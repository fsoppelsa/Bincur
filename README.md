bincur.sh
=========

bincur.sh is a /bin/sh script I use to track NetBSD-current from daily
binary snapshots without ./build.sh and tons of make and gcc and blah
blah every time.

It automatically fetches the latest shots from the latest HEAD master
at top ftp://nyftp.netbsd.org.

Please refer to the online help for usage.

Bug reports and feature requests:  
https://github.com/fsoppelsa/Bincur

Getting started
===============

Please be sure you have enough disk space for the .tgz files.

Carefully read the help by typing `./bincur.sh`

Basic syntax is:

	./bincur.sh [-p PATH] [-d] [-i] [-y] [-k] [-s SET]"
		-p: specify the folder where put the sets (default ~/.sets)
		-d: perform the download of sets
		-dx: include X sets
		-i: install all the sets WITHOUT the kernel
		-y: as -di but without interactive confirmations
		-k: also install the generic kernel
		-s: download only the specified set SET

Warning!!!
==========

When you decide to use the **-k** option please make sure you **DO KNOW**
what you're doing.

Ideas
=====

* Integration with newest LKM is not done yet.
* Logging actions might be interesting
* More beautiful cleaning procedure
