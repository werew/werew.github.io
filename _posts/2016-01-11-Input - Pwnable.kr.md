---
title: Input - Pwnable.kr
date: 2016-01-11
categories: [Writeups, Pwnable.kr]
tags: ['IO']
image:
    path: "/unsorted/pwnablekr.png"

---

Once logged in we need to have a look to the code source of input: `input.c`

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <arpa/inet.h>
 
int main(int argc, char* argv[], char* envp[]){
    printf("Welcome to pwnable.kr\n");
    printf("Let's see if you know how to give input to program\n");
    printf("Just give me correct inputs then you will get the flag :)\n");
 
    // argv
    if(argc != 100) return 0;
    if(strcmp(argv['A'],"\x00")) return 0;
    if(strcmp(argv['B'],"\x20\x0a\x0d")) return 0;
    printf("Stage 1 clear!\n"); 
 
    // stdio
    char buf[4];
    read(0, buf, 4);
    puts(buf);
    if(memcmp(buf, "\x00\x0a\x00\xff", 4)) return 0;
    read(2, buf, 4);
        if(memcmp(buf, "\x00\x0a\x02\xff", 4)) return 0;
    printf("Stage 2 clear!\n");
     
    // env
    if(strcmp("\xca\xfe\xba\xbe", getenv("\xde\xad\xbe\xef"))) return 0;
    printf("Stage 3 clear!\n");
 
    // file
    FILE* fp = fopen("\x0a", "r");
    if(!fp) return 0;
    if( fread(buf, 4, 1, fp)!=1 ) return 0;
    if( memcmp(buf, "\x00\x00\x00\x00", 4) ) return 0;
    fclose(fp);
    printf("Stage 4 clear!\n"); 
 
    // network
    int sd, cd;
    struct sockaddr_in saddr, caddr;
    sd = socket(AF_INET, SOCK_STREAM, 0);
    if(sd == -1){
        printf("socket error, tell admin\n");
        return 0;
    }
    saddr.sin_family = AF_INET;
    saddr.sin_addr.s_addr = INADDR_ANY;
    saddr.sin_port = htons( atoi(argv['C']) );
    if(bind(sd, (struct sockaddr*)&saddr, sizeof(saddr)) < 0){
        printf("bind error, use another port\n");
            return 1;
    }
    listen(sd, 1);
    int c = sizeof(struct sockaddr_in);
    cd = accept(sd, (struct sockaddr *)&caddr, (socklen_t*)&c);
    if(cd < 0){
        printf("accept error, tell admin\n");
        return 0;
    }
    if( recv(cd, buf, 4, 0) != 4 ) return 0;
    if(memcmp(buf, "\xde\xad\xbe\xef", 4)) return 0;
    printf("Stage 5 clear!\n");
 
    // here's your flag
    system("/bin/cat flag");    
    return 0;
}
```


As we can see the program goes trough many conditions that we need to satisfy
(or not, it depends which case) in order to let the program continue its
execution. Let's create a C program which will execute the
program ‘input’ with all the given precautions.


#### Stage 1 – argv

```c
if(argc != 100) return 0;
if(strcmp(argv['A'],"\x00")) return 0;
if(strcmp(argv['B'],"\x20\x0a\x0d")) return 0;
printf("Stage 1 clear!");
```

We deduce that the program must be executed with those conditions:

- Exactly 100 arguments
- The argument n0. 65 (ascii value for A) must be an empty string
- The argument no. 66 (ascii value for B) must be \x20\x0a\x0d

This could be simply done using the command line.

We need to change the value of `$IFS` in order to allow the chars
`\x20\x0a\x0d` to be inside an argument string.  Let’s choose ‘-‘ for example
as field separator: IFS=’-‘ The arguments will be: 64 times A + `\x00` +
`\x20\x0a\x0d` + 33 times A All separated by ‘-‘. Using perl then: `perl -e
'print "A-"x64 . "\x00-" . "\x20\x0a\x0d" . "-A"x33'`

Note that we add in total 99 arguments, this is because the name of the program
counts as one.  

Now forget all this...as I said we will use a C program to do everything.  We
will use ‘execve’ to execute the program ‘input’.

```c
int execve(const char *filename, char *const argv[], char *const envp[]);
```


We need an array containing all the 100 arguments, then we need to initialize the 
arguments n. 65 (‘A’) and n. 66 (‘B’) with the required values.

```c
char *argv[101] = {"/home/input/input", [1 ... 99] = "A", NULL};
argv['A'] = "\x00";
argv['B'] = "\x20\x0a\x0d";

execve("/home/input/input",argv,NULL);
```

Once executed, we will obtain a beautiful “Stage 1 clear!” :)


#### Stage 2 – stdio

```c
char buf[4];
read(0, buf, 4);
if(memcmp(buf, "\x00\x0a\x00\xff", 4)) return 0;
read(2, buf, 4);
if(memcmp(buf, "\x00\x0a\x02\xff", 4)) return 0;
```

The program ‘input’ must read “\x00\x0a\x00\xff” from the stdin and
“\x00\x0a\x02\xff” from the stderr.  This could be done using
[pipes](https://tldp.org/LDP/lpg/node11.html).  We will use two pipes: one for
the stdin, one for the stderr.  In brief:

1.  Create two pipes: pipe2stdin and pipe2stderr
2.  Fork the process
3.  Child:
    1.  write “\x00\x0a\x00\xff” to pipe2stdin
    2.  write “\x00\x0a\x02\xff” to pipe2stderr
4.  Parent:
    1.  map the stdin to pipe2stdin
    2.  map the stderr to pipe2stderr
    3.  substitute the process with the execution of ‘input’


Further reading: [Mapping UNIX pipe descriptors to stdin and stdout in
C](https://unixwiz.net/techtips/remap-pipe-fds.html)

Then, let’s add this code:

```c
int pipe2stdin[2] = {-1,-1};
int pipe2stderr[2] = {-1,-1};
pid_t childpid;
 
if ( pipe(pipe2stdin) < 0 || pipe(pipe2stderr) < 0){
    perror("Cannot create the pipe");
    exit(1);
}
 
if ( ( childpid = fork() ) < 0 ){
    perror("Cannot fork");
    exit(1);
}
 
if ( childpid == 0 ){
    /* Child process */
    close(pipe2stdin[0]); close(pipe2stderr[0]); // Close pipes for reading
    write(pipe2stdin[1],"\x00\x0a\x00\xff",4);
    write(pipe2stderr[1],"\x00\x0a\x02\xff",4);
}
else {
    /* Parent process */
    close(pipe2stdin[1]); close(pipe2stderr[1]);   // Close pipes for writing
    dup2(pipe2stdin[0],0); dup2(pipe2stderr[0],2); // Map to stdin and stderr
    close(pipe2stdin[0]); close(pipe2stderr[1]);   // Close write end (the fd has been copied before)
    execve("/home/input/input",argv,NULL);  // Execute the program
}
```


Cool “Stage 2 clear!” :)


#### Stage 3 – env 

```c
if(strcmp("\xca\xfe\xba\xbe", getenv("\xde\xad\xbe\xef"))) return 0;
printf("Stage 3 clear!\n");
```

This stage is about environment variables, our goal is to pass a variable
called (in hex values) “\xde\xad\xbe\xef” containing a value of (again using
hex values) “\xca\xfe\xba\xbe”.  This can be easily done using the third
parameter of the function execve

```c
char *env[2] = {"\xde\xad\xbe\xef=\xca\xfe\xba\xbe", NULL};
execve("/home/input/input",argv,env);   
```


#### Stage 4 – file 

```c
FILE* fp = fopen("\x0a", "r");
if(!fp) return 0;
if( fread(buf, 4, 1, fp)!=1 ) return 0;
if( memcmp(buf, "\x00\x00\x00\x00", 4) ) return 0;
fclose(fp);
printf("Stage 4 clear!\n"); 
```

We need to open a file and write down 4 null bytes. Once we are done we can close it. 

```c
FILE* fp = fopen("\x0a","w");
fwrite("\x00\x00\x00\x00",4,1,fp);
fclose(fp);
```

So far, so good: stage 4 clear!

#### Stage 5 – network

In this last stage the program “input” becomes a 
[server](https://www.cs.rpi.edu/~moorthy/Courses/os98/Pgms/socket.html), 
which will wait for incoming connections on a given port:

```c
int sd, cd;
struct sockaddr_in saddr, caddr;
sd = socket(AF_INET, SOCK_STREAM, 0);
if(sd == -1){
    printf("socket error, tell admin\n");
    return 0;
}
saddr.sin_family = AF_INET;
saddr.sin_addr.s_addr = INADDR_ANY;
saddr.sin_port = htons( atoi(argv['C']) );
if(bind(sd, (struct sockaddr*)&saddr, sizeof(saddr)) < 0){
    printf("bind error, use another port\n");
        return 1;
}
listen(sd, 1);
int c = sizeof(struct sockaddr_in);
cd = accept(sd, (struct sockaddr *)&caddr, (socklen_t*)&c);
if(cd < 0){
    printf("accept error, tell admin\n");
    return 0;
}
if( recv(cd, buf, 4, 0) != 4 ) return 0;
if(memcmp(buf, "\xde\xad\xbe\xef", 4)) return 0;
printf("Stage 5 clear!\n");
```


We can choose the port on which the server will listen specifying a value for
the argument no. ‘C’ (67), let’s take a port number bigger then 1024, let’s say
55555.
       
```c
argv['B'] = "55555";
```


Now when we execute the program it will listen on port 55555 and wait for
one incoming connection (just one: the server doesn’t perform any kind of loop
and length of the queue is one). If the first 4 bytes of the data we send to
the program are equal to “\xde\xad\xbe\xef” then our program will finally open
the flag.  How do we send data to it? Let’s see two possible solutions.

**Using a third program on the command line**

This is the easiest way as we don’t need to add anything to our program, we
just use another one to connect to “input” once it is ready to listen for
incoming connections. Let’s use netcat:

```c
printf "\xde\xad\xbe\xef" | nc localhost 55555
```

Be aware: the syntax could change from different versions of netcat.  One could
be tempted to use

```c
printf "\xde\xad\xbe\xef" | nc pwnable.kr 55555
```

from another machine than the server of pwnable.kr. This will not work because
the server of pwnable.kr uses the public address of his gateway (have a look
with ifconfig) which will not forward the traffic coming to this port, so we
are obliged to connect from the server itself (or from a machine on the same
network! ) otherwise our traffic will be blocked.

**Using our C program**

We can [build our own C
client](https://gnosis.cx/publish/programming/sockets.html).


```c
int sockfd;
struct sockaddr_in server;
sockfd = socket(AF_INET,SOCK_STREAM,0);
if ( sockfd < 0){
    perror("Cannot create the socket");
    exit(1);
}
server.sin_family = AF_INET;
server.sin_addr.s_addr = inet_addr("127.0.0.1");
server.sin_port = htons(55555);
if ( connect(sockfd, (struct sockaddr*) &server, sizeof(server)) < 0 ){
    perror("Problem connecting");
    exit(1);
}
char buf[4] = "\xde\xad\xbe\xef";
write(sockfd,buf,4);
close(sockfd);
```

But there is still a little problem: most of the times the server will not be
ready once our client will try to connect, in order to avoid that we can make
our client sleep for a few seconds before trying to reach the server.

Last small issue. Now our program runs perfectly, it has just one problem: our
working directory will be under /tmp and the program “input” gets the same
working directory, this means that it will not be able to find the file “flag”.
In order to resolve this we can just create a link to “flag” on our working
directory and call it “flag” with `ln /home/input/flag flag`

Now that we have the link to flag, lets put all the parts back together:

```c
#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <netinet/in.h>
 
int main (){
    //Stage 1
    char *argv[101] = {"/home/input/input", [1 ... 99] = "A", NULL};
    argv['A'] = "\x00";
    argv['B'] = "\x20\x0a\x0d";
    argv['C'] = "55555";
     
    //Stage 2
    int pipe2stdin[2] = {-1,-1};
    int pipe2stderr[2] = {-1,-1};
    pid_t childpid;
 
    if ( pipe(pipe2stdin) < 0 || pipe(pipe2stderr) < 0){
        perror("Cannot create the pipe");
        exit(1);
    }
     
    //Stage 4
    FILE* fp = fopen("\x0a","w");
    fwrite("\x00\x00\x00\x00",4,1,fp);
    fclose(fp);
 
    if ( ( childpid = fork() ) < 0 ){
        perror("Cannot fork");
        exit(1);
    }
     
    if ( childpid == 0 ){
        /* Child process */
        close(pipe2stdin[0]); close(pipe2stderr[0]); // Close pipes for reading 
        write(pipe2stdin[1],"\x00\x0a\x00\xff",4);
        write(pipe2stderr[1],"\x00\x0a\x02\xff",4);
         
    } 
    else {
        /* Parent process */
        close(pipe2stdin[1]); close(pipe2stderr[1]);   // Close pipes for writing
        dup2(pipe2stdin[0],0); dup2(pipe2stderr[0],2); // Map to stdin and stderr 
        close(pipe2stdin[0]); close(pipe2stderr[1]);   // Close write end (the fd has been copied before)
        // Stage 3
        char *env[2] = {"\xde\xad\xbe\xef=\xca\xfe\xba\xbe", NULL};
        execve("/home/input/input",argv,env);   // Execute the program  
        perror("Fail to execute the program");
        exit(1);
    }
 
        // Stage 5
        sleep(5);
        int sockfd;
        struct sockaddr_in server;
        sockfd = socket(AF_INET,SOCK_STREAM,0);
        if ( sockfd < 0){
            perror("Cannot create the socket");
            exit(1);
        }
        server.sin_family = AF_INET;
        server.sin_addr.s_addr = inet_addr("127.0.0.1");
        server.sin_port = htons(55555);
        if ( connect(sockfd, (struct sockaddr*) &server, sizeof(server)) < 0 ){
            perror("Problem connecting");
            exit(1);
        }
        printf("Connected\n");
        char buf[4] = "\xde\xad\xbe\xef";
        write(sockfd,buf,4);
        close(sockfd);
        return 0;
}
```

We execute it and finally get the flag: 

    Let's see if you know how to give input to program
    Just give me correct inputs then you will get the flag :)
    Stage 1 clear!
    Stage 2 clear!
    Stage 3 clear!
    Stage 4 clear!

    Stage 5 clear!
    Mommy! I ********************** input in Linux :)

