#!/bin/sh

NAME="bincur.sh"
# fsoppelsa@rhx.it
#

detectwget() {
	`type wget > /dev/null`
	if [ ! "$?" = 0 ]
	then
		echo "Please install wget before proceeding (pkgsrc/net/wget)"
		exit 1
	fi
}

usage() {
	echo "Usage: sh $NAME [-p PATH] [-d] [-i] [-y] [-k] [-s SET]"
	echo "	-p: specify the folder where put the sets (default ~/.sets)"
	echo "	-d: perform the download of sets"
	echo "	-dx: include X sets"
	echo "	-i: install all the sets WITHOUT the kernel"
	echo "	-y: as -di but without interactive confirmations"
	echo "	-k: also install the generic kernel"
	echo "	-s: download only the specified set SET"
}

BASE=
ARCH=
CKSM=SHA512

findcorrectroot() {
	OK=FALSE
	MINUS=0

	echo "Calculating basedir of most recent -current snapshot. Please wait..."
	wget -q ftp://nyftp.netbsd.org//pub/NetBSD-daily/HEAD/ -O .head.prov

	if [ ! -f .head.prov ]
	then
		echo Some error in downloading index file occured
		exit 
	fi

	# This loop is truly a mess! But it works
	while [ "$OK" = FALSE ]
	do
		(grep "a href" .head.prov > .head.1) 
		LAST=`cat ".head.1" | wc -l` 
		LAST=$(( $LAST - $MINUS ))
		sed -n "$LAST"p .head.1 | cut -d\" -f 2 > .head.base

		# Now $BASE points to the basedir of newest current snapshot
		BASE=`cat .head.base`
		ARCH=`uname -m`

		wget -q "$BASE/$ARCH/binary/sets/" -O .head.3
		if [ ! -s .head.3 ]
		then
			MINUS=$(( $MINUS + 1 ))
		else
			OK=TRUE
		fi

		if [ $(( $LAST - $MINUS )) -eq 0 ]
		then
			echo "Sorry, no binary snapshots available at the moment"
			exit 1
		fi
	done;

	rm .head.base .head.3
}


DOWNLOAD=FALSE
KERNEL=FALSE
X11=FALSE
YES=FALSE
ONLYSET=FALSE
PROCEED=FALSE
TMP="$HOME/.sets"

if [ "$#" -lt 1 ]
then
	usage
	exit 0
fi


while getopts p:dxkiys: option
do
	case "$option"
	in
		p) TMP=$OPTARG;;
		d) DOWNLOAD=TRUE;;
		x) X11=TRUE;;
		k) KERNEL=TRUE;;
		i) YES=TRUE;;
		y) PROCEED=TRUE;;
		s) ONLYSET=TRUE
		   SETTODOWN=$OPTARG;;
	       \?) usage
		   exit 0;;
	esac
done

if [ ! -d "$TMP" ]
then
	mkdir "$TMP"
fi

TMP="$TMP/"

if [ "$ONLYSET" = TRUE ]
then
	detectwget

	findcorrectroot

	cd "$TMP"

	echo "Downloading $SETTODOWN..."
	wget -q "$BASE/$ARCH/binary/sets/$SETTODOWN"
fi
	
if [ "$DOWNLOAD" = TRUE -o "$PROCEED" = TRUE ]
then
	detectwget
	
	findcorrectroot

	cd "$TMP"
	for currentset in base.tgz comp.tgz etc.tgz games.tgz man.tgz misc.tgz text.tgz
	do
		echo "Downloading $currentset..."
		wget -q "$BASE/$ARCH/binary/sets/$currentset"
	done

	if [ "$X11" = TRUE ]
	then
		for xset in xbase.tgz xcomp.tgz xetc.tgz xfont.tgz xserver.tgz
		do
			echo "Downloading $xset..."
			wget -q "$BASE/$ARCH/binary/sets/$xset"
		done
	fi

	if [ "$KERNEL" = TRUE ]
	then
		echo "Downloading generic kernel..."
		wget -q "$BASE/$ARCH/binary/sets/kern-GENERIC.tgz"
	fi
fi

if [ "$YES" = TRUE -o "$PROCEED" = TRUE ]
then
	cd "$TMP"

	# Set the default install or not
	if [ "$PROCEED" = TRUE ]
	then
		USERLAND=y
	else
		USERLAND=n
	fi

	if [ ! "$KERNEL" = TRUE -a ! "$PROCEED" = TRUE ]
	then
		printf "
WARNING: be sure you are running the latest kernel version now!
If not, installing the new userland could compromise the system behaviour.
Please install a new binary kernel snapshot, or a custom kernel, and reboot
the newest kernel version before proceeding

Continue installing userland? (y/N) "

		read USERLAND
	fi

	if [ "$USERLAND" = y ]
	then
		findcorrectroot

		echo "Downloading checksum phile..."
		wget -q "$BASE/$ARCH/binary/sets/$CKSM" -O .SHA512

		if [ ! -f .SHA512 ]
		then
			echo "No checksum file found"
			exit 1
		fi

		for currentset in base.tgz comp.tgz games.tgz man.tgz misc.tgz text.tgz
		do
			if [ ! -f "$TMP/$currentset" -a ! "$PROCEED" = TRUE ]
			then
				printf "
$TMP/$currentset not found, aborting
please retry with ./$NAME -s $currentset, if available
or force the installation of other sets by typing 'f' "

				read force
				if [ ! "$force" = f ]
				then
					exit 1
				fi
			fi

			# Extract checksums
			`grep \($currentset .SHA512 > .tmpcksm`
			echo "Checksumming $currentset"

			NWCK=`cut -d ' ' -f 4 .tmpcksm`
			`cksum -a sha512 "$TMP/$currentset" > .tmpcksm`
			MYCK=`cut -d ' ' -f 4 .tmpcksm`
			rm .tmpcksm

			if [ ! "$NWCK" = "$MYCK" ]
			then
				"Local $currentset and remote have different checksums. Exiting."
				exit 1
				rm .SHA512
			fi
		done
		
		rm .SHA512 

		for currentset in base.tgz comp.tgz games.tgz man.tgz misc.tgz text.tgz
		do
			echo "Extracting $currentset..."
			tar xzfp "$TMP/$currentset" -C /
		done
	
		if [ "$X11" = TRUE ]
		then
			for xset in xbase.tgz xcomp.tgz xetc.tgz xfont.tgz xserver.tgz
			do
				echo "Extracting $xset..."
				tar xzfp "$TMP/$xset" -C /
			done
		fi

		# etcupdate
		if [ -f "$TMP/etc.tgz" ]
		then
			echo "Etcupdate procedure..."
			tar xzfvp "$TMP/etc.tgz" -C "$TMP"
			etcupdate -s "$TMP"
		else
			echo "etc.tgz not found: etcupdate will be skipped"
		fi
	fi

	if [ "$KERNEL" = TRUE ]
	then
		echo "Installing the GENERIC kernel in /"
		echo "Old kernel has been moved to /onetbsd"
		mv /netbsd /onetbsd
		tar xzfv "$TMP/kern-GENERIC.tgz" -C /
	fi

	printf "Do you want to remove sets now? (y/N) "

	read REM

	if [ "$REM" = y ]
	then
		rm -fr "$TMP/"
	fi
fi

echo "Your system is now updated to latest snapshot available at releng.NetBSD"
echo
