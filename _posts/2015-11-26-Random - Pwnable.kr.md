---
title: Random - Pwnable.kr
date: 2015-11-26
categories: [Writeups, Pwnable.kr]
tags: ['PRNG']
image:
    path: "/unsorted/pwnablekr.png"

---


Let's have a look at random.c:

![Code random.c](/unsorted/screenshot-2015-11-25-225147.png)

A little research on google shows that the ^ operator is the XOR bitwise
operator, what we need is a key that applied to 'random' using this operator
gives us the value 0xdeadbeef.

What's the value of 'random'? It is the result of the function rand.  A little
research on google can help us again to understand how the function rand works:

The function rand returns a pseudo random value between 0 and RAND_MAX (a
constant defined in stdlib.h). It is called "pseudo random" because it doesn't
actually return a totally random value but it returns the entries of a
somehow [predictable "list" of numbers](
https://stackoverflow.com/questions/1026327/what-common-algorithms-are-used-for-cs-rand)
, this "list" will necessarily repeat itself after a certain period.

Here's the scoop: rand needs a point where to start.  Usually this point (seed)
is set using the function srand with some not predictable value (often the
time).

In our case, when no seed is set the function rand will start to calculate
random values from a predictable point.  This means that, at every execution,
rand will always return the same number!

In order to know which is the first number returned by rand, we can write a
little program in C who writes it down.

I did it and, in my case it was 1804289383 or 0x6b8b4567 in hex. A little math
tells us that the number that will give us 0xdeadbeef with a xor bitwise
operation is: 0xb5****88 who translated in decimals is 30******56.

We type the decimal-encoded version and we get the flag:

    Mommy*********************redictable...

