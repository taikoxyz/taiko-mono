#
# Set rcS vars
#

# Because /etc/default/rcS isn't a conffile, it's never updated
# automatically.  So that an empty or outdated file missing newer
# options works correctly, set the default values here.
TMPTIME=0
SULOGIN=no
DELAYLOGIN=no
UTC=yes
VERBOSE=no
FSCKFIX=no

# Source conffile
if [ -f /etc/default/rcS ]; then
    . /etc/default/rcS
fi

# Unset old unused options
unset EDITMOTD
unset RAMRUN
unset RAMLOCK
# Don't unset RAMSHM and RAMTMP for now.

# Parse kernel command line
if [ -r /proc/cmdline ]; then
    for ARG in $(cat /proc/cmdline); do
        case $ARG in

            # check for bootoption 'noswap' and do not activate swap
            # partitions/files when it is set.
            noswap)
		NOSWAP=yes
		;;

            # Accept the same 'quiet' option as the kernel, but only
            # during boot and shutdown.  Only use this rule when the
            # variables set by init.d/rc is present.
            quiet)
		if [ "$RUNLEVEL" ] && [ "$PREVLEVEL" ] ; then
		    VERBOSE="no"
		fi
		;;
	esac
    done
fi

# But allow both rcS and the kernel options 'quiet' to be overrided
# when INIT_VERBOSE=yes is used as well.
if [ "$INIT_VERBOSE" ] ; then
    VERBOSE="$INIT_VERBOSE"
fi
