package File::Basename;

# File::Basename is used during the Perl build, when the re extension may
# not be available, but we only actually need it if running under tainting.
BEGIN {
  if (${^TAINT}) {
    require re;
    re->import('taint');
  }
}

use strict;
use 5.006;
use warnings;
our(@ISA, @EXPORT, $VERSION, $Fileparse_fstype, $Fileparse_igncase);
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(fileparse fileparse_set_fstype basename dirname);
$VERSION = "2.85";

fileparse_set_fstype($^O);

sub fileparse {
  my($fullname,@suffices) = @_;

  unless (defined $fullname) {
      require Carp;
      Carp::croak("fileparse(): need a valid pathname");
  }

  my $orig_type = '';
  my($type,$igncase) = ($Fileparse_fstype, $Fileparse_igncase);

  my($taint) = substr($fullname,0,0);  # Is $fullname tainted?

  if ($type eq "VMS" and $fullname =~ m{/} ) {
    # We're doing Unix emulation
    $orig_type = $type;
    $type = 'Unix';
  }

  my($dirpath, $basename);

  if (grep { $type eq $_ } qw(MSDOS DOS MSWin32 Epoc)) {
    ($dirpath,$basename) = ($fullname =~ /^((?:.*[:\\\/])?)(.*)/s);
    $dirpath .= '.\\' unless $dirpath =~ /[\\\/]\z/;
  }
  elsif ($type eq "OS2") {
    ($dirpath,$basename) = ($fullname =~ m#^((?:.*[:\\/])?)(.*)#s);
    $dirpath = './' unless $dirpath;	# Can't be 0
    $dirpath .= '/' unless $dirpath =~ m#[\\/]\z#;
  }
  elsif ($type eq "MacOS") {
    ($dirpath,$basename) = ($fullname =~ /^(.*:)?(.*)/s);
    $dirpath = ':' unless $dirpath;
  }
  elsif ($type eq "AmigaOS") {
    ($dirpath,$basename) = ($fullname =~ /(.*[:\/])?(.*)/s);
    $dirpath = './' unless $dirpath;
  }
  elsif ($type eq 'VMS' ) {
    ($dirpath,$basename) = ($fullname =~ /^(.*[:>\]])?(.*)/s);
    $dirpath ||= '';  # should always be defined
  }
  else { # Default to Unix semantics.
    ($dirpath,$basename) = ($fullname =~ m{^(.*/)?(.*)}s);
    if ($orig_type eq 'VMS' and $fullname =~ m{^(/[^/]+/000000(/|$))(.*)}) {
      # dev:[000000] is top of VMS tree, similar to Unix '/'
      # so strip it off and treat the rest as "normal"
      my $devspec  = $1;
      my $remainder = $3;
      ($dirpath,$basename) = ($remainder =~ m{^(.*/)?(.*)}s);
      $dirpath ||= '';  # should always be defined
      $dirpath = $devspec.$dirpath;
    }
    $dirpath = './' unless $dirpath;
  }
      

  my $tail   = '';
  my $suffix = '';
  if (@suffices) {
    foreach $suffix (@suffices) {
      my $pat = ($igncase ? '(?i)' : '') . "($suffix)\$";
      if ($basename =~ s/$pat//s) {
        $taint .= substr($suffix,0,0);
        $tail = $1 . $tail;
      }
    }
  }

  # Ensure taint is propagated from the path to its pieces.
  $tail .= $taint;
  wantarray ? ($basename .= $taint, $dirpath .= $taint, $tail)
            : ($basename .= $taint);
}

sub basename {
  my($path) = shift;

  # From BSD basename(1)
  # The basename utility deletes any prefix ending with the last slash '/'
  # character present in string (after first stripping trailing slashes)
  _strip_trailing_sep($path);

  my($basename, $dirname, $suffix) = fileparse( $path, map("\Q$_\E",@_) );

  # From BSD basename(1)
  # The suffix is not stripped if it is identical to the remaining 
  # characters in string.
  if( length $suffix and !length $basename ) {
      $basename = $suffix;
  }
  
  # Ensure that basename '/' == '/'
  if( !length $basename ) {
      $basename = $dirname;
  }

  return $basename;
}

sub dirname {
    my $path = shift;

    my($type) = $Fileparse_fstype;

    if( $type eq 'VMS' and $path =~ m{/} ) {
        # Parse as Unix
        local($File::Basename::Fileparse_fstype) = '';
        return dirname($path);
    }

    my($basename, $dirname) = fileparse($path);

    if ($type eq 'VMS') { 
        $dirname ||= $ENV{DEFAULT};
    }
    elsif ($type eq 'MacOS') {
	if( !length($basename) && $dirname !~ /^[^:]+:\z/) {
            _strip_trailing_sep($dirname);
	    ($basename,$dirname) = fileparse $dirname;
	}
	$dirname .= ":" unless $dirname =~ /:\z/;
    }
    elsif (grep { $type eq $_ } qw(MSDOS DOS MSWin32 OS2)) { 
        _strip_trailing_sep($dirname);
        unless( length($basename) ) {
	    ($basename,$dirname) = fileparse $dirname;
	    _strip_trailing_sep($dirname);
	}
    }
    elsif ($type eq 'AmigaOS') {
        if ( $dirname =~ /:\z/) { return $dirname }
        chop $dirname;
        $dirname =~ s{[^:/]+\z}{} unless length($basename);
    }
    else {
        _strip_trailing_sep($dirname);
        unless( length($basename) ) {
	    ($basename,$dirname) = fileparse $dirname;
	    _strip_trailing_sep($dirname);
	}
    }

    $dirname;
}

# Strip the trailing path separator.
sub _strip_trailing_sep  {
    my $type = $Fileparse_fstype;

    if ($type eq 'MacOS') {
        $_[0] =~ s/([^:]):\z/$1/s;
    }
    elsif (grep { $type eq $_ } qw(MSDOS DOS MSWin32 OS2)) { 
        $_[0] =~ s/([^:])[\\\/]*\z/$1/;
    }
    else {
        $_[0] =~ s{(.)/*\z}{$1}s;
    }
}

BEGIN {

my @Ignore_Case = qw(MacOS VMS AmigaOS OS2 RISCOS MSWin32 MSDOS DOS Epoc);
my @Types = (@Ignore_Case, qw(Unix));

sub fileparse_set_fstype {
    my $old = $Fileparse_fstype;

    if (@_) {
        my $new_type = shift;

        $Fileparse_fstype = 'Unix';  # default
        foreach my $type (@Types) {
            $Fileparse_fstype = $type if $new_type =~ /^$type/i;
        }

        $Fileparse_igncase = 
          (grep $Fileparse_fstype eq $_, @Ignore_Case) ? 1 : 0;
    }

    return $old;
}

}

1;

