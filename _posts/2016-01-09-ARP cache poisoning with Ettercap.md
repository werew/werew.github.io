---
title: ARP cache poisoning with Ettercap
date: 2016-01-09
categories: [Network Security]
tags: ['MITM', 'ARP']
image:
    path: "unsorted/poison.webp"
---

The Internet is extremely full of articles about the principles of an ARP 
cache poisoning attack, I will rather show how to perform some of the most 
basic ARP spoofing attacks using Ettercap, a powerful and easy to use
tool for MITM attacks.

Ettercap usually comes pre-installed if you are using Linux distributions such
as Kali, otherwise you can simply download it from [Ettercap's web page](
https://ettercap.github.io/ettercap/)


## ARP poisoning using Ettercap 
**version: 0.8.2**

Ettercap offers several user interfaces, basically: text, curses, gtk,
daemonize. I like to use the text (command line) interface...I find it way more
handy once understood the syntax than a graphical interface and, most important
point, it is suited for use inside scripts.

### Scanning for hosts

The first thing Ettercap needs to do in order to work is a list of all the
available hosts in the network. Ettercap performs automatically an ARP storm
trying all the possible ip addresses (considering the current netmask) every
time it is launched.  This approach is particularly noisy (especially for a big
network) but we can use a file to store all the informations and ask
Ettercap to use it next time we will launch it.

```sh
#This will scan the whole network and write everything down in /tmp/hosts
ettercap -T -k /tmp/hosts
```

Note that I’m using a file under /tmp , this is because even if Ettercap needs
to have the necessary privileges to run, it will then drop his privileges and
sets UID = 65535 (nobody) after the initialization phase.  
For more infos have a look to the [manual](https://linux.die.net/man/8/ettercap).

We can then use that file with the -j option.

Then initial scan can be also avoided using the silent option: -z, in this case
Ettercap will be expecting either a list of hosts (in a file) either a couple
of hosts directly specified as targets.

### Man in the middle 
Now it’s time to launch the ARP spoofing attack and intercept all the packets
on the network.  For this we need to use the -M option (man in the middle) and
specify which kind of attack we would like to perform. In this article I
will cover just the ARP poisoning.

Here is some example:

- **Intercept all the traffic on the network**  
  `ettercap -T -M arp`  
  As no file for the hosts is charged and the -z option has not been specified
  Ettercap will scan for all the active hosts using the ip address and the
  netmask of the default interface.

- **Intercept the traffic of one particular address space**   
  `ettercap -T -M arp /192.168.1.1-24,100-110//80`  
  Ettercap will capture all the traffic relative the port 80 of the ip
  addresses between **192.168.1.1** and **192.168.1.24** and the addresses
  between **192.168.1.100** and **192.168.1.110**.

- **Store the packets in a file and don’t show them**   
  `ettercap -T -w /tmp/dump -q -M arp`  
  There are many ways of storing the packets with Ettercap, note also the
  options: -L and -l

- **Perform a one-way attack:**  
  `ettercap -T -M arp:oneway /192.168.1.99//`  
  This will spoof only the outgoing traffic of 192.168.1.99.

- **A simple Dos attack**  
  `ettercap -T  -o -M arp /192.168.1.99//`  
  Ettercap uses 2 separated threads to sniff and perform the man in the middle
  operations, the option -o turns off the sniffer. Ettercap will not read any
  packet and will no forward them.  If there isn't any other application who deal
  with the forwarding, the result will be a DOS attack.

### Filters

The possibility are infinites. Here the principle:

1. Write down a filter (have a look to the man page of etterfilter for the syntax).  
   Example:

	    if (ip.proto == TCP && tcp.src == 80) {
	       replace("img src=", "img src=\"https://somewebsite.com/pwned.png\" ");
	       replace("IMG SRC=", "img src=\"https://somewebsite.com/pwned.png\" ");
	       msg("Filter Ran.\n");
	    }

2. Compile the filter using etterfilter

3. Use it with ettercap

Further reading: <https://www.sans.org/reading-room/whitepapers/tools/ettercap-primer-1406>



### How can I try ettercap on my machine?

If you only have one device in your home network or if just you want to
test Ettercap using one only machine, virtualization could be a good option.

In my case I tried Ettercap inside my home network using a KVM-made virtual
machine configured in order to be on the same network of the physical
computer.

If you want to follow this same technique, here are the scripts I used to bring
up a virtual machine and link it to the same network of the host.

For the virtual machine I used a Kali Linux’s image.


**upnet:**

```sh
#!/bin/sh -x
brctl addbr kabr0
tunctl -t katap0 -u werew
brctl addif kabr0 eth0
brctl addif kabr0 katap0
 
ifconfig eth0 up
ifconfig katap0 up
ifconfig kabr0 up
 
ifconfig kabr0 192.168.1.99
ifconfig eth0 0.0.0.0 promisc
route add default gw 192.168.1.254
```

**downnet:**

```sh
#!/bin/sh -x
ifconfig kabr0 down
ifconfig katap0 down
ifconfig eth0 down
 
brctl delbr kabr0
tunctl -d katap0
 
ifconfig eth0 up -promisc
```

**kalinet:**

```sh
#!/bin/sh -x
sudo ./upnet
kvm -m 2G -hda kali2.img -net nic,vlan=0 \ 
    -net tap,vlan=0,ifname=katap0,script=no,downscript=no
sudo ./downne
```


And then start everything just typing: `./kalinet`

For more informations [Host and guests on same network
](https://wiki.debian.org/QEMU#Host_and_guests_on_same_network) 
and [Connecting QEMU to a Real Network
](https://emreboy.wordpress.com/2012/12/24/connecting-qemu-to-a-real-network)

