#! /bin/sh
# savelog - save a log file
#    Copyright (C) 1987, 1988 Ronald S. Karr and Landon Curt Noll
#    Copyright (C) 1992  Ronald S. Karr
# Slight modifications by Ian A. Murdock <imurdock@gnu.ai.mit.edu>:
#	* uses `gzip' rather than `compress'
#	* doesn't use $savedir; keeps saved log files in the same directory
#	* reports successful rotation of log files
#	* for the sake of consistency, files are rotated even if they are
#	  empty
# More modifications by Guy Maor <maor@debian.org>:
#       * cleanup.
#       * -p (preserve) option
# 
# usage: savelog [-m mode] [-u user] [-g group] [-t] [-p] [-c cycle]
#		 [-j] [-C] [-d] [-l] [-r rolldir] [-n] [-q] file...
#	-m mode	  - chmod log files to mode
#	-u user	  - chown log files to user
#	-g group  - chgrp log files to group
#	-c cycle  - save cycle versions of the logfile	(default: 7)
#	-r rolldir- use rolldir instead of . to roll files
#	-C	  - force cleanup of cycled logfiles
#	-d	  - use standard date for rolling
#	-D	  - override date format for -d 
#	-t	  - touch file
#	-l	  - don't compress any log files	(default: compress)
#       -p        - preserve mode/user/group of original file
#	-j        - use bzip2 instead of gzip
#	-J        - use xz instead of gzip
#	-1 .. -9  - compression strength or memory usage (default: 9, except for xz)
#	-x script - invoke script with rotated log file in $FILE
#	-n	  - do not rotate empty files
#	-q	  - be quiet
#	file 	  - log file names
#
# The savelog command saves and optionally compresses old copies of files.
# Older version of 'file' are named:
#
#		'file'.<number><compress_suffix>
#
# where <number> is the version number, 0 being the newest.  By default,
# version numbers > 0 are compressed (unless -l prevents it). The
# version number 0 is never compressed on the off chance that a process
# still has 'file' opened for I/O.
#
# if the '-d' option is specified, <number> will be YYMMDDhhmmss
#
# If the 'file' does not exist and -t was given, it will be created.
#
# For files that do exist and have lengths greater than zero, the following 
# actions are performed.
#
#	1) Version numered files are cycled.  That is version 6 is moved to
#	   version 7, version is moved to becomes version 6, ... and finally
#	   version 0 is moved to version 1.  Both compressed names and
#	   uncompressed names are cycled, regardless of -t.  Missing version 
#	   files are ignored.
#
#	2) The new file.1 is compressed and is changed subject to 
#	   the -m, -u and -g flags.  This step is skipped if the -t flag 
#	   was given.
#
#	3) The main file is moved to file.0.
#
#	4) If the -m, -u, -g, -t, or -p flags are given, then the file is
#          touched into existence subject to the given flags.  The -p flag
#          will preserve the original owner, group, and permissions.
#
#	5) The new file.0 is changed subject to the -m, -u and -g flags.
#
# Note: If no -m, -u, -g, -t, or -p is given, then the primary log file is 
#	not created.
#
# Note: Since the version numbers start with 0, version number <cycle>
#       is never formed.  The <cycle> count must be at least 2.
#
# Bugs: If a process is still writing to the file.0 and savelog
#	moved it to file.1 and compresses it, data could be lost.
#	Smail does not have this problem in general because it
#	restats files often.

# common location
export PATH=$PATH:/sbin:/bin:/usr/sbin:/usr/bin
COMPRESS="gzip"
COMPRESS_OPTS="-f"
COMPRESS_STRENGTH_DEF="-9";
DOT_Z=".gz"
DATUM=`date +%Y%m%d%H%M%S`

# parse args
exitcode=0	# no problems to far
prog=`basename $0`
mode=
user=
group=
touch=
forceclean=
rolldir=
datum=
preserve=
hookscript=
quiet=0
rotateifempty=yes
count=7

usage()
{
    echo "Usage: $prog [-m mode] [-u user] [-g group] [-t] [-c cycle] [-p]"
    echo "             [-j] [-C] [-d] [-l] [-r rolldir] [-n] [-q] file ..."
    echo "	-m mode	   - chmod log files to mode"
    echo "	-u user	   - chown log files to user"
    echo "	-g group   - chgrp log files to group"
    echo "	-c cycle   - save cycle versions of the logfile (default: 7)"
    echo "	-r rolldir - use rolldir instead of . to roll files"
    echo "	-C	   - force cleanup of cycled logfiles"
    echo "	-d	   - use standard date for rolling"
    echo "	-D	   - override date format for -d"
    echo "	-t	   - touch file"
    echo "	-l	   - don't compress any log files (default: compress)"
    echo "	-p         - preserve mode/user/group of original file"
    echo "	-j         - use bzip2 instead of gzip"
    echo "	-J         - use xz instead of gzip"
    echo "	-1 .. -9   - compression strength or memory usage (default: 9, except for xz)"
    echo "	-x script  - invoke script with rotated log file in \$FILE"
    echo "	-n         - do not rotate empty files"
    echo "	-q         - suppress rotation message"
    echo "	file 	   - log file names"
}


fixfile()
{
    if [ -n "$user" ]; then
	chown -- "$user" "$1"
    fi
    if [ -n "$group" ]; then 
	chgrp -- "$group" "$1"
    fi
    if [ -n "$mode" ]; then 
	chmod -- "$mode" "$1"
    fi
}


while getopts m:u:g:c:r:CdD:tlphjJ123456789x:nq opt ; do
	case "$opt" in
	m) mode="$OPTARG" ;;
	u) user="$OPTARG" ;;
	g) group="$OPTARG" ;;
	c) count="$OPTARG" ;;
	r) rolldir="$OPTARG" ;;
	C) forceclean=1 ;;
	d) datum=1 ;;
	D) DATUM=$(date +$OPTARG) ;;
	t) touch=1 ;;
	j) COMPRESS="bzip2"; COMPRESS_OPTS="-f"; COMPRESS_STRENGTH_DEF="-9"; DOT_Z=".bz2" ;;
	J) COMPRESS="xz"; COMPRESS_OPTS="-f"; COMPRESS_STRENGTH_DEF=""; DOT_Z=".xz" ;;
	[1-9]) COMPRESS_STRENGTH="-$opt" ;;
	x) hookscript="$OPTARG" ;;
	l) COMPRESS="" ;;
	p) preserve=1 ;;
	n) rotateifempty="no" ;;
	q) quiet=1 ;;
	h) usage; exit 0 ;;
	*) usage; exit 1 ;;
	esac
done

shift $(($OPTIND - 1))

if [ "$count" -lt 2 ]; then
	echo "$prog: count must be at least 2" 1>&2
	exit 2
fi

if [ -n "$COMPRESS" ] && [ -z "$(command -v $COMPRESS)"  ]; then
       echo "$prog: Compression binary not available, please make sure '$COMPRESS' is installed" 1>&2
       exit 2
fi

if [ -n "$COMPRESS_STRENGTH" ]; then
	COMPRESS_OPTS="$COMPRESS_OPTS $COMPRESS_STRENGTH"
else
	COMPRESS_OPTS="$COMPRESS_OPTS $COMPRESS_STRENGTH_DEF"
fi

# cycle thru filenames
while [ $# -gt 0 ]; do

	# get the filename
	filename="$1"
	shift

	# catch bogus files
	if [ -e "$filename" ] && [ ! -f "$filename" ]; then
		echo "$prog: $filename is not a regular file" 1>&2
		exitcode=3
		continue
	fi

	# if file does not exist or is empty, and we've been told to not rotate
	# empty files, create if requested and skip to the next file.
	if [ ! -s "$filename" ] && [ "$rotateifempty" = "no" ]; then
		# if -t was given and it does not exist, create it
		if test -n "$touch" && [ ! -f "$filename" ]; then 
			touch -- "$filename"
			if [ "$?" -ne 0 ]; then
				echo "$prog: could not touch $filename" 1>&2
				exitcode=4
				continue
			fi
			fixfile "$filename"
		fi
		continue
	# otherwise if the file does not exist and we've been told to rotate it
	# anyway, create an empty file to rotate.
	elif [ ! -e "$filename" ]; then
		touch -- "$filename"
		if [ "$?" -ne 0 ]; then
			echo "$prog: could not touch $filename" 1>&2
			exitcode=4
			continue
		fi
		fixfile "$filename"
	fi

 	# be sure that the savedir exists and is writable
	# (Debian default: $savedir is . and not ./OLD)
 	savedir=`dirname -- "$filename"`
 	if [ -z "$savedir" ]; then
 		savedir=.
 	fi
	case "$rolldir" in
		(/*)
		savedir="$rolldir"
		;;
		(*)
		savedir="$savedir/$rolldir"
		;;
	esac
 	if [ ! -d "$savedir" ]; then
 		mkdir -p -- "$savedir"
 		if [ "$?" -ne 0 ]; then
 			echo "$prog: could not mkdir $savedir" 1>&2
 			exitcode=5
 			continue
 		fi
 		chmod 0755 -- "$savedir"
 	fi
 	if [ ! -w "$savedir" ]; then
 		echo "$prog: directory $savedir is not writable" 1>&2
 		exitcode=7
 		continue
 	fi
 
	# determine our uncompressed file names
	newname=`basename -- "$filename"`
	newname="$savedir/$newname"

	# cycle the old compressed log files
	cycle=$(( $count - 1))
	rm -f -- "$newname.$cycle" "$newname.$cycle$DOT_Z"
	while [ $cycle -gt 1 ]; do
		# --cycle
		oldcycle=$cycle
		cycle=$(( $cycle - 1 ))
		# cycle log
		if [ -f "$newname.$cycle$DOT_Z" ]; then
			mv -f -- "$newname.$cycle$DOT_Z" \
			    "$newname.$oldcycle$DOT_Z"
		fi
		if [ -f "$newname.$cycle" ]; then
			# file was not compressed. move it anyway
			mv -f -- "$newname.$cycle" "$newname.$oldcycle"
		fi
	done

	# compress the old uncompressed log if needed
	if [ -f "$newname.0" ]; then
		if [ -z "$COMPRESS" ]; then
			newfile="$newname.1"
			mv -f -- "$newname.0" "$newfile"
		else
			newfile="$newname.1$DOT_Z"
#			$COMPRESS $COMPRESS_OPTS < $newname.0 > $newfile
#			rm -f $newname.0
			$COMPRESS $COMPRESS_OPTS "$newname.0"
			mv -f -- "$newname.0$DOT_Z" "$newfile"
		fi
		fixfile "$newfile"
	fi

	# compress the old uncompressed log if needed
	if test -n "$datum" && test -n "$COMPRESS"; then
		$COMPRESS $COMPRESS_OPTS -- "$newname".[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]
	fi

	# remove old files if so desired
	if [ -n "$forceclean" ]; then
		cycle=$(( $count - 1))
		if [ -z "$COMPRESS" ]; then
			list=$(ls -t -- $newname.[0-9]* 2>/dev/null | sed -e 1,${cycle}d)
			if [ -n "$list" ]; then
				rm -f -- $list
			fi
		else
			list=$(ls -t -- $newname.[0-9]*$DOT_Z 2>/dev/null | sed -e 1,${cycle}d)
			if [ -n "$list" ]; then
				rm -f -- $list
			fi
		fi
	fi

	# create new file if needed
	if [ -n "$preserve" ]; then
		(umask 077
		 touch -- "$filename.new"
		 chown --reference="$filename" -- "$filename.new"
		 chmod --reference="$filename" -- "$filename.new")
		filenew=1
	elif [ -n "$touch$user$group$mode" ]; then
		touch -- "$filename.new"
		fixfile "$filename.new"
		filenew=1
	fi

	newfilename="$newname.0"
	# link the file into the file.0 holding place
	if [ -f "$filename" ]; then
		if [ -n "$filenew" ]; then
			if ln -f -- "$filename" "$newfilename"; then
				mv -f -- "$filename.new" "$filename"
			else
				echo "Error hardlinking $filename to $newfilename" >&2
				exitcode=8
				continue
			fi
		else
			mv -f -- "$filename" "$newfilename"
		fi
	fi
	[ ! -f "$newfilename" ] && touch -- "$newfilename"
	fixfile "$newfilename"
	if [ -n "$datum" ]; then
		mv -- "$newfilename" "$newname.$DATUM"
		newfilename="$newname.$DATUM"
	fi

	if [ -n "$hookscript" ]; then
	  FILE="$newfilename" $SHELL -c "$hookscript" || \
	  {
	    ret=$?
	    test "$quiet" -eq 1 || echo "Hook script failed with exit code $ret." 1>&2
	  }
	fi

	# report successful rotation
	test "$quiet" -eq 1 || echo "Rotated \`$filename' at `date`."
done
exit $exitcode
