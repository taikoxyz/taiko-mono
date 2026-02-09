package IPC::Open3;

use strict;
no strict 'refs'; # because users pass me bareword filehandles

use Exporter 'import';

use Carp;
use Symbol qw(gensym qualify);

our $VERSION	= '1.22';
our @EXPORT		= qw(open3);

# &open3: Marc Horowitz <marc@mit.edu>
# derived mostly from &open2 by tom christiansen, <tchrist@convex.com>
# fixed for 5.001 by Ulrich Kunitz <kunitz@mai-koeln.com>
# ported to Win32 by Ron Schmidt, Merrill Lynch almost ended my career
# fixed for autovivving FHs, tchrist again
# allow fd numbers to be used, by Frank Tobin
# allow '-' as command (c.f. open "-|"), by Adam Spiers <perl@adamspiers.org>
#
# usage: $pid = open3('wtr', 'rdr', 'err' 'some cmd and args', 'optarg', ...);
#
# spawn the given $cmd and connect rdr for
# reading, wtr for writing, and err for errors.
# if err is '', or the same as rdr, then stdout and
# stderr of the child are on the same fh.  returns pid
# of child (or dies on failure).

# if wtr begins with '<&', then wtr will be closed in the parent, and
# the child will read from it directly.  if rdr or err begins with
# '>&', then the child will send output directly to that fd.  In both
# cases, there will be a dup() instead of a pipe() made.

# WARNING: this is dangerous, as you may block forever
# unless you are very careful.
#
# $wtr is left unbuffered.
#
# abort program if
#   rdr or wtr are null
#   a system call fails

our $Me = 'open3 (bug)';	# you should never see this, it's always localized

# Fatal.pm needs to be fixed WRT prototypes.

sub xpipe {
    pipe $_[0], $_[1] or croak "$Me: pipe($_[0], $_[1]) failed: $!";
}

# I tried using a * prototype character for the filehandle but it still
# disallows a bareword while compiling under strict subs.

sub xopen {
    open $_[0], $_[1], @_[2..$#_] and return;
    local $" = ', ';
    carp "$Me: open(@_) failed: $!";
}

sub xclose {
    $_[0] =~ /\A=?(\d+)\z/
	? do { my $fh; open($fh, $_[1] . '&=' . $1) and close($fh); }
	: close $_[0]
	or croak "$Me: close($_[0]) failed: $!";
}

sub xfileno {
    return $1 if $_[0] =~ /\A=?(\d+)\z/;  # deal with fh just being an fd
    return fileno $_[0];
}

use constant FORCE_DEBUG_SPAWN => 0;
use constant DO_SPAWN => $^O eq 'os2' || $^O eq 'MSWin32' || FORCE_DEBUG_SPAWN;

sub _open3 {
    local $Me = shift;

    # simulate autovivification of filehandles because
    # it's too ugly to use @_ throughout to make perl do it for us
    # tchrist 5-Mar-00

    # Historically, open3(undef...) has silently worked, so keep
    # it working.
    splice @_, 0, 1, undef if \$_[0] == \undef;
    splice @_, 1, 1, undef if \$_[1] == \undef;
    unless (eval  {
	$_[0] = gensym unless defined $_[0] && length $_[0];
	$_[1] = gensym unless defined $_[1] && length $_[1];
	1; })
    {
	# must strip crud for croak to add back, or looks ugly
	$@ =~ s/(?<=value attempted) at .*//s;
	croak "$Me: $@";
    }

    my @handles = ({ mode => '<', handle => \*STDIN },
		   { mode => '>', handle => \*STDOUT },
		   { mode => '>', handle => \*STDERR },
		  );

    foreach (@handles) {
	$_->{parent} = shift;
	$_->{open_as} = gensym;
    }

    if (@_ > 1 and $_[0] eq '-') {
	croak "Arguments don't make sense when the command is '-'"
    }

    $handles[2]{parent} ||= $handles[1]{parent};
    $handles[2]{dup_of_out} = $handles[1]{parent} eq $handles[2]{parent};

    my $package;
    foreach (@handles) {
	$_->{dup} = ($_->{parent} =~ s/^[<>]&//);

	if ($_->{parent} !~ /\A=?(\d+)\z/) {
	    # force unqualified filehandles into caller's package
	    $package //= caller 1;
	    $_->{parent} = qualify $_->{parent}, $package;
	}

	next if $_->{dup} or $_->{dup_of_out};
	if ($_->{mode} eq '<') {
	    xpipe $_->{open_as}, $_->{parent};
	} else {
	    xpipe $_->{parent}, $_->{open_as};
	}
    }

    my $kidpid;
    if (!DO_SPAWN) {
	# Used to communicate exec failures.
	xpipe my $stat_r, my $stat_w;

	$kidpid = fork;
	croak "$Me: fork failed: $!" unless defined $kidpid;
	if ($kidpid == 0) {  # Kid
	    eval {
		# A tie in the parent should not be allowed to cause problems.
		untie *STDIN;
		untie *STDOUT;
		untie *STDERR;

		close $stat_r;
		require Fcntl;
		my $flags = fcntl $stat_w, &Fcntl::F_GETFD, 0;
		croak "$Me: fcntl failed: $!" unless $flags;
		fcntl $stat_w, &Fcntl::F_SETFD, $flags|&Fcntl::FD_CLOEXEC
		    or croak "$Me: fcntl failed: $!";

		# If she wants to dup the kid's stderr onto her stdout I need to
		# save a copy of her stdout before I put something else there.
		if (!$handles[2]{dup_of_out} && $handles[2]{dup}
			&& xfileno($handles[2]{parent}) == fileno \*STDOUT) {
		    my $tmp = gensym;
		    xopen($tmp, '>&', $handles[2]{parent});
		    $handles[2]{parent} = $tmp;
		}

		foreach (@handles) {
		    if ($_->{dup_of_out}) {
			xopen \*STDERR, ">&STDOUT"
			    if defined fileno STDERR && fileno STDERR != fileno STDOUT;
		    } elsif ($_->{dup}) {
			xopen $_->{handle}, $_->{mode} . '&', $_->{parent}
			    if fileno $_->{handle} != xfileno($_->{parent});
		    } else {
			xclose $_->{parent}, $_->{mode};
			xopen $_->{handle}, $_->{mode} . '&=',
			    fileno $_->{open_as};
		    }
		}
		return 1 if ($_[0] eq '-');
		exec @_ or do {
		    local($")=(" ");
		    croak "$Me: exec of @_ failed: $!";
		};
	    } and do {
                close $stat_w;
                return 0;
            };

	    my $bang = 0+$!;
	    my $err = $@;
	    utf8::encode $err if $] >= 5.008;
	    print $stat_w pack('IIa*', $bang, length($err), $err);
	    close $stat_w;

	    eval { require POSIX; POSIX::_exit(255); };
	    exit 255;
	}
	else {  # Parent
	    close $stat_w;
	    my $to_read = length(pack('I', 0)) * 2;
	    my $bytes_read = read($stat_r, my $buf = '', $to_read);
	    if ($bytes_read) {
		(my $bang, $to_read) = unpack('II', $buf);
		read($stat_r, my $err = '', $to_read);
		waitpid $kidpid, 0; # Reap child which should have exited
		if ($err) {
		    utf8::decode $err if $] >= 5.008;
		} else {
		    $err = "$Me: " . ($! = $bang);
		}
		$! = $bang;
		die($err);
	    }
	}
    }
    else {  # DO_SPAWN
	# All the bookkeeping of coincidence between handles is
	# handled in spawn_with_handles.

	my @close;

	foreach (@handles) {
	    if ($_->{dup_of_out}) {
		$_->{open_as} = $handles[1]{open_as};
	    } elsif ($_->{dup}) {
		$_->{open_as} = $_->{parent} =~ /\A[0-9]+\z/
		    ? $_->{parent} : \*{$_->{parent}};
		push @close, $_->{open_as};
	    } else {
		push @close, \*{$_->{parent}}, $_->{open_as};
	    }
	}
	require IO::Pipe;
	$kidpid = eval {
	    spawn_with_handles(\@handles, \@close, @_);
	};
	die "$Me: $@" if $@;
    }

    foreach (@handles) {
	next if $_->{dup} or $_->{dup_of_out};
	xclose $_->{open_as}, $_->{mode};
    }

    # If the write handle is a dup give it away entirely, close my copy
    # of it.
    xclose $handles[0]{parent}, $handles[0]{mode} if $handles[0]{dup};

    select((select($handles[0]{parent}), $| = 1)[0]); # unbuffer pipe
    $kidpid;
}

sub open3 {
    if (@_ < 4) {
	local $" = ', ';
	croak "open3(@_): not enough arguments";
    }
    return _open3 'open3', @_
}

sub spawn_with_handles {
    my $fds = shift;		# Fields: handle, mode, open_as
    my $close_in_child = shift;
    my ($fd, %saved, @errs);

    foreach $fd (@$fds) {
	$fd->{tmp_copy} = IO::Handle->new_from_fd($fd->{handle}, $fd->{mode});
	$saved{fileno $fd->{handle}} = $fd->{tmp_copy} if $fd->{tmp_copy};
    }
    foreach $fd (@$fds) {
	bless $fd->{handle}, 'IO::Handle'
	    unless eval { $fd->{handle}->isa('IO::Handle') } ;
	# If some of handles to redirect-to coincide with handles to
	# redirect, we need to use saved variants:
    my $open_as = $fd->{open_as};
    my $fileno = fileno($open_as);
    $fd->{handle}->fdopen(defined($fileno)
                  ? $saved{$fileno} || $open_as
                  : $open_as,
                  $fd->{mode});
    }
    unless ($^O eq 'MSWin32') {
	require Fcntl;
	# Stderr may be redirected below, so we save the err text:
	foreach $fd (@$close_in_child) {
	    next unless fileno $fd;
	    fcntl($fd, Fcntl::F_SETFD(), 1) or push @errs, "fcntl $fd: $!"
		unless $saved{fileno $fd}; # Do not close what we redirect!
	}
    }

    my $pid;
    unless (@errs) {
	if (FORCE_DEBUG_SPAWN) {
	    pipe my $r, my $w or die "Pipe failed: $!";
	    $pid = fork;
	    die "Fork failed: $!" unless defined $pid;
	    if (!$pid) {
		{ no warnings; exec @_ }
		print $w 0 + $!;
		close $w;
		require POSIX;
		POSIX::_exit(255);
	    }
	    close $w;
	    my $bad = <$r>;
	    if (defined $bad) {
		$! = $bad;
		undef $pid;
	    }
	} else {
	    $pid = eval { system 1, @_ }; # 1 == P_NOWAIT
	}
	if($@) {
	    push @errs, "IO::Pipe: Can't spawn-NOWAIT: $@";
	} elsif(!$pid || $pid < 0) {
	    push @errs, "IO::Pipe: Can't spawn-NOWAIT: $!";
	}
    }

    # Do this in reverse, so that STDERR is restored first:
    foreach $fd (reverse @$fds) {
	$fd->{handle}->fdopen($fd->{tmp_copy}, $fd->{mode});
    }
    foreach (values %saved) {
	$_->close or croak "Can't close: $!";
    }
    croak join "\n", @errs if @errs;
    return $pid;
}

1; # so require is happy
