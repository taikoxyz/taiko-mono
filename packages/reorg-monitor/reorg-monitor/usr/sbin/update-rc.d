#! /usr/bin/perl
# vim: ft=perl
#
# update-rc.d	Update the links in /etc/rc[0-9S].d/
#

use strict;
use warnings;
# NB: All Perl modules used here must be in perl-base. Specifically, depending
# on modules in perl-modules is not okay! See bug #716923

my $initd = "/etc/init.d";
my $etcd  = "/etc/rc";
my $dpkg_root = $ENV{DPKG_ROOT} // '';

# Print usage message and die.

sub usage {
	print STDERR "update-rc.d: error: @_\n" if ($#_ >= 0);
	print STDERR <<EOF;
usage: update-rc.d [-f] <basename> remove
       update-rc.d [-f] <basename> defaults
       update-rc.d [-f] <basename> defaults-disabled
       update-rc.d <basename> disable|enable [S|2|3|4|5]
		-f: force

The disable|enable API is not stable and might change in the future.
EOF
	exit (1);
}

exit main(@ARGV);

sub info {
    print STDOUT "update-rc.d: @_\n";
}

sub warning {
    print STDERR "update-rc.d: warning: @_\n";
}

sub error {
    print STDERR "update-rc.d: error: @_\n";
    exit (1);
}

sub error_code {
    my $rc = shift;
    print STDERR "update-rc.d: error: @_\n";
    exit ($rc);
}

sub make_path {
    my ($path) = @_;
    my @dirs = ();
    my @path = split /\//, $path;
    map { push @dirs, $_; mkdir join('/', @dirs), 0755; } @path;
}

# Given a script name, return any runlevels except 0 or 6 in which the
# script is enabled.  If that gives nothing and the script is not
# explicitly disabled, return 6 if the script is disabled in runlevel
# 0 or 6.
sub script_runlevels {
    my ($scriptname) = @_;
    my @links=<"$dpkg_root/etc/rc[S12345].d/S[0-9][0-9]$scriptname">;
    if (@links) {
        return map(substr($_, 7, 1), @links);
    } elsif (! <"$dpkg_root/etc/rc[S12345].d/K[0-9][0-9]$scriptname">) {
        @links=<"$dpkg_root/etc/rc[06].d/K[0-9][0-9]$scriptname">;
        return ("6") if (@links);
    } else {
	return ;
    }
}

# Map the sysvinit runlevel to that of openrc.
sub openrc_rlconv {
    my %rl_table = (
        "S" => "sysinit",
        "1" => "recovery",
        "2" => "default",
        "3" => "default",
        "4" => "default",
        "5" => "default",
        "6" => "off" );

    my %seen; # return unique runlevels
    return grep !$seen{$_}++, map($rl_table{$_}, @_);
}

sub systemd_reload {
    if (length $ENV{DPKG_ROOT}) {
	# if we operate on a chroot from the outside, do not attempt to reload
	return;
    }
    if (-d "/run/systemd/system") {
        system("systemctl", "daemon-reload");
    }
}

# Creates the necessary links to enable/disable a SysV init script (fallback if
# no insserv/rc-update exists)
sub make_sysv_links {
    my ($scriptname, $action) = @_;

    # for "remove" we cannot rely on the init script still being present, as
    # this gets called in postrm for purging. Just remove all symlinks.
    if ("remove" eq $action) { unlink($_) for
        glob("$dpkg_root/etc/rc?.d/[SK][0-9][0-9]$scriptname"); return; }

    # if the service already has any links, do not touch them
    # numbers we don't care about, but enabled/disabled state we do
    return if glob("$dpkg_root/etc/rc?.d/[SK][0-9][0-9]$scriptname");

    # for "defaults", parse Default-{Start,Stop} and create these links
    my ($lsb_start_ref, $lsb_stop_ref) = parse_def_start_stop("$dpkg_root/etc/init.d/$scriptname");
    my $start = $action eq "defaults-disabled" ? "K" : "S";
    foreach my $lvl (@$lsb_start_ref) {
        make_path("$dpkg_root/etc/rc$lvl.d");
        my $l = "$dpkg_root/etc/rc$lvl.d/${start}01$scriptname";
        symlink("../init.d/$scriptname", $l);
    }

    foreach my $lvl (@$lsb_stop_ref) {
        make_path("$dpkg_root/etc/rc$lvl.d");
        my $l = "$dpkg_root/etc/rc$lvl.d/K01$scriptname";
        symlink("../init.d/$scriptname", $l);
    }
}

# Creates the necessary links to enable/disable the service (equivalent of an
# initscript) in systemd.
sub make_systemd_links {
    my ($scriptname, $action) = @_;

    # If called by systemctl (via systemd-sysv-install), do nothing to avoid
    # an endless loop.
    if (defined($ENV{_SKIP_SYSTEMD_NATIVE}) && $ENV{_SKIP_SYSTEMD_NATIVE} == 1) {
        return;
    }

    # If systemctl is available, let's use that to create the symlinks.
    if (-x "/bin/systemctl" || -x "/usr/bin/systemctl") {
        my $systemd_root = '/';
        if ($dpkg_root ne '') {
            $systemd_root = $dpkg_root;
        }
        # Set this env var to avoid loop in systemd-sysv-install.
        local $ENV{SYSTEMCTL_SKIP_SYSV} = 1;
        # Use --quiet to mimic the old update-rc.d behaviour.
        system("systemctl", "--root=$systemd_root", "--quiet", "$action", "$scriptname");
        return;
    }

    # In addition to the insserv call we also enable/disable the service
    # for systemd by creating the appropriate symlink in case there is a
    # native systemd service. In case systemd is not installed we do this
    # on our own instead of using systemctl.
    my $service_path;
    if (-f "/etc/systemd/system/$scriptname.service") {
        $service_path = "/etc/systemd/system/$scriptname.service";
    } elsif (-f "/lib/systemd/system/$scriptname.service") {
        $service_path = "/lib/systemd/system/$scriptname.service";
    } elsif (-f "/usr/lib/systemd/system/$scriptname.service") {
        $service_path = "/usr/lib/systemd/system/$scriptname.service";
    }
    if (defined($service_path)) {
        my $changed_sth;
        open my $fh, '<', $service_path or error("unable to read $service_path");
        while (<$fh>) {
            chomp;
            if (/^\s*WantedBy=(.+)$/i) {
                my $wants_dir = "/etc/systemd/system/$1.wants";
                my $service_link = "$wants_dir/$scriptname.service";
                if ("enable" eq $action) {
                    make_path($wants_dir);
                    symlink($service_path, $service_link);
                } else {
                    unlink($service_link) if -e $service_link;
                }
            }
        }
        close($fh);
    }
}

sub create_sequence {
    my $force = (@_);
    my $insserv = "/usr/lib/insserv/insserv";
    # Fallback for older insserv package versions [2014-04-16]
    $insserv = "/sbin/insserv" if ( -x "/sbin/insserv");
    # If insserv is not configured it is not fully installed
    my $insserv_installed = -x $insserv && -e "/etc/insserv.conf";
    my @opts;
    push(@opts, '-f') if $force;
    # Add force flag if initscripts is not installed
    # This enables inistcripts-less systems to not fail when a facility is missing
    unshift(@opts, '-f') unless is_initscripts_installed();

    my $openrc_installed = -x "/sbin/openrc";

    my $sysv_insserv ={};
    $sysv_insserv->{remove} = sub {
        my ($scriptname) = @_;
        if ( -f "/etc/init.d/$scriptname" ) {
            return system($insserv, @opts, "-r", $scriptname) >> 8;
        } else {
            # insserv removes all dangling symlinks, no need to tell it
            # what to look for.
            my $rc = system($insserv, @opts) >> 8;
            error_code($rc, "insserv rejected the script header") if $rc;
        }
    };
    $sysv_insserv->{defaults} = sub {
        my ($scriptname) = @_;
        if ( -f "/etc/init.d/$scriptname" ) {
            my $rc = system($insserv, @opts, $scriptname) >> 8;
            error_code($rc, "insserv rejected the script header") if $rc;
        } else {
            error("initscript does not exist: /etc/init.d/$scriptname");
        }
    };
    $sysv_insserv->{defaults_disabled} = sub {
        my ($scriptname) = @_;
        return if glob("/etc/rc?.d/[SK][0-9][0-9]$scriptname");
        if ( -f "/etc/init.d/$scriptname" ) {
            my $rc = system($insserv, @opts, $scriptname) >> 8;
            error_code($rc, "insserv rejected the script header") if $rc;
        } else {
            error("initscript does not exist: /etc/init.d/$scriptname");
        }
        sysv_toggle("disable", $scriptname);
    };
    $sysv_insserv->{toggle} = sub {
        my ($action, $scriptname) = (shift, shift);
        sysv_toggle($action, $scriptname, @_);

        # Call insserv to resequence modified links
        my $rc = system($insserv, @opts, $scriptname) >> 8;
        error_code($rc, "insserv rejected the script header") if $rc;
    };

    my $sysv_plain = {};
    $sysv_plain->{remove} = sub {
        my ($scriptname) = @_;
        make_sysv_links($scriptname, "remove");
    };
    $sysv_plain->{defaults} = sub {
        my ($scriptname) = @_;
        make_sysv_links($scriptname, "defaults");
    };
    $sysv_plain->{defaults_disabled} = sub {
        my ($scriptname) = @_;
        make_sysv_links($scriptname, "defaults-disabled");
    };
    $sysv_plain->{toggle} = sub {
        my ($action, $scriptname) = (shift, shift);
        sysv_toggle($action, $scriptname, @_);
    };

    my $systemd = {};
    $systemd->{remove} = sub {
        systemd_reload;
    };
    $systemd->{defaults} = sub {
        systemd_reload;
    };
    $systemd->{defaults_disabled} = sub {
        systemd_reload;
    };
    $systemd->{toggle} = sub {
        my ($action, $scriptname) = (shift, shift);
        make_systemd_links($scriptname, $action);
        systemd_reload;
    };

    # Should we check exit codeS?
    my $openrc = {};
    $openrc->{remove} = sub {
        my ($scriptname) = @_;
        system("rc-update", "-qqa", "delete", $scriptname);

    };
    $openrc->{defaults} = sub {
        my ($scriptname) = @_;
        # OpenRC does not distinguish halt and reboot.  They are handled
        # by /etc/init.d/transit instead.
        return if ("halt" eq $scriptname || "reboot" eq $scriptname);
        # no need to consider default disabled runlevels
        # because everything is disabled by openrc by default
        my @rls=script_runlevels($scriptname);
        if ( @rls ) {
            system("rc-update", "add", $scriptname, openrc_rlconv(@rls));
        }
    };
    $openrc->{defaults_disabled} = sub {
        # In openrc everything is disabled by default
    };
    $openrc->{toggle} = sub {
        my ($action, $scriptname) = (shift, shift);
        my (@toggle_lvls, $start_lvls, $stop_lvls, @symlinks);
        my $lsb_header = lsb_header_for_script($scriptname);

        # Extra arguments to disable|enable action are runlevels. If none
        # given parse LSB info for Default-Start value.
        if ($#_ >= 0) {
            @toggle_lvls = @_;
        } else {
            ($start_lvls, $stop_lvls) = parse_def_start_stop($lsb_header);
            @toggle_lvls = @$start_lvls;
            if ($#toggle_lvls < 0) {
                error("$scriptname Default-Start contains no runlevels, aborting.");
            }
        }
        my %openrc_act = ( "disable" => "del", "enable" => "add" );
        system("rc-update", $openrc_act{$action}, $scriptname,
               openrc_rlconv(@toggle_lvls))
    };

    my @sequence;
    if ($insserv_installed) {
        push @sequence, $sysv_insserv;
    }
    else {
        push @sequence, $sysv_plain;
    }
    # OpenRC has to be after sysv_{insserv,plain} because it depends on them to synchronize
    # states.
    if ($openrc_installed) {
        push @sequence, $openrc;
    }
    push @sequence, $systemd;

    return @sequence;
}

## Dependency based
sub main {
    my @args = @_;
    my $scriptname;
    my $action;
    my $force = 0;

    while($#args >= 0 && ($_ = $args[0]) =~ /^-/) {
        shift @args;
        if (/^-f$/) { $force = 1; next }
        if (/^-h|--help$/) { usage(); }
        usage("unknown option");
    }

    usage("not enough arguments") if ($#args < 1);

    my @sequence = create_sequence($force);

    $scriptname = shift @args;
    $action = shift @args;
    if ("remove" eq $action) {
        foreach my $init (@sequence) {
            $init->{remove}->($scriptname);
        }
    } elsif ("defaults" eq $action || "start" eq $action ||
             "stop" eq $action) {
        # All start/stop/defaults arguments are discarded so emit a
        # message if arguments have been given and are in conflict
        # with Default-Start/Default-Stop values of LSB comment.
        if ("start" eq $action || "stop" eq $action) {
            cmp_args_with_defaults($scriptname, $action, @args);
        }
        foreach my $init (@sequence) {
            $init->{defaults}->($scriptname);
        }
    } elsif ("defaults-disabled" eq $action) {
        foreach my $init (@sequence) {
            $init->{defaults_disabled}->($scriptname);
        }
    } elsif ("disable" eq $action || "enable" eq $action) {
        foreach my $init (@sequence) {
            $init->{toggle}->($action, $scriptname, @args);
        }
    } else {
        usage();
    }
}

sub parse_def_start_stop {
    my $script = shift;
    my (%lsb, @def_start_lvls, @def_stop_lvls);

    open my $fh, '<', $script or error("unable to read $script");
    while (<$fh>) {
        chomp;
        if (m/^### BEGIN INIT INFO\s*$/) {
            $lsb{'begin'}++;
        }
        elsif (m/^### END INIT INFO\s*$/) {
            $lsb{'end'}++;
            last;
        }
        elsif ($lsb{'begin'} and not $lsb{'end'}) {
            if (m/^# Default-Start:\s*(\S?.*)$/) {
                @def_start_lvls = split(' ', $1);
            }
            if (m/^# Default-Stop:\s*(\S?.*)$/) {
                @def_stop_lvls = split(' ', $1);
            }
        }
    }
    close($fh);

    return (\@def_start_lvls, \@def_stop_lvls);
}

sub lsb_header_for_script {
    my $name = shift;

    foreach my $file ("/etc/insserv/overrides/$name", "/etc/init.d/$name",
                      "/usr/share/insserv/overrides/$name") {
        return $file if -s $file;
    }

    error("cannot find a LSB script for $name");
}

sub cmp_args_with_defaults {
    my ($name, $act) = (shift, shift);
    my ($lsb_start_ref, $lsb_stop_ref, $arg_str, $lsb_str);
    my (@arg_start_lvls, @arg_stop_lvls, @lsb_start_lvls, @lsb_stop_lvls);

    ($lsb_start_ref, $lsb_stop_ref) = parse_def_start_stop("/etc/init.d/$name");
    @lsb_start_lvls = @$lsb_start_ref;
    @lsb_stop_lvls  = @$lsb_stop_ref;
    return if (!@lsb_start_lvls and !@lsb_stop_lvls);

    warning "start and stop actions are no longer supported; falling back to defaults";
    my $start = $act eq 'start' ? 1 : 0;
    my $stop = $act eq 'stop' ? 1 : 0;

    # The legacy part of this program passes arguments starting with
    # "start|stop NN x y z ." but the insserv part gives argument list
    # starting with sequence number (ie. strips off leading "start|stop")
    # Start processing arguments immediately after the first seq number.
    my $argi = $_[0] eq $act ? 2 : 1;

    while (defined $_[$argi]) {
        my $arg = $_[$argi];

        # Runlevels 0 and 6 are always stop runlevels
        if ($arg eq 0 or $arg eq 6) {
            $start = 0; $stop = 1;
        } elsif ($arg eq 'start') {
            $start = 1; $stop = 0; $argi++; next;
        } elsif ($arg eq 'stop') {
            $start = 0; $stop = 1; $argi++; next;
        } elsif ($arg eq '.') {
            next;
        }
        push(@arg_start_lvls, $arg) if $start;
        push(@arg_stop_lvls, $arg) if $stop;
    } continue {
        $argi++;
    }

    if ($#arg_start_lvls != $#lsb_start_lvls or
        join("\0", sort @arg_start_lvls) ne join("\0", sort @lsb_start_lvls)) {
        $arg_str = @arg_start_lvls ? "@arg_start_lvls" : "none";
        $lsb_str = @lsb_start_lvls ? "@lsb_start_lvls" : "none";
        warning "start runlevel arguments ($arg_str) do not match",
                "$name Default-Start values ($lsb_str)";
    }
    if ($#arg_stop_lvls != $#lsb_stop_lvls or
        join("\0", sort @arg_stop_lvls) ne join("\0", sort @lsb_stop_lvls)) {
        $arg_str = @arg_stop_lvls ? "@arg_stop_lvls" : "none";
        $lsb_str = @lsb_stop_lvls ? "@lsb_stop_lvls" : "none";
        warning "stop runlevel arguments ($arg_str) do not match",
                "$name Default-Stop values ($lsb_str)";
    }
}

sub sysv_toggle {
    my ($act, $name) = (shift, shift);
    my (@toggle_lvls, $start_lvls, $stop_lvls, @symlinks);
    my $lsb_header = lsb_header_for_script($name);

    # Extra arguments to disable|enable action are runlevels. If none
    # given parse LSB info for Default-Start value.
    if ($#_ >= 0) {
        @toggle_lvls = @_;
    } else {
        ($start_lvls, $stop_lvls) = parse_def_start_stop($lsb_header);
        @toggle_lvls = @$start_lvls;
        if ($#toggle_lvls < 0) {
            error("$name Default-Start contains no runlevels, aborting.");
        }
    }

    # Find symlinks in rc.d directories. Refuse to modify links in runlevels
    # not used for normal system start sequence.
    for my $lvl (@toggle_lvls) {
        if ($lvl !~ /^[S2345]$/) {
            warning("$act action will have no effect on runlevel $lvl");
            next;
        }
        push(@symlinks, $_) for glob("$dpkg_root/etc/rc$lvl.d/[SK][0-9][0-9]$name");
    }

    if (!@symlinks) {
        error("no runlevel symlinks to modify, aborting!");
    }

    # Toggle S/K bit of script symlink.
    for my $cur_lnk (@symlinks) {
        my $sk;
        my @new_lnk = split(//, $cur_lnk);

        if ("disable" eq $act) {
            $sk = rindex($cur_lnk, '/S') + 1;
            next if $sk < 1;
            $new_lnk[$sk] = 'K';
        } else {
            $sk = rindex($cur_lnk, '/K') + 1;
            next if $sk < 1;
            $new_lnk[$sk] = 'S';
        }

        rename($cur_lnk, join('', @new_lnk)) or error($!);
    }
}

# Try to determine if initscripts is installed
sub is_initscripts_installed {
    # Check if mountkernfs is available. We cannot make inferences
    # using the running init system because we may be running in a
    # chroot
    return  glob("$dpkg_root/etc/rcS.d/S??mountkernfs.sh");
}
