package File::Path;

use 5.005_04;
use strict;

use Cwd 'getcwd';
use File::Basename ();
use File::Spec     ();

BEGIN {
    if ( $] < 5.006 ) {

        # can't say 'opendir my $dh, $dirname'
        # need to initialise $dh
        eval 'use Symbol';
    }
}

use Exporter ();
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
$VERSION   = '2.18';
$VERSION   = eval $VERSION;
@ISA       = qw(Exporter);
@EXPORT    = qw(mkpath rmtree);
@EXPORT_OK = qw(make_path remove_tree);

BEGIN {
  for (qw(VMS MacOS MSWin32 os2)) {
    no strict 'refs';
    *{"_IS_\U$_"} = $^O eq $_ ? sub () { 1 } : sub () { 0 };
  }

  # These OSes complain if you want to remove a file that you have no
  # write permission to:
  *_FORCE_WRITABLE = (
    grep { $^O eq $_ } qw(amigaos dos epoc MSWin32 MacOS os2)
  ) ? sub () { 1 } : sub () { 0 };

  # Unix-like systems need to stat each directory in order to detect
  # race condition. MS-Windows is immune to this particular attack.
  *_NEED_STAT_CHECK = !(_IS_MSWIN32()) ? sub () { 1 } : sub () { 0 };
}

sub _carp {
    require Carp;
    goto &Carp::carp;
}

sub _croak {
    require Carp;
    goto &Carp::croak;
}

sub _error {
    my $arg     = shift;
    my $message = shift;
    my $object  = shift;

    if ( $arg->{error} ) {
        $object = '' unless defined $object;
        $message .= ": $!" if $!;
        push @{ ${ $arg->{error} } }, { $object => $message };
    }
    else {
        _carp( defined($object) ? "$message for $object: $!" : "$message: $!" );
    }
}

sub __is_arg {
    my ($arg) = @_;

    # If client code blessed an array ref to HASH, this will not work
    # properly. We could have done $arg->isa() wrapped in eval, but
    # that would be expensive. This implementation should suffice.
    # We could have also used Scalar::Util:blessed, but we choose not
    # to add this dependency
    return ( ref $arg eq 'HASH' );
}

sub make_path {
    push @_, {} unless @_ and __is_arg( $_[-1] );
    goto &mkpath;
}

sub mkpath {
    my $old_style = !( @_ and __is_arg( $_[-1] ) );

    my $data;
    my $paths;

    if ($old_style) {
        my ( $verbose, $mode );
        ( $paths, $verbose, $mode ) = @_;
        $paths = [$paths] unless UNIVERSAL::isa( $paths, 'ARRAY' );
        $data->{verbose} = $verbose;
        $data->{mode} = defined $mode ? $mode : oct '777';
    }
    else {
        my %args_permitted = map { $_ => 1 } ( qw|
            chmod
            error
            group
            mask
            mode
            owner
            uid
            user
            verbose
        | );
        my %not_on_win32_args = map { $_ => 1 } ( qw|
            group
            owner
            uid
            user
        | );
        my @bad_args = ();
        my @win32_implausible_args = ();
        my $arg = pop @_;
        for my $k (sort keys %{$arg}) {
            if (! $args_permitted{$k}) {
                push @bad_args, $k;
            }
            elsif ($not_on_win32_args{$k} and _IS_MSWIN32) {
                push @win32_implausible_args, $k;
            }
            else {
                $data->{$k} = $arg->{$k};
            }
        }
        _carp("Unrecognized option(s) passed to mkpath() or make_path(): @bad_args")
            if @bad_args;
        _carp("Option(s) implausible on Win32 passed to mkpath() or make_path(): @win32_implausible_args")
            if @win32_implausible_args;
        $data->{mode} = delete $data->{mask} if exists $data->{mask};
        $data->{mode} = oct '777' unless exists $data->{mode};
        ${ $data->{error} } = [] if exists $data->{error};
        unless (@win32_implausible_args) {
            $data->{owner} = delete $data->{user} if exists $data->{user};
            $data->{owner} = delete $data->{uid}  if exists $data->{uid};
            if ( exists $data->{owner} and $data->{owner} =~ /\D/ ) {
                my $uid = ( getpwnam $data->{owner} )[2];
                if ( defined $uid ) {
                    $data->{owner} = $uid;
                }
                else {
                    _error( $data,
                            "unable to map $data->{owner} to a uid, ownership not changed"
                          );
                    delete $data->{owner};
                }
            }
            if ( exists $data->{group} and $data->{group} =~ /\D/ ) {
                my $gid = ( getgrnam $data->{group} )[2];
                if ( defined $gid ) {
                    $data->{group} = $gid;
                }
                else {
                    _error( $data,
                            "unable to map $data->{group} to a gid, group ownership not changed"
                    );
                    delete $data->{group};
                }
            }
            if ( exists $data->{owner} and not exists $data->{group} ) {
                $data->{group} = -1;    # chown will leave group unchanged
            }
            if ( exists $data->{group} and not exists $data->{owner} ) {
                $data->{owner} = -1;    # chown will leave owner unchanged
            }
        }
        $paths = [@_];
    }
    return _mkpath( $data, $paths );
}

sub _mkpath {
    my $data   = shift;
    my $paths = shift;

    my ( @created );
    foreach my $path ( @{$paths} ) {
        next unless defined($path) and length($path);
        $path .= '/' if _IS_OS2 and $path =~ /^\w:\z/s; # feature of CRT

        # Logic wants Unix paths, so go with the flow.
        if (_IS_VMS) {
            next if $path eq '/';
            $path = VMS::Filespec::unixify($path);
        }
        next if -d $path;
        my $parent = File::Basename::dirname($path);
        # Coverage note:  It's not clear how we would test the condition:
        # '-d $parent or $path eq $parent'
        unless ( -d $parent or $path eq $parent ) {
            push( @created, _mkpath( $data, [$parent] ) );
        }
        print "mkdir $path\n" if $data->{verbose};
        if ( mkdir( $path, $data->{mode} ) ) {
            push( @created, $path );
            if ( exists $data->{owner} ) {

                # NB: $data->{group} guaranteed to be set during initialisation
                if ( !chown $data->{owner}, $data->{group}, $path ) {
                    _error( $data,
                        "Cannot change ownership of $path to $data->{owner}:$data->{group}"
                    );
                }
            }
            if ( exists $data->{chmod} ) {
                # Coverage note:  It's not clear how we would trigger the next
                # 'if' block.  Failure of 'chmod' might first result in a
                # system error: "Permission denied".
                if ( !chmod $data->{chmod}, $path ) {
                    _error( $data,
                        "Cannot change permissions of $path to $data->{chmod}" );
                }
            }
        }
        else {
            my $save_bang = $!;

            # From 'perldoc perlvar': $EXTENDED_OS_ERROR ($^E) is documented
            # as:
            # Error information specific to the current operating system. At the
            # moment, this differs from "$!" under only VMS, OS/2, and Win32
            # (and for MacPerl). On all other platforms, $^E is always just the
            # same as $!.

            my ( $e, $e1 ) = ( $save_bang, $^E );
            $e .= "; $e1" if $e ne $e1;

            # allow for another process to have created it meanwhile
            if ( ! -d $path ) {
                $! = $save_bang;
                if ( $data->{error} ) {
                    push @{ ${ $data->{error} } }, { $path => $e };
                }
                else {
                    _croak("mkdir $path: $e");
                }
            }
        }
    }
    return @created;
}

sub remove_tree {
    push @_, {} unless @_ and __is_arg( $_[-1] );
    goto &rmtree;
}

sub _is_subdir {
    my ( $dir, $test ) = @_;

    my ( $dv, $dd ) = File::Spec->splitpath( $dir,  1 );
    my ( $tv, $td ) = File::Spec->splitpath( $test, 1 );

    # not on same volume
    return 0 if $dv ne $tv;

    my @d = File::Spec->splitdir($dd);
    my @t = File::Spec->splitdir($td);

    # @t can't be a subdir if it's shorter than @d
    return 0 if @t < @d;

    return join( '/', @d ) eq join( '/', splice @t, 0, +@d );
}

sub rmtree {
    my $old_style = !( @_ and __is_arg( $_[-1] ) );

    my ($arg, $data, $paths);

    if ($old_style) {
        my ( $verbose, $safe );
        ( $paths, $verbose, $safe ) = @_;
        $data->{verbose} = $verbose;
        $data->{safe} = defined $safe ? $safe : 0;

        if ( defined($paths) and length($paths) ) {
            $paths = [$paths] unless UNIVERSAL::isa( $paths, 'ARRAY' );
        }
        else {
            _carp("No root path(s) specified\n");
            return 0;
        }
    }
    else {
        my %args_permitted = map { $_ => 1 } ( qw|
            error
            keep_root
            result
            safe
            verbose
        | );
        my @bad_args = ();
        my $arg = pop @_;
        for my $k (sort keys %{$arg}) {
            if (! $args_permitted{$k}) {
                push @bad_args, $k;
            }
            else {
                $data->{$k} = $arg->{$k};
            }
        }
        _carp("Unrecognized option(s) passed to remove_tree(): @bad_args")
            if @bad_args;
        ${ $data->{error} }  = [] if exists $data->{error};
        ${ $data->{result} } = [] if exists $data->{result};

        # Wouldn't it make sense to do some validation on @_ before assigning
        # to $paths here?
        # In the $old_style case we guarantee that each path is both defined
        # and non-empty.  We don't check that here, which means we have to
        # check it later in the first condition in this line:
        #     if ( $ortho_root_length && _is_subdir( $ortho_root, $ortho_cwd ) ) {
        # Granted, that would be a change in behavior for the two
        # non-old-style interfaces.

        $paths = [@_];
    }

    $data->{prefix} = '';
    $data->{depth}  = 0;

    my @clean_path;
    $data->{cwd} = getcwd() or do {
        _error( $data, "cannot fetch initial working directory" );
        return 0;
    };
    for ( $data->{cwd} ) { /\A(.*)\Z/s; $_ = $1 }    # untaint

    for my $p (@$paths) {

        # need to fixup case and map \ to / on Windows
        my $ortho_root = _IS_MSWIN32 ? _slash_lc($p) : $p;
        my $ortho_cwd =
          _IS_MSWIN32 ? _slash_lc( $data->{cwd} ) : $data->{cwd};
        my $ortho_root_length = length($ortho_root);
        $ortho_root_length-- if _IS_VMS;   # don't compare '.' with ']'
        if ( $ortho_root_length && _is_subdir( $ortho_root, $ortho_cwd ) ) {
            local $! = 0;
            _error( $data, "cannot remove path when cwd is $data->{cwd}", $p );
            next;
        }

        if (_IS_MACOS) {
            $p = ":$p" unless $p =~ /:/;
            $p .= ":" unless $p =~ /:\z/;
        }
        elsif ( _IS_MSWIN32 ) {
            $p =~ s{[/\\]\z}{};
        }
        else {
            $p =~ s{/\z}{};
        }
        push @clean_path, $p;
    }

    @{$data}{qw(device inode)} = ( lstat $data->{cwd} )[ 0, 1 ] or do {
        _error( $data, "cannot stat initial working directory", $data->{cwd} );
        return 0;
    };

    return _rmtree( $data, \@clean_path );
}

sub _rmtree {
    my $data   = shift;
    my $paths = shift;

    my $count  = 0;
    my $curdir = File::Spec->curdir();
    my $updir  = File::Spec->updir();

    my ( @files, $root );
  ROOT_DIR:
    foreach my $root (@$paths) {

        # since we chdir into each directory, it may not be obvious
        # to figure out where we are if we generate a message about
        # a file name. We therefore construct a semi-canonical
        # filename, anchored from the directory being unlinked (as
        # opposed to being truly canonical, anchored from the root (/).

        my $canon =
          $data->{prefix}
          ? File::Spec->catfile( $data->{prefix}, $root )
          : $root;

        my ( $ldev, $lino, $perm ) = ( lstat $root )[ 0, 1, 2 ]
          or next ROOT_DIR;

        if ( -d _ ) {
            $root = VMS::Filespec::vmspath( VMS::Filespec::pathify($root) )
              if _IS_VMS;

            if ( !chdir($root) ) {

                # see if we can escalate privileges to get in
                # (e.g. funny protection mask such as -w- instead of rwx)
                # This uses fchmod to avoid traversing outside of the proper
                # location (CVE-2017-6512)
                my $root_fh;
                if (open($root_fh, '<', $root)) {
                    my ($fh_dev, $fh_inode) = (stat $root_fh )[0,1];
                    $perm &= oct '7777';
                    my $nperm = $perm | oct '700';
                    local $@;
                    if (
                        !(
                            $data->{safe}
                           or $nperm == $perm
                           or !-d _
                           or $fh_dev ne $ldev
                           or $fh_inode ne $lino
                           or eval { chmod( $nperm, $root_fh ) }
                        )
                      )
                    {
                        _error( $data,
                            "cannot make child directory read-write-exec", $canon );
                        next ROOT_DIR;
                    }
                    close $root_fh;
                }
                if ( !chdir($root) ) {
                    _error( $data, "cannot chdir to child", $canon );
                    next ROOT_DIR;
                }
            }

            my ( $cur_dev, $cur_inode, $perm ) = ( stat $curdir )[ 0, 1, 2 ]
              or do {
                _error( $data, "cannot stat current working directory", $canon );
                next ROOT_DIR;
              };

            if (_NEED_STAT_CHECK) {
                ( $ldev eq $cur_dev and $lino eq $cur_inode )
                  or _croak(
"directory $canon changed before chdir, expected dev=$ldev ino=$lino, actual dev=$cur_dev ino=$cur_inode, aborting."
                  );
            }

            $perm &= oct '7777';    # don't forget setuid, setgid, sticky bits
            my $nperm = $perm | oct '700';

            # notabene: 0700 is for making readable in the first place,
            # it's also intended to change it to writable in case we have
            # to recurse in which case we are better than rm -rf for
            # subtrees with strange permissions

            if (
                !(
                       $data->{safe}
                    or $nperm == $perm
                    or chmod( $nperm, $curdir )
                )
              )
            {
                _error( $data, "cannot make directory read+writeable", $canon );
                $nperm = $perm;
            }

            my $d;
            $d = gensym() if $] < 5.006;
            if ( !opendir $d, $curdir ) {
                _error( $data, "cannot opendir", $canon );
                @files = ();
            }
            else {
                if ( !defined ${^TAINT} or ${^TAINT} ) {
                    # Blindly untaint dir names if taint mode is active
                    @files = map { /\A(.*)\z/s; $1 } readdir $d;
                }
                else {
                    @files = readdir $d;
                }
                closedir $d;
            }

            if (_IS_VMS) {

                # Deleting large numbers of files from VMS Files-11
                # filesystems is faster if done in reverse ASCIIbetical order.
                # include '.' to '.;' from blead patch #31775
                @files = map { $_ eq '.' ? '.;' : $_ } reverse @files;
            }

            @files = grep { $_ ne $updir and $_ ne $curdir } @files;

            if (@files) {

                # remove the contained files before the directory itself
                my $narg = {%$data};
                @{$narg}{qw(device inode cwd prefix depth)} =
                  ( $cur_dev, $cur_inode, $updir, $canon, $data->{depth} + 1 );
                $count += _rmtree( $narg, \@files );
            }

            # restore directory permissions of required now (in case the rmdir
            # below fails), while we are still in the directory and may do so
            # without a race via '.'
            if ( $nperm != $perm and not chmod( $perm, $curdir ) ) {
                _error( $data, "cannot reset chmod", $canon );
            }

            # don't leave the client code in an unexpected directory
            chdir( $data->{cwd} )
              or
              _croak("cannot chdir to $data->{cwd} from $canon: $!, aborting.");

            # ensure that a chdir upwards didn't take us somewhere other
            # than we expected (see CVE-2002-0435)
            ( $cur_dev, $cur_inode ) = ( stat $curdir )[ 0, 1 ]
              or _croak(
                "cannot stat prior working directory $data->{cwd}: $!, aborting."
              );

            if (_NEED_STAT_CHECK) {
                ( $data->{device} eq $cur_dev and $data->{inode} eq $cur_inode )
                  or _croak(  "previous directory $data->{cwd} "
                            . "changed before entering $canon, "
                            . "expected dev=$ldev ino=$lino, "
                            . "actual dev=$cur_dev ino=$cur_inode, aborting."
                  );
            }

            if ( $data->{depth} or !$data->{keep_root} ) {
                if ( $data->{safe}
                    && ( _IS_VMS
                        ? !&VMS::Filespec::candelete($root)
                        : !-w $root ) )
                {
                    print "skipped $root\n" if $data->{verbose};
                    next ROOT_DIR;
                }
                if ( _FORCE_WRITABLE and !chmod $perm | oct '700', $root ) {
                    _error( $data, "cannot make directory writeable", $canon );
                }
                print "rmdir $root\n" if $data->{verbose};
                if ( rmdir $root ) {
                    push @{ ${ $data->{result} } }, $root if $data->{result};
                    ++$count;
                }
                else {
                    _error( $data, "cannot remove directory", $canon );
                    if (
                        _FORCE_WRITABLE
                        && !chmod( $perm,
                            ( _IS_VMS ? VMS::Filespec::fileify($root) : $root )
                        )
                      )
                    {
                        _error(
                            $data,
                            sprintf( "cannot restore permissions to 0%o",
                                $perm ),
                            $canon
                        );
                    }
                }
            }
        }
        else {
            # not a directory
            $root = VMS::Filespec::vmsify("./$root")
              if _IS_VMS
              && !File::Spec->file_name_is_absolute($root)
              && ( $root !~ m/(?<!\^)[\]>]+/ );    # not already in VMS syntax

            if (
                $data->{safe}
                && (
                    _IS_VMS
                    ? !&VMS::Filespec::candelete($root)
                    : !( -l $root || -w $root )
                )
              )
            {
                print "skipped $root\n" if $data->{verbose};
                next ROOT_DIR;
            }

            my $nperm = $perm & oct '7777' | oct '600';
            if (    _FORCE_WRITABLE
                and $nperm != $perm
                and not chmod $nperm, $root )
            {
                _error( $data, "cannot make file writeable", $canon );
            }
            print "unlink $canon\n" if $data->{verbose};

            # delete all versions under VMS
            for ( ; ; ) {
                if ( unlink $root ) {
                    push @{ ${ $data->{result} } }, $root if $data->{result};
                }
                else {
                    _error( $data, "cannot unlink file", $canon );
                    _FORCE_WRITABLE and chmod( $perm, $root )
                      or _error( $data,
                        sprintf( "cannot restore permissions to 0%o", $perm ),
                        $canon );
                    last;
                }
                ++$count;
                last unless _IS_VMS && lstat $root;
            }
        }
    }
    return $count;
}

sub _slash_lc {

    # fix up slashes and case on MSWin32 so that we can determine that
    # c:\path\to\dir is underneath C:/Path/To
    my $path = shift;
    $path =~ tr{\\}{/};
    return lc($path);
}

1;

__END__

