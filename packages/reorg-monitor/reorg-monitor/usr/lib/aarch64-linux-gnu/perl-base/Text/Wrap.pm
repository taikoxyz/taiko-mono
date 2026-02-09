use strict; use warnings;

package Text::Wrap;

use warnings::register;

BEGIN { require Exporter; *import = \&Exporter::import }

our @EXPORT = qw( wrap fill );
our @EXPORT_OK = qw( $columns $break $huge );

our $VERSION = '2021.0814';
our $SUBVERSION = 'modern'; # back-compat vestige

our $columns = 76;  # <= screen width
our $break = '(?=\s)(?:\r\n|\PM\pM*)';
our $huge = 'wrap'; # alternatively: 'die' or 'overflow'
our $unexpand = 1;
our $tabstop = 8;
our $separator = "\n";
our $separator2 = undef;

sub _xlen { () = $_[0] =~ /\PM/g }

use Text::Tabs qw(expand unexpand);

sub wrap
{
	my ($ip, $xp, @t) = map +( defined $_ ? $_ : '' ), @_;

	local($Text::Tabs::tabstop) = $tabstop;
	my $r = "";
	my $tail = pop(@t);
	my $t = expand(join("", (map { /\s+\z/ ? ( $_ ) : ($_, ' ') } @t), $tail));
	my $lead = $ip;
	my $nll = $columns - _xlen(expand($xp)) - 1;
	if ($nll <= 0 && $xp ne '') {
		my $nc = _xlen(expand($xp)) + 2;
		warnings::warnif "Increasing \$Text::Wrap::columns from $columns to $nc to accommodate length of subsequent tab";
		$columns = $nc;
		$nll = 1;
	}
	my $ll = $columns - _xlen(expand($ip)) - 1;
	$ll = 0 if $ll < 0;
	my $nl = "";
	my $remainder = "";

	use re 'taint';

	pos($t) = 0;
	while ($t !~ /\G(?:$break)*\Z/gc) {
		if ($t =~ /\G((?:(?!\n)\PM\pM*){0,$ll})($break|\n+|\z)/xmgc) {
			$r .= $unexpand 
				? unexpand($nl . $lead . $1)
				: $nl . $lead . $1;
			$remainder = $2;
		} elsif ($huge eq 'wrap' && $t =~ /\G((?:(?!\n)\PM\pM*){$ll})/gc) {
			$r .= $unexpand 
				? unexpand($nl . $lead . $1)
				: $nl . $lead . $1;
			$remainder = defined($separator2) ? $separator2 : $separator;
		} elsif ($huge eq 'overflow' && $t =~ /\G((?:(?!\n)\PM\pM*)*?)($break|\n+|\z)/xmgc) {
			$r .= $unexpand 
				? unexpand($nl . $lead . $1)
				: $nl . $lead . $1;
			$remainder = $2;
		} elsif ($huge eq 'die') {
			die "couldn't wrap '$t'";
		} elsif ($columns < 2) {
			warnings::warnif "Increasing \$Text::Wrap::columns from $columns to 2";
			$columns = 2;
			return @_;
		} else {
			die "This shouldn't happen";
		}
			
		$lead = $xp;
		$ll = $nll;
		$nl = defined($separator2)
			? ($remainder eq "\n"
				? "\n"
				: $separator2)
			: $separator;
	}
	$r .= $remainder;

	$r .= $lead . substr($t, pos($t), length($t) - pos($t))
		if pos($t) ne length($t);

	return $r;
}

sub fill 
{
	my ($ip, $xp, @raw) = map +( defined $_ ? $_ : '' ), @_;
	my @para;
	my $pp;

	for $pp (split(/\n\s+/, join("\n",@raw))) {
		$pp =~ s/\s+/ /g;
		my $x = wrap($ip, $xp, $pp);
		push(@para, $x);
	}

	# if paragraph_indent is the same as line_indent, 
	# separate paragraphs with blank lines

	my $ps = ($ip eq $xp) ? "\n\n" : "\n";
	return join ($ps, @para);
}

1;

__END__

