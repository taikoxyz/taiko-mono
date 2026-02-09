# Subroutines shared by the "adduser" and "deluser" utilities.
#
# Copyright (C) 2000 Roland Bauerschmidt <rb@debian.org>
#
# Most subroutines here are adopted from Debian's original "adduser"
# program.
#
# Copyright (C) 1997-1999 Guy Maor <maor@debian.org>
#
# Copyright (C) 1995 Ted Hajek <tedhajek@boombox.micro.umn.edu>
#                    Ian A. Murdock <imurdock@gnu.ai.mit.edu>


use File::Basename;
use Fcntl qw(:flock SEEK_END);

use constant PROGNAME => basename($0);

use vars qw(@EXPORT $VAR1);

my $lockfile;

@EXPORT = (
    'debugf',
    'dief',
    'get_group_members',
    'gtx',
    'read_config',
    'read_pool',
    's_print',
    's_printf',
    'systemcall',
    'systemcall_or_warn',
    'systemcall_silent',
    'warnf',
    'acquire_lock',
    'release_lock'
);

sub gtx {
    return gettext( shift );
}

sub dief {
    my ($form, @argu) = @_;
    printf STDERR sprintf(gtx('%s: %s'), PROGNAME, $form), @argu;
    exit 1;
}

sub warnf {
    my ($form, @argu) = @_;
    printf STDERR sprintf(gtx('%s: %s'), PROGNAME, $form), @argu;
}

sub debugf {
    my ($form, @argu) = @_;
    if ( $verbose == 2 ) {
        printf STDERR sprintf('DEBUG: %s: %s', PROGNAME, $form), @argu;
    }
}

# parse the configuration file
# parameters:
#  -- filename of the configuration file
#  -- a hash for the configuration data
sub read_config {
    my ($conf_file, $configref) = @_;
    my ($var, $lcvar, $val);

    if (! -f $conf_file) {
        warnf gtx("`%s' does not exist. Using defaults.\n"),$conf_file if $verbose;
        return;
    }

    open (CONF, $conf_file) || dief ("%s: `%s'\n",$conf_file,$!);
    while (<CONF>) {
        chomp;
        next if /^#/ || /^\s*$/;

        if ((($var, $val) = m/^\s*([_a-zA-Z0-9]+)\s*=\s*(.*)/) != 2) {
            warnf gtx("Couldn't parse `%s', line %d.\n"),$conf_file,$.;
            next;
        }
        $lcvar = lc $var;
        if (!exists($configref->{$lcvar})) {
            warnf gtx("Unknown variable `%s' at `%s', line %d.\n"),$var,$conf_file,$.;
            next;
        }

        $val =~ s/^"(.*)"$/$1/;
        $val =~ s/^'(.*)'$/$1/;

        $configref->{$lcvar} = $val;
    }

    close CONF || die "$!";
}

# read names and IDs from a pool file
# parameters:
#  -- filename of the pool file, or directory containing files
#  -- a hash for the pool data
sub read_pool {
    my ($pool_file, $type, $poolref) = @_;
    my ($name, $id);
    my %ids = ();
    my %new;

    if (-d $pool_file) {
        opendir (DIR, $pool_file) or
            dief gtx("Cannot read directory `%s'"),$pool_file;
        my @files = readdir (DIR);
        closedir (DIR);
        foreach (sort @files) {
            next if (/^\./);
            next if (!/\.conf$/);
            my $file = "$pool_file/$_";
            next if (! -f $file);
            read_pool ($file, $type, $poolref);
        }
        return;
    }
    if (! -f $pool_file) {
        warnf gtx("`%s' does not exist.\n"),$pool_file if $verbose;
        return;
    }
    open (POOL, $pool_file) || dief ("%s: `%s'\n",$pool_file,$!);
    while (<POOL>) {
        chomp;
        next if /^#/ || /^\s*$/;

        if ($type eq "uid") {
            ($name, $id, $comment, $home, $shell) = split (/:/);
            if (!$name || $name !~ /^([_a-zA-Z0-9-]+)$/ ||
                !$id || $id !~ /^(\d+)$/) {
                warnf gtx("Couldn't parse `%s', line %d.\n"),$pool_file,$.;
                next;
            }
            $new = {
                'id' => $id,
                'comment' => $comment,
                'home' => $home,
                'shell' => $shell
            };
        } elsif ($type eq "gid") {
            ($name, $id) = split (/:/);
            if (!$name || $name !~ /^([_a-zA-Z0-9-]+)$/ ||
                !$id || $id !~ /^(\d+)$/) {
                warnf gtx("Couldn't parse `%s', line %d.\n"),$pool_file,$.;
                next;
            }
            $new = {
                'id' => $id,
            };
        } else {
            dief gtx("Illegal pool type `%s' reading `%s'.\n"),$type,$pool_file;
        }
        if (defined($poolref->{$name})) {
            dief gtx("Duplicate name `%s' at `%s', line %d.\n"),$name,$pool_file,$.;
        }
        if (defined($ids{$id})) {
            dief gtx("Duplicate ID `%s' at `%s', line %d.\n"),$id,$pool_file,$.;
        }

        $poolref->{$name} = $new;
    }

    close POOL || die "$!";
}

sub get_group_members
{
    my $group = shift;

    my @members;

    foreach my $member (split(/ /, (getgrnam($group))[3])) {
        push(@members, $member) if defined(getpwnam($member));
    }

    return @members;
}

sub s_print
{
    if($verbose) {
        print join(" ",@_);
    }
}

sub s_printf
{
    if($verbose) {
        printf @_;
    }
}

sub d_printf
{
    if((defined($verbose) && $verbose > 1) || (defined($debugging) && $debugging == 1)) {
        printf @_;
    }
}

sub systemcall {
    my $c = join(' ', @_);
    if( $verbose==2 ) {
        print ("$c\n");
    }
    if (system(@_)) {
        if ($?>>8) {
            dief (gtx("`%s' returned error code %d. Exiting.\n"), $c, $?>>8)
        }
        dief (gtx("`%s' exited from signal %d. Exiting.\n"), $c, $?&127);
    }
}

sub systemcall_or_warn {
    my $command = join(' ', @_);
    if( $verbose==2 ) {
        print ("$c\n");
    }

    system(@_);

    if ($? == -1) {
        warnf(gtx("`%s' failed to execute. %s. Continuing.\n"), $command, "$!");
    } elsif ($? & 127) {
        warnf(gtx("`%s' killed by signal %d. Continuing.\n"), $command, ($? & 127));
    } elsif ($? >> 8) {
        warnf(gtx("`%s' failed with status %d. Continuing.\n"), $command, ($? >> 8));
    }

    return $?;
}

sub systemcall_silent {
    my $pid = fork();

    if( !defined($pid) ) {
        return -1;
    }

    if ($pid) {
        wait;
        return $?;
    }

    open(STDOUT, '>>', '/dev/null');
    open(STDERR, '>>', '/dev/null');

    # TODO: report exec() failure to parent
    exec(@_) or exit(1);
}

sub systemcall_silent_error {
    my $command = join(' ', @_);
    my $output = `$command >/dev/null 2>&1`;
    return $?;
}

sub which {
    my ($progname, $nonfatal) = @_ ;
    for my $dir (split /:/, $ENV{"PATH"}) {
        if (-x "$dir/$progname" ) {
            return "$dir/$progname";
        }
    }
    dief(gtx("Could not find program named `%s' in \$PATH.\n"), $progname) unless ($nonfatal);
    return 0;
}


# preseed the configuration variables
# then read the config file /etc/adduser and overwrite the data hardcoded here
# we cannot give defaults for users_gid and users_group here since this will
# probably lead to double defined users_gid and users_group.
sub preseed_config {
    my ($conflistref, $configref) = @_;
    my %config_defaults = (
        system => 0,
        only_if_empty => 0,
        remove_home => 0,
        home => "",
        remove_all_files => 0,
        backup => 0,
        backup_to => ".",
        dshell => "/bin/bash",
        first_system_uid => 100,
        last_system_uid => 999,
        first_uid => 1000,
        last_uid => 59999,
        first_system_gid => 100,
        last_system_gid => 999,
        first_gid => 1000,
        last_gid => 59999,
        dhome => "/home",
        skel => "/etc/skel",
        usergroups => "yes",
        users_gid => undef,
        users_group => undef,
        grouphomes => "no",
        letterhomes => "no",
        quotauser => "",
        dir_mode => "0700",
        sys_dir_mode => "0755",
        setgid_home => "no",
        no_del_paths => "^/bin\$ ^/boot\$ ^/dev\$ ^/etc\$ ^/initrd ^/lib ^/lost+found\$ ^/media\$ ^/mnt\$ ^/opt\$ ^/proc\$ ^/root\$ ^/run\$ ^/sbin\$ ^/srv\$ ^/sys\$ ^/tmp\$ ^/usr\$ ^/var\$ ^/vmlinu",
        name_regex => "^[a-z][a-z0-9_-]*\\\$?\$",
        sys_name_regex => "^[a-z_][a-z0-9_-]*\\\$?\$",
        exclude_fstypes => "(proc|sysfs|usbfs|devpts|devtmpfs|devfs|afs)",
        skel_ignore_regex => "\.(dpkg|ucf)-(old|new|dist)\$",
        extra_groups => "users",
        add_extra_groups => 0,
        uid_pool => "",
        gid_pool => "",
    );

    # Initialize to the set of known variables.
    foreach (keys %config_defaults) {
        $configref->{$_} = $config_defaults{$_};
    }

    # Read the configuration files
    foreach( @$conflistref ) {
        debugf("read configuration file %s\n", $_);
        read_config($_,$configref);
    }
}

sub acquire_lock {
    my $lockfile_path = '/run/adduser';
    my @notify_secs = (1, 3, 8, 18, 28);
    my ($wait_secs, $timeout_secs) = (0, 30);

    open($lockfile, '>>', $lockfile_path)
        or dief "could not open lock file %s!\n", $lockfile_path;

    while (!flock($lockfile, LOCK_EX | LOCK_NB)) {
        if ($wait_secs == $timeout_secs) {
            dief gtx("Could not obtain exclusive lock, please try again shortly!");
        } elsif (grep @notify_secs, $wait_secs) {
            warnf gtx("Waiting for lock to become available...\n");
        }
        sleep 1;
        $wait_secs++;
    }

    seek($lockfile, 0, SEEK_END) or dief "could not seek - %s!\n", $lockfile_path;
}

sub release_lock {
    my $nonfatal = shift || 0;
    return if ($nonfatal && !$lockfile);
    dief "could not find lock file!" unless $lockfile;
    flock($lockfile, LOCK_UN) or $nonfatal or die "could not unlock file $lockfile_path: $! !\n";
    close($lockfile) or $nonfatal or die "could not close lock file $lockfile_path: $! !\n";
}

END {
    release_lock(1);
}

# Local Variables:
# mode:cperl
# End:

# vim: tabstop=4 shiftwidth=4 expandtab
