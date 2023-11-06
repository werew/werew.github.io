---
title: IOLI - crackme0x09
date: 2016-07-19
categories: [Writeups]
tags: ['IOLI']
---


This level adds nothing new to the previous nine crackmes of the 
[IOLI - suite ](http://github.com/Maijin/Workshop20LI-crackme)
Let's have a look to the function main:

```nasm
[0x08048420]> pdf @ main
/ (fcn) main 120
|           ; var int local_78h @ ebp-0x78
|           ; var int local_4h @ ebp-0x4
|           ; arg int arg_10h @ ebp+0x10
|           ; var int local_4h @ esp+0x4
|           ; DATA XREF from 0x08048437 (entry0)
|           0x080486ee      55             push ebp
|           0x080486ef      89e5           mov ebp, esp
|           0x080486f1      53             push ebx
|           0x080486f2      81ec84000000   sub esp, 0x84
|           0x080486f8      e869000000     call fcn.08048766 ; ebx = eip + 5
|           0x080486fd      81c3f7180000   add ebx, 0x18f7
|           0x08048703      83e4f0         and esp, 0xfffffff0
|           0x08048706      b800000000     mov eax, 0
|           0x0804870b      83c00f         add eax, 0xf
|           0x0804870e      83c00f         add eax, 0xf
|           0x08048711      c1e804         shr eax, 4
|           0x08048714      c1e004         shl eax, 4
|           0x08048717      29c4           sub esp, eax
|           0x08048719      8d8375e8ffff   lea eax, [ebx - 0x178b]
|           0x0804871f      890424         mov dword [esp], eax
|           0x08048722      e8b9fcffff     call sym.imp.printf ; "IOLI Crackme Level 0x09\n"
|           0x08048727      8d838ee8ffff   lea eax, [ebx - 0x1772]
|           0x0804872d      890424         mov dword [esp], eax
|           0x08048730      e8abfcffff     call sym.imp.printf ; "Password:"
|           0x08048735      8d4588         lea eax, [ebp - local_78h]
|           0x08048738      89442404       mov dword [esp + local_4h], eax
|           0x0804873c      8d8399e8ffff   lea eax, [ebx - 0x1767]
|           0x08048742      890424         mov dword [esp], eax ; "%s"
|           0x08048745      e876fcffff     call sym.imp.scanf
|           0x0804874a      8b4510         mov eax, dword [ebp + arg_10h]
|           0x0804874d      89442404       mov dword [esp + local_4h], eax
|           0x08048751      8d4588         lea eax, [ebp - local_78h]
|           0x08048754      890424         mov dword [esp], eax
|           0x08048757      e8bafeffff     call sub.strlen_616
|           0x0804875c      b800000000     mov eax, 0
|           0x08048761      8b5dfc         mov ebx, dword [ebp - local_4h]
|           0x08048764      c9             leave
\           0x08048765      c3             ret
```

It looks like the program is compiled using the flag `-fPIC` and the 
compiler chose `ebx` [as PIC register](
http://stackoverflow.com/questions/38372759/what-is-this-pattern-where-the-ebx-register-is-used-for-memory-access).
The function at `0x08048766` is used to assign to `ebx` the instruction
immediately following the call instruction. Since the size of a call
instruction is 5 bytes this translates into `ebx = eip + 5`.

```nasm
[0x08048420]> pdf @ fcn.08048766 
/ (fcn) fcn.08048766 4
|           ; XREFS: CALL 0x080486f8  CALL 0x0804861d  CALL 0x080484db  CALL 0x08048564  CALL 0x08048590       
|           ; XREFS: CALL 0x08048778 
|           0x08048766      8b1c24         mov ebx, dword [esp] ; eip was pushed into the stack
\           0x08048769      c3             ret
```


Looking at the XREFS we can see that this function is called quite often.
For convenience let's rename it: `afn init_ebx 0x08048766`  
After this call and the instruction `add ebx, 0x18f7` the register `ebx`
points to the end of the GOT: `ebx = 0x080486fd + 0x18f7`.

Then, to see what contains the string passed to the first printf as argument
we can just do like this:  

    [0x08048420]> ps @ section_end..got - 0x178b
    IOLI Crackme Level 0x09


The function main would look more or less like this:


```C
#define SIZE_PASS 100 // This is just a random value
int main(int argc, char **argv, char **envp){

    char password[SIZE_PASS];

    printf("IOLI Crackme Level 0x09\n");
    printf("Password: \n");

    scanf("%s",password);

    strlen_616(password, envp);

    return 0;

}
```

Lets have a look to the first block of the function `strlen_616`:

```nasm
0x08048616      55             push ebp
0x08048617      89e5           mov ebp, esp
0x08048619      53             push ebx
0x0804861a      83ec24         sub esp, 0x24
0x0804861d      e844010000     call init_ebx
0x08048622      81c3d2190000   add ebx, 0x19d2
0x08048628      c745f4000000.  mov dword [ebp - local_ch], 0
0x0804862f      c745f0000000.  mov dword [ebp - local_10h], 0
```

After the usual prelude, there are two values initialize with 0.
We can suppose they are counters used in some sort of loop, let's 
rename them `count_1` and `count_2`.  
From the second block it would seem that `count_2` is used in a
loop along all the length of our password:

```nasm
0x08048636      8b4508         mov eax, dword [ebp + password]
0x08048639      890424         mov dword [esp], eax  
0x0804863c      e88ffdffff     call sym.imp.strlen 
0x08048641      3945f0         cmp dword [ebp - count_2], eax
0x08048644      734f           jae 0x8048695
```


Now let's have a look at what happens inside this loop:

```nasm
0x08048646      8b45f0         mov eax, dword [ebp - count_2]                        
0x08048649      034508         add eax, dword [ebp + password]                       
0x0804864c      0fb600         movzx eax, byte [eax]                                 
0x0804864f      8845ef         mov byte [ebp - local_11h], al                        
0x08048652      8d45f8         lea eax, [ebp - local_8h] 
0x08048655      89442408       mov dword [esp + local_8h], eax                       
0x08048659      8d835ee8ffff   lea eax, [ebx - 0x17a2]   
0x0804865f      89442404       mov dword [esp + local_4h], eax                       
0x08048663      8d45ef         lea eax, [ebp - local_11h] 
0x08048666      890424         mov dword [esp], eax                                  
0x08048669      e882fdffff     call sym.imp.sscanf ; sscanf(local_11h, "%d", &local_8h)
0x0804866e      8b55f8         mov edx, dword [ebp - local_8h]                       
0x08048671      8d45f4         lea eax, [ebp - count_1]
0x08048674      0110           add dword [eax], edx  ; count_1 += local_8h
0x08048676      837df410       cmp dword [ebp - count_1], 0x10
0x0804867a      7512           jne 0x804868e   
```

So, the program reads one by one all the characters of our password as they
were integers. For the sake of clarity, let's rename some variable: 

- count_1   -> sum 
- local_11h -> pass_char
- local_8h  -> char_value


A function is called when the value of `sum` is equal to 0x10:

```nasm
0x0804867c      8b450c         mov eax, dword [ebp + envp]
0x0804867f      89442404       mov dword [esp + local_4h], eax 
0x08048683      8b4508         mov eax, dword [ebp + password]
0x08048686      890424         mov dword [esp], eax
0x08048689      e8fbfeffff     call sub.sscanf_589; sscanf_589(password,envp)
```


Otherwise the value of `count_2` is incremented and the loop continues:

```nasm
0x0804868e      8d45f0         lea eax, [ebp - count_2]
0x08048691      ff00           inc dword [eax]                                       
0x08048693      eba1           jmp 0x8048636      
```

If we go out of the loop, the program calls a function which will print
an error message and exit:

```nasm
0x0804855d      55             push ebp
0x0804855e      89e5           mov ebp, esp                                         
0x08048560      53             push ebx
0x08048561      83ec04         sub esp, 4                                                             
0x08048564      e8fd010000     call init_ebx               
0x08048569      81c38b1a0000   add ebx, 0x1a8b                                                        
0x0804856f      8d8349e8ffff   lea eax, [ebx - 0x17b7]
0x08048575      890424         mov dword [esp], eax                                                   
0x08048578      e863feffff     call sym.imp.printf ; "Invalid password!\n"
0x0804857d      c70424000000.  mov dword [esp], 0                                                     
0x08048584      e887feffff     call sym.imp.exit
```

So apparently we must enter into the function named by radare `sub.sscanf_589`.
This gives as a first constraint: at some point the sum of the characters 
of our password must be equal to 0x10 (16). So, "466" would work, but
"1234abc" or "999" would not. So let's see what happens when the password
meets this constraint:
    

```nasm
0x08048589      55             push ebp
0x0804858a      89e5           mov ebp, esp
0x0804858c      53             push ebx
0x0804858d      83ec14         sub esp, 0x14
0x08048590      e8d1010000     call init_ebx
0x08048595      81c35f1a0000   add ebx, 0x1a5f
0x0804859b      8d45f8         lea eax, [ebp - value]
0x0804859e      89442408       mov dword [esp + 8], eax
0x080485a2      8d835ee8ffff   lea eax, [ebx - 0x17a2]
0x080485a8      89442404       mov dword [esp + 4], eax
0x080485ac      8b4508         mov eax, dword [ebp + password]
0x080485af      890424         mov dword [esp], eax
0x080485b2      e839feffff     call sym.imp.sscanf ; sscanf(password, "%d", &value)
0x080485b7      8b450c         mov eax, dword [ebp + envp]
0x080485ba      89442404       mov dword [esp + 4], eax
0x080485be      8b45f8         mov eax, dword [ebp - value]
0x080485c1      890424         mov dword [esp], eax 
0x080485c4      e80bffffff     call sub.strncmp_4d4 ; sub.strncmp_4d4(value, envp)
0x080485c9      85c0           test eax, eax
0x080485cb      7443           je 0x8048610
```

This function reads the value of the whole password as if it was
an integer and put it in a variable that I already renamed `value`. 
Then ,if the value returned by the function `sub.strncmp_4d4(value, envp)`
is 0, it jumps to the address `0x8048610` end just returns:

```nasm
0x08048610      83c414         add esp, 0x14                                                           
0x08048613      5b             pop ebx                                                                 
0x08048614      5d             pop ebp                                                                 
0x08048615      c3             ret      
```

Otherwise we enter in a loop:

```nasm
0x080485cd      c745f4000000.  mov dword [ebp - count], 0 
0x080485d4      837df409       cmp dword [ebp - count], 9
0x080485d8      7f36           jg 0x8048610 ; quit the loop if (count > 9)
0x080485da      8b45f8         mov eax, dword [ebp - value]                                         
0x080485dd      83e001         and eax, 1                                                              
0x080485e0      85c0           test eax, eax                                                           
0x080485e2      7525           jne 0x8048609 ; continue if (value & 1 != 0) 
0x080485e4      8b83fcffffff   mov eax, dword [ebx - 4] ; probably a global var
0x080485ea      833801         cmp dword [eax], 1 
0x080485ed      750e           jne 0x80485fd ; so [eax] must be == 1 
0x080485ef      8d8361e8ffff   lea eax, [ebx - 0x179f] ; "Password OK!\n"
0x080485f5      890424         mov dword [esp], eax                                                    
0x080485f8      e8e3fdffff     call sym.imp.printf  
0x080485fd      c70424000000.  mov dword [esp], 0                                                      
0x08048604      e807feffff     call sym.imp.exit  
0x08048609      8d45f4         lea eax, [ebp - count]  
0x0804860c      ff00           inc dword [eax] ; count++
0x0804860e      ebc4           jmp 0x80485d4 
```

For `count = 0` until `count <= 9`, if the `value & 1 == 0` and the
content at `[ebx - 4]` is an address to a value of 1 we pass the level!
In order to have `value & 1 == 0`, `value` must be an even number.
Now let's see the function `sub.strncmp_4d4` and let's figure out how to
obtain a return value != 0. This is the content after the usual prelude:

```nasm
0x080484e6      c745f8000000.  mov dword [ebp - count], 0
0x080484ed      8b45f8         mov eax, dword [ebp - count]
0x080484f0      8d1485000000.  lea edx, [eax*4]
0x080484f7      8b450c         mov eax, dword [ebp + envp]
0x080484fa      833c0200       cmp dword [edx + eax], 0
0x080484fe      7448           je 0x8048548
```

It looks like a loop over all the values contained into `envp`.

```nasm
0x08048500      8b45f8         mov eax, dword [ebp - count]
0x08048503      8d1485000000.  lea edx, [eax*4]
0x0804850a      8b4d0c         mov ecx, dword [ebp + envp]
0x0804850d      8d45f8         lea eax, [ebp - count]
0x08048510      ff00           inc dword [eax]
0x08048512      8d8344e8ffff   lea eax, [ebx - 0x17bc]; "LOLO"
0x08048518      c74424080300.  mov dword [esp + 8], 3
0x08048520      89442404       mov dword [esp + 4], eax
0x08048524      8b040a         mov eax, dword [edx + ecx]
0x08048527      890424         mov dword [esp], eax
0x0804852a      e8d1feffff     call sym.imp.strncmp; strncmp(envp[count],"LOLO",3)
0x0804852f      85c0           test eax, eax
0x08048531      75ba           jne 0x80484ed
```

Apparently the program search for an env. variable having a name
that starts with "LOL". If this variable exists, the function changes
the value pointed by `[ebx - 4]` to 1, and returns 1:

```nasm
0x08048533      8b83fcffffff   mov eax, dword [ebx - 4]                                                
0x08048539      c70001000000   mov dword [eax], 1                                                      
0x0804853f      c745f4010000.  mov dword [ebp - local_ch], 1                                           
0x08048546      eb0c           jmp 0x8048554 

... 

0x08048554      8b45f4         mov eax, dword [ebp - local_ch]                                         
0x08048557      83c414         add esp, 0x14                                                           
0x0804855a      5b             pop ebx                                                                 
0x0804855b      5d             pop ebp                                                                 
0x0804855c      c3             ret  
```


This is exactly what we need in order to pass the level.
To recap:
    - The password must start with a series of numbers which
      sum is equal to 16
    - The password must be an even number
    - There must be an env. variable having a name that starts
      with "LOL"

So let's try it out:

```console
$ export LOL=123; ./crackme0x09
IOLI Crackme Level 0x09
Password: 556
Password OK!
```

Cool, it worked :)



