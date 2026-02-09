#!/bin/sh

### BEGIN INIT INFO
# Provides:          hwclock
# Required-Start:
# Required-Stop:     mountdevsubfs
# Should-Stop:       umountfs
# Default-Start:     S
# Default-Stop:      0 6
# Short-Description: Save system clock to hardware on shutdown.
### END INIT INFO

# Note: this init script and related code is only useful if you
# run a sysvinit system, without NTP synchronization.

if [ -e /run/systemd/system ] ; then
    exit 0
fi

unset TZ

hwclocksh()
{
    HCTOSYS_DEVICE=rtc0
    [ ! -x /sbin/hwclock ] && return 0
    [ ! -r /etc/default/rcS ] || . /etc/default/rcS
    [ ! -r /etc/default/hwclock ] || . /etc/default/hwclock

    . /lib/lsb/init-functions
    verbose_log_action_msg() { [ "$VERBOSE" = no ] || log_action_msg "$@"; }

    case "$1" in
        start)
            # start is handled by /usr/lib/udev/rules.d/85-hwclock.rules.
            return 0
            ;;
        stop|restart|reload|force-reload)
            # Updates the Hardware Clock with the System Clock time.
            # This will *override* any changes made to the Hardware Clock,
            # for example by the Linux kernel when NTP is in use.
            log_action_msg "Saving the system clock to /dev/$HCTOSYS_DEVICE"
            if /sbin/hwclock --rtc=/dev/$HCTOSYS_DEVICE --systohc; then
                verbose_log_action_msg "Hardware Clock updated to `date`"
            fi
            ;;
        show)
            /sbin/hwclock --rtc=/dev/$HCTOSYS_DEVICE --show
            ;;
        *)
            log_success_msg "Usage: hwclock.sh {stop|reload|force-reload|show}"
            log_success_msg "       stop and reload set hardware (RTC) clock from kernel (system) clock"
            return 1
            ;;
    esac
}

hwclocksh "$@"
