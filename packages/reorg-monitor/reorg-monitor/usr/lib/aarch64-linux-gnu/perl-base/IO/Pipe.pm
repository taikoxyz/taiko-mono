# IO::Pipe.pm
#
# Copyright (c) 1996-8 Graham Barr <gbarr@pobox.com>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package IO::Pipe;

use 5.008_001;

use IO::Handle;
use strict;
use Carp;
use Symbol;

our $VERSION = "1.49";

sub new {
    my $type = shift;
    my $class = ref($type) || $type || "IO::Pipe";
    @_ == 0 || @_ == 2 or croak "usage: $class->([READFH, WRITEFH])";

    my $me = bless gensym(), $class;

    my($readfh,$writefh) = @_ ? @_ : $me->handles;

    pipe($readfh, $writefh)
	or return undef;

    @{*$me} = ($readfh, $writefh);

    $me;
}

sub handles {
    @_ == 1 or croak 'usage: $pipe->handles()';
    (IO::Pipe::End->new(), IO::Pipe::End->new());
}

my $do_spawn = $^O eq 'os2' || $^O eq 'MSWin32';

sub _doit {
    my $me = shift;
    my $rw = shift;

    my $pid = $do_spawn ? 0 : fork();

    if($pid) { # Parent
        return $pid;
    }
    elsif(defined $pid) { # Child or spawn
        my $fh;
        my $io = $rw ? \*STDIN : \*STDOUT;
        my ($mode, $save) = $rw ? "r" : "w";
        if ($do_spawn) {
          require Fcntl;
          $save = IO::Handle->new_from_fd($io, $mode);
	  my $handle = shift;
          # Close in child:
	  unless ($^O eq 'MSWin32') {
            fcntl($handle, Fcntl::F_SETFD(), 1) or croak "fcntl: $!";
	  }
          $fh = $rw ? ${*$me}[0] : ${*$me}[1];
        } else {
          shift;
          $fh = $rw ? $me->reader() : $me->writer(); # close the other end
        }
        bless $io, "IO::Handle";
        $io->fdopen($fh, $mode);
	$fh->close;

        if ($do_spawn) {
          $pid = eval { system 1, @_ }; # 1 == P_NOWAIT
          my $err = $!;
    
          $io->fdopen($save, $mode);
          $save->close or croak "Cannot close $!";
          croak "IO::Pipe: Cannot spawn-NOWAIT: $err" if not $pid or $pid < 0;
          return $pid;
        } else {
          exec @_ or
            croak "IO::Pipe: Cannot exec: $!";
        }
    }
    else {
        croak "IO::Pipe: Cannot fork: $!";
    }

    # NOT Reached
}

sub reader {
    @_ >= 1 or croak 'usage: $pipe->reader( [SUB_COMMAND_ARGS] )';
    my $me = shift;

    return undef
	unless(ref($me) || ref($me = $me->new));

    my $fh  = ${*$me}[0];
    my $pid;
    $pid = $me->_doit(0, $fh, @_)
        if(@_);

    close ${*$me}[1];
    bless $me, ref($fh);
    *$me = *$fh;          # Alias self to handle
    $me->fdopen($fh->fileno,"r")
	unless defined($me->fileno);
    bless $fh;                  # Really wan't un-bless here
    ${*$me}{'io_pipe_pid'} = $pid
        if defined $pid;

    $me;
}

sub writer {
    @_ >= 1 or croak 'usage: $pipe->writer( [SUB_COMMAND_ARGS] )';
    my $me = shift;

    return undef
	unless(ref($me) || ref($me = $me->new));

    my $fh  = ${*$me}[1];
    my $pid;
    $pid = $me->_doit(1, $fh, @_)
        if(@_);

    close ${*$me}[0];
    bless $me, ref($fh);
    *$me = *$fh;          # Alias self to handle
    $me->fdopen($fh->fileno,"w")
	unless defined($me->fileno);
    bless $fh;                  # Really wan't un-bless here
    ${*$me}{'io_pipe_pid'} = $pid
        if defined $pid;

    $me;
}

package IO::Pipe::End;

our(@ISA);

@ISA = qw(IO::Handle);

sub close {
    my $fh = shift;
    my $r = $fh->SUPER::close(@_);

    waitpid(${*$fh}{'io_pipe_pid'},0)
	if(defined ${*$fh}{'io_pipe_pid'});

    $r;
}

1;

__END__

