use strict; use warnings;

package Text::Tabs;

BEGIN { require Exporter; *import = \&Exporter::import }

our @EXPORT = qw( expand unexpand $tabstop );

our $VERSION = '2021.0814';
our $SUBVERSION = 'modern'; # back-compat vestige

our $tabstop = 8;

sub expand {
	my @l;
	my $pad;
	for ( @_ ) {
		defined or do { push @l, ''; next };
		my $s = '';
		for (split(/^/m, $_, -1)) {
			my $offs;
			for (split(/\t/, $_, -1)) {
				if (defined $offs) {
					$pad = $tabstop - $offs % $tabstop;
					$s .= " " x $pad;
				}
				$s .= $_;
				$offs = () = /\PM/g;
			}
		}
		push(@l, $s);
	}
	return @l if wantarray;
	return $l[0];
}

sub unexpand
{
	my (@l) = @_;
	my @e;
	my $x;
	my $line;
	my @lines;
	my $lastbit;
	my $ts_as_space = " " x $tabstop;
	for $x (@l) {
		defined $x or next;
		@lines = split("\n", $x, -1);
		for $line (@lines) {
			$line = expand($line);
			@e = split(/((?:\PM\pM*){$tabstop})/,$line,-1);
			$lastbit = pop(@e);
			$lastbit = '' 
				unless defined $lastbit;
			$lastbit = "\t"
				if $lastbit eq $ts_as_space;
			for $_ (@e) {
				s/  +$/\t/;
			}
			$line = join('',@e, $lastbit);
		}
		$x = join("\n", @lines);
	}
	return @l if wantarray;
	return $l[0];
}

1;

__END__

