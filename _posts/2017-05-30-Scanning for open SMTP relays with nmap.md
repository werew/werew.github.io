---
title: Scanning for open SMTP relays with nmap
date: 2017-05-30
categories: [Network Security]
tags: ['SMTP', 'Nmap']
image:
    path: "unsorted/nmap.jpg"
---


Among the many features offered by the famous scanner
[nmap](https://nmap.org/) there is also a script to identify 
open relays ([link here](https://nmap.org/nsedoc/scripts/smtp-open-relay.html)).
If passed with the option `--script` to nmap this script will
determine if an email server is an open relay.

In order not to scan blindly some ranges we can take some country-based ip
ranges from [here](https://www.ipaddresslocation.org/ip_ranges/get_ranges.php).
Let's save those ranges in a file ranges.txt.  

Now we can launch the scan:

```sh
#!/bin/sh

# ports to scan
ports="25,465,587"

nmap    -sS                             \
        --min-parallelism  100          \
        -n                              \
        -PN                             \
        -p $ports                       \
        --max-retries 1                 \
        --script smtp-open-relay        \
        -T 4                            \
        -iL ranges.txt                  \
        | grep -B 8 -A 2 "smtp-open-relay:"
```

There are a lot of nmap's options, not all of them are necessary
but are simply there to make things better. Let's have a look at them: 

- **-p 25,465,587**: we limit the scan at just some
    [common SMTP ports](https://blog.mailgun.com/25-465-587-what-port-should-i-use)
- **-n**: never do DNS resolution, as we are using ip addresses 
- **-T 4**: aggressive scan time template, in short: go fast, don't wait much...
- **--min-parallelism 100**: minimum total of parallel probes...pretty high
- **-iL ranges.txt**: input from list
- **-Pn**: no ping, go directly to scanning...
- **-sS**: TCP SYN scan
- **--script smtp-open-relay**: use the script smtp-open-relay

When run, the scan will output something like this:

```console
$ nmap -Pn --script smtp-open-relay -p 25,465,587 smtp.bbox.fr

Starting Nmap 6.40 ( https://nmap.org ) at 2017-05-22 17:01 CEST
Nmap scan report for smtp.bbox.fr (194.158.122.55)
Host is up (0.034s latency).
PORT    STATE SERVICE
25/tcp  open  smtp
|_smtp-open-relay: Server is an open relay (12/16 tests)
465/tcp open  smtps
|_smtp-open-relay: Server doesn't seem to be an open relay, all tests failed
587/tcp open  submission
|_smtp-open-relay: Server doesn't seem to be an open relay, all tests failed

Nmap done: 1 IP address (1 host up) scanned in 20.41 seconds
```

In this case nmap found out that port 25 offers an open relay.
The command `grep` at the end of the script will let us get 
only the successful scans.

NB: outgoing connection to port 25 could be blocked by your ISP

For the script I have taken inspiration from
[this article](https://funoverip.net/2010/11/socks-proxy-servers-scanning-with-nmap/).
Give it a look ;)  


### How does it work ?

We saw that nmap can detect open SMTP relays, but how does it ?
Lets have a look at the script `smtp-open-relay.nse` 
[here](https://svn.nmap.org/nmap/scripts/smtp-open-relay.nse).



The heart of the script starts at `-- Antispam tests`:

```lua
-- Antispam tests.
  local tests = {
    {
      from = "",
      to = string.format("%s@%s", to, domain)
    },
    {
      from = string.format("%s@%s", from, domain),
      to = string.format("%s@%s", to, domain)
    },
    {
      from = string.format("%s@%s", from, srvname),
      to = string.format("%s@%s", to, domain)
    },
    {
      from = string.format("%s@[%s]", from, ip),
      to = string.format("%s@%s", to, domain)
    },
    {
      from = string.format("%s@[%s]", from, ip),
      to = string.format("%s%%%s@[%s]", to, domain, ip)
    },
    {
      from = string.format("%s@[%s]", from, ip),
      to = string.format("%s%%%s@%s", to, domain, srvname)
    },
    {
      from = string.format("%s@[%s]", from, ip),
      to = string.format("\"%s@%s\"", to, domain)
    },
    {
      from = string.format("%s@[%s]", from, ip),
      to = string.format("\"%s%%%s\"", to, domain)
    },
    {
      from = string.format("%s@[%s]", from, ip),
      to = string.format("%s@%s@[%s]", to, domain, ip)
    },
    {
      from = string.format("%s@[%s]", from, ip),
      to = string.format("\"%s@%s\"@[%s]", to, domain, ip)
    },
    {
      from = string.format("%s@[%s]", from, ip),
      to = string.format("%s@%s@%s", to, domain, srvname)
    },
    {
      from = string.format("%s@[%s]", from, ip),
      to = string.format("@[%s]:%s@%s", ip, to, domain)
    },
    {
      from = string.format("%s@[%s]", from, ip),
      to = string.format("@%s:%s@%s", srvname, to, domain)
    },
    {
      from = string.format("%s@[%s]", from, ip),
      to = string.format("%s!%s", domain, to)
    },
    {
      from = string.format("%s@[%s]", from, ip),
      to = string.format("%s!%s@[%s]", domain, to, ip)
    },
    {
      from = string.format("%s@[%s]", from, ip),
      to = string.format("%s!%s@%s", domain, to, srvname)
    },
  }
```

Each test is performed simply changing the content of `from` and `to`:

```lua
status, response = smtp.query(socket, "MAIL",
      string.format("FROM:<%s>",
      tests[index]["from"]))
...

if string.match(response, "530") then
      smtp.quit(socket)
      return false, "Server isn't an open relay, authentication needed"
    elseif smtp.check_reply("MAIL", response) then
      -- Lets try to actually relay.
      status, response = smtp.query(socket, "RCPT",
        string.format("TO:<%s>",
        tests[index]["to"]))
      if not status then
        return failure(string.format("Failed to issue %s command (%s)",
          tests[index]["to"], response))
      end

      if string.match(response, "530") then
        smtp.quit(socket)
        return false, "Server isn't an open relay, authentication needed"
      elseif smtp.check_reply("RCPT", response) then
        -- Save the working from and to combination.
        table.insert(result,
          string.format("MAIL FROM:<%s> -> RCPT TO:<%s>",
          tests[index]["from"], tests[index]["to"]))
      end
    end
end
```

If server accept both the commands `MAIL FROM` and `RCPT TO` is has
passed the test.

In order to see exactly whats going on we can use the option `-v` which 
will tell us which tests actually passed:

```console
25/tcp  open  smtp
| smtp-open-relay: Server is an open relay (12/16 tests)
|  MAIL FROM:<> -> RCPT TO:<relaytest@nmap.scanme.org>
|  MAIL FROM:<antispam@nmap.scanme.org> -> RCPT TO:<relaytest@nmap.scanme.org>
|  MAIL FROM:<antispam@mail-1y.bbox.fr> -> RCPT TO:<relaytest@nmap.scanme.org>
|  MAIL FROM:<antispam@[194.158.122.55]> -> RCPT TO:<relaytest@nmap.scanme.org>
|  MAIL FROM:<antispam@[194.158.122.55]> -> RCPT TO:<relaytest%nmap.scanme.org@mail-1y.bbox.fr>
|  MAIL FROM:<antispam@[194.158.122.55]> -> RCPT TO:<"relaytest@nmap.scanme.org">
|  MAIL FROM:<antispam@[194.158.122.55]> -> RCPT TO:<relaytest@nmap.scanme.org@[194.158.122.55]>
|  MAIL FROM:<antispam@[194.158.122.55]> -> RCPT TO:<"relaytest@nmap.scanme.org"@[194.158.122.55]>
|  MAIL FROM:<antispam@[194.158.122.55]> -> RCPT TO:<relaytest@nmap.scanme.org@mail-1y.bbox.fr>
|  MAIL FROM:<antispam@[194.158.122.55]> -> RCPT TO:<@[194.158.122.55]:relaytest@nmap.scanme.org>
|  MAIL FROM:<antispam@[194.158.122.55]> -> RCPT TO:<@mail-1y.bbox.fr:relaytest@nmap.scanme.org>
|_ MAIL FROM:<antispam@[194.158.122.55]> -> RCPT TO:<nmap.scanme.org!relaytest@mail-1y.bbox.fr>
```

...or if you are brave enough you can use the option `--packet-trace`.

