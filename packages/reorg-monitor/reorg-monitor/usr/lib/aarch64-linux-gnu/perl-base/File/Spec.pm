package File::Spec;

use strict;

our $VERSION = '3.84';
$VERSION =~ tr/_//d;

my %module = (
	      MSWin32 => 'Win32',
	      os2     => 'OS2',
	      VMS     => 'VMS',
	      NetWare => 'Win32', # Yes, File::Spec::Win32 works on NetWare.
	      symbian => 'Win32', # Yes, File::Spec::Win32 works on symbian.
	      dos     => 'OS2',   # Yes, File::Spec::OS2 works on DJGPP.
	      cygwin  => 'Cygwin',
	      amigaos => 'AmigaOS');

my $module = $module{$^O} || 'Unix';

require "File/Spec/$module.pm";
our @ISA = ("File::Spec::$module");

1;

__END__

