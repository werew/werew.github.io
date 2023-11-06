---
title: Leviathan Walkthrough - OverTheWire.org
date: 2015-11-19
categories: [Writeups, OverTheWire.org]
image:
    path: "unsorted/levi.jpg"
---


Leviathan is a one of the easiest wargames hosted by the famous website OTW
([overthewire.org](https://overthewire.org)).

Here is a short walktrough of it's 7 levels :)

**leviathan0**

For the first level you will easily find the pass inside this file: 
*~/.backup/bookmarks.html*

Password: rioGegei8m



**leviathan1**


The program `check` has SUID rights on leviathan2, we need to find the right
string in order to pass the level. This can be easily done using ltrace (this
command will shows the calls to the standard library, and with them the string
we are searching) or even disassembling it. The string is "sex" (eheh) now we
pass it to `check` and we get the good rights to access the password.

The password is in: */etc/leviathan_pass/leviathan2*

Password: ougahZi8Ta



**leviathan2**


In order to pass this level we need to win the race condition changing the
rights to access the file between access() and system().  More informations
about race conditions: <https://www.win.tue.nl/~aeb/linux/hh/hh-9.html#ss9.1>

I wrote a small script that will do the job:

```bash
#!/bin/sh

touch /tmp/myfile132142

while true; do
    ln -sf /tmp/myfile132142 /tmp/mylink132142  &
    /home/leviathan2/printfile /tmp/mylink132142 &
    ln -sf /etc/leviathan_pass/leviathan3 /tmp/mylink132142 &
done        
```


We can finally see the password

Password: Ahdiemoo1j



**leviathan3**


As the previous level we can use ltrace to get the correct string, this time:
`snlprintf` and now we can get a terminal and the password to the next level.

Password: vuH0coox6m



**leviathan4**


The program bin under the directory .trash opens the file
*/etc/leviathan_pass/leviathan5* and translate it in binary, we just need to
translate it back.

Password: Tith4cokei



**leviathan5**

In order to pass this level just make a link from */tmp/file.log* to 
*/etc/leviathan_pass/leviathan6* and run the program *./leviathan5*.

Password: UgaoFee4li


**leviathan6**

We need to get the correct number, for this we have 2 ways: brute force the
program or find the number directly analysing the code. The number is 7123.

Password: ahy7MaeBo9

