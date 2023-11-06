---
title: Memcpy - Pwnable.kr
date: 2016-06-29
categories: [Writeups, Pwnable.kr]
tags: ['Memcpy']
image:
    path: "/unsorted/pwnablekr.png"

---

This time we have to test the performance of two different implementations of
the function memcpy.  This is the code:

```c
// compiled with : gcc -o memcpy memcpy.c -m32 -lm
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <signal.h>
#include <unistd.h>
#include <sys/mman.h>
#include <math.h>

unsigned long long rdtsc(){
		asm("rdtsc");
}

char* slow_memcpy(char* dest, const char* src, size_t len){
	int i;
	for (i=0; i<len; i++) {
		dest[i] = src[i];
	}
	return dest;
}

char* fast_memcpy(char* dest, const char* src, size_t len){
	size_t i;
	// 64-byte block fast copy
	if(len >= 64){
		i = len / 64;
		len &= (64-1);
		while(i-- > 0){
			__asm__ __volatile__ (
			"movdqa (%0), %%xmm0\n"
			"movdqa 16(%0), %%xmm1\n"
			"movdqa 32(%0), %%xmm2\n"
			"movdqa 48(%0), %%xmm3\n"
			"movntps %%xmm0, (%1)\n"
			"movntps %%xmm1, 16(%1)\n"
			"movntps %%xmm2, 32(%1)\n"
			"movntps %%xmm3, 48(%1)\n"
			::"r"(src),"r"(dest):"memory");
			dest += 64;
			src += 64;
		}
	}

	// byte-to-byte slow copy
	if(len) slow_memcpy(dest, src, len);
	return dest;
}

int main(void){

	setvbuf(stdout, 0, _IONBF, 0);
	setvbuf(stdin, 0, _IOLBF, 0);

	printf("Hey, I have a boring assignment for CS class.. :(\n");
	printf("The assignment is simple.\n");

	printf("-----------------------------------------------------\n");
	printf("- What is the best implementation of memcpy?        -\n");
	printf("- 1. implement your own slow/fast version of memcpy -\n");
	printf("- 2. compare them with various size of data         -\n");
	printf("- 3. conclude your experiment and submit report     -\n");
	printf("-----------------------------------------------------\n");

	printf("This time, just help me out with my experiment and get flag\n");
	printf("No fancy hacking, I promise :D\n");

	unsigned long long t1, t2;
	int e;
	char* src;
	char* dest;
	unsigned int low, high;
	unsigned int size;
	// allocate memory
	char* cache1 = mmap(0, 0x4000, 7, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0);
	char* cache2 = mmap(0, 0x4000, 7, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0);
	src = mmap(0, 0x2000, 7, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0);

	size_t sizes[10];
	int i=0;

	// setup experiment parameters
	for(e=4; e<14; e++){	// 2^13 = 8K
		low = pow(2,e-1);
		high = pow(2,e);
		printf("specify the memcpy amount between %d ~ %d : ", low, high);
		scanf("%d", &size);
		if( size < low || size > high ){
			printf("don't mess with the experiment.\n");
			exit(0);
		}
		sizes[i++] = size;
	}

	sleep(1);
	printf("ok, lets run the experiment with your configuration\n");
	sleep(1);

	// run experiment
	for(i=0; i<10; i++){
		size = sizes[i];
		printf("experiment %d : memcpy with buffer size %d\n", i+1, size);
		dest = malloc( size );

		memcpy(cache1, cache2, 0x4000);		// to eliminate cache effect
		t1 = rdtsc();
		slow_memcpy(dest, src, size);		// byte-to-byte memcpy
		t2 = rdtsc();
		printf("ellapsed CPU cycles for slow_memcpy : %llu\n", t2-t1);

		memcpy(cache1, cache2, 0x4000);		// to eliminate cache effect
		t1 = rdtsc();
		fast_memcpy(dest, src, size);		// block-to-block memcpy
		t2 = rdtsc();
		printf("ellapsed CPU cycles for fast_memcpy : %llu\n", t2-t1);
		printf("\n");
	}

	printf("thanks for helping my experiment!\n");
	printf("flag : ----- erased in this source code -----\n");
	return 0;
}
```



Once we have a look to the code we can see how this 2 versions are implemented:
- The first one is a simple byte to byte copy
- The second one uses four 128 registers at a time in order to copy blocks of
  64 bytes.  In addition it uses the instruction movntps to store the value
  copied in those registers into the destination. This instruction is
  particularly fast because it also asks the CPU not to sync the cache hierarchy
  (more infos: <https://x86.renejeschke.de/html/file_module_x86_id_197.html>)
  Also the destination operand should be 16 byte aligned.


At this point the next step for me was test the program running on the port
9022 with some values:

    ...
    specify the memcpy amount between 8 ~ 16 : 11
    specify the memcpy amount between 16 ~ 32 : 17
    specify the memcpy amount between 32 ~ 64 : 50
    specify the memcpy amount between 64 ~ 128 : 81
    specify the memcpy amount between 128 ~ 256 : 172
    specify the memcpy amount between 256 ~ 512 : 340
    specify the memcpy amount between 512 ~ 1024 : 801
    specify the memcpy amount between 1024 ~ 2048 : 1088
    specify the memcpy amount between 2048 ~ 4096 : 4027
    specify the memcpy amount between 4096 ~ 8192 : 6375
    ok, lets run the experiment with your configuration
    experiment 1 : memcpy with buffer size 11
    ellapsed CPU cycles for slow_memcpy : 1311
    ellapsed CPU cycles for fast_memcpy : 255

    experiment 2 : memcpy with buffer size 17
    ellapsed CPU cycles for slow_memcpy : 285
    ellapsed CPU cycles for fast_memcpy : 297

    experiment 3 : memcpy with buffer size 50
    ellapsed CPU cycles for slow_memcpy : 690
    ellapsed CPU cycles for fast_memcpy : 654

    experiment 4 : memcpy with buffer size 81
    ellapsed CPU cycles for slow_memcpy : 1095


Bad news...as we can see the program stops before calculating the elapsed time
for fast_memcpy.  That means no flag so far. Well, it would have been too
easy...

In order to understand why the program fails I compiled it in debug mode and
had a closer look at the behaviour of the function fast_memcpy. It turns out
that everything goes just fine until we execute the asm instruction movntps, is
at this point that the programs receive a SIGSEGV.

movntps fails probably because the destination address is not 16-byte
aligned...  Let's try with other numbers, but this time we print the address
stored on dest:

    experiment 1 : memcpy with buffer size 10
    ----------------- Address dest: 0x9f2c008 ----------------
    ellapsed CPU cycles for slow_memcpy : 1365
    ellapsed CPU cycles for fast_memcpy : 324

    experiment 2 : memcpy with buffer size 20
    ----------------- Address dest: 0x9f2c018 ----------------
    ellapsed CPU cycles for slow_memcpy : 351
    ellapsed CPU cycles for fast_memcpy : 390

    experiment 3 : memcpy with buffer size 40
    ----------------- Address dest: 0x9f2c030 ----------------
    ellapsed CPU cycles for slow_memcpy : 642
    ellapsed CPU cycles for fast_memcpy : 615

    experiment 4 : memcpy with buffer size 70
    ----------------- Address dest: 0x9f2c060 ----------------
    ellapsed CPU cycles for slow_memcpy : 1071
    ellapsed CPU cycles for fast_memcpy : 237

    experiment 5 : memcpy with buffer size 189
    ----------------- Address dest: 0x9f2c0b0 ----------------
    ellapsed CPU cycles for slow_memcpy : 2811
    ellapsed CPU cycles for fast_memcpy : 1098

    experiment 6 : memcpy with buffer size 412
    ----------------- Address dest: 0x9f2c178 ----------------
    ellapsed CPU cycles for slow_memcpy : 5586
    Segmentation fault


Until a size of 40 the 64-byte block fast copy is never executed.  With a size
of 70 and 189 the 64-byte block copy is executed successfully, in this case we
can see that the address 0x9f2c060 and 0x9f2c0b0 are both 16-byte aligned.  At
the experiment n.6 the program fails and as expected the address 0x9f2c178 is
not 16-byte aligned.

Ps: note that malloc allocates word-aligned blocks of memory. In the example a
word is 8 bytes long, 64 bits (so basically the program would have worked in a
128-bit architecture ^^ ). To have a different alignment when allocating
memory functions like memalign, aligned_malloc, valloc, etc...  should be used
rather than malloc.


Now, what we need to get the flag is a series of sizes that will generate
16-byte aligned memory allocations.  The previous example works fine until the
experiment 5, so I just changed the sizes from that point: 



    experiment 1 : memcpy with buffer size 10
    ellapsed CPU cycles for slow_memcpy : 1230
    ellapsed CPU cycles for fast_memcpy : 240

    experiment 2 : memcpy with buffer size 20
    ellapsed CPU cycles for slow_memcpy : 336
    ellapsed CPU cycles for fast_memcpy : 333

    experiment 3 : memcpy with buffer size 40
    ellapsed CPU cycles for slow_memcpy : 579
    ellapsed CPU cycles for fast_memcpy : 528

    experiment 4 : memcpy with buffer size 70
    ellapsed CPU cycles for slow_memcpy : 957
    ellapsed CPU cycles for fast_memcpy : 189

    experiment 5 : memcpy with buffer size 181
    ellapsed CPU cycles for slow_memcpy : 2226
    ellapsed CPU cycles for fast_memcpy : 873

    experiment 6 : memcpy with buffer size 412
    ellapsed CPU cycles for slow_memcpy : 4974
    ellapsed CPU cycles for fast_memcpy : 627

    experiment 7 : memcpy with buffer size 999
    ellapsed CPU cycles for slow_memcpy : 11931
    ellapsed CPU cycles for fast_memcpy : 1050

    experiment 8 : memcpy with buffer size 1769
    ellapsed CPU cycles for slow_memcpy : 20898
    ellapsed CPU cycles for fast_memcpy : 1083

    experiment 9 : memcpy with buffer size 2394
    ellapsed CPU cycles for slow_memcpy : 28407
    ellapsed CPU cycles for fast_memcpy : 1437

    experiment 10 : memcpy with buffer size 7811
    ellapsed CPU cycles for slow_memcpy : 97650
    ellapsed CPU cycles for fast_memcpy : 2961

    thanks for helping my experiment!
    flag : 1_****_*****_***_m3m0ry_4lignm3nt

Got it :)





