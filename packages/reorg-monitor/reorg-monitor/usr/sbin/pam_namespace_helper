#!/bin/sh

CONF=/etc/security/namespace.conf

# Match logic of process_line(), except lines with $HOME are ignored
# skip the leading white space, rip off the comments, ignore empty lines
sed -e 's/^[ 	]*//g' -e 's/#.*//g' -e '/.*\$HOME.*/d'  -e '/^$/d' < $CONF | \
    while read polydir instance_prefix method uids; do
	if [ ! -e "$instance_prefix" ]; then
	    echo "mkdir $instance_prefix"
	    mkdir --parents --mode=0 -Z "$instance_prefix"
	fi
    done

exit 0
