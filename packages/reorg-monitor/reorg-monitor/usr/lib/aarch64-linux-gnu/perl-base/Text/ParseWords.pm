package Text::ParseWords;

use strict;
use warnings;
require 5.006;
our $VERSION = "3.31";

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(shellwords quotewords nested_quotewords parse_line);
our @EXPORT_OK = qw(old_shellwords);
our $PERL_SINGLE_QUOTE;

sub shellwords {
    my (@lines) = @_;
    my @allwords;

    foreach my $line (@lines) {
	$line =~ s/^\s+//;
	my @words = parse_line('\s+', 0, $line);
	pop @words if (@words and !defined $words[-1]);
	return() unless (@words || !length($line));
	push(@allwords, @words);
    }
    return(@allwords);
}

sub quotewords {
    my($delim, $keep, @lines) = @_;
    my($line, @words, @allwords);

    foreach $line (@lines) {
	@words = parse_line($delim, $keep, $line);
	return() unless (@words || !length($line));
	push(@allwords, @words);
    }
    return(@allwords);
}

sub nested_quotewords {
    my($delim, $keep, @lines) = @_;
    my($i, @allwords);

    for ($i = 0; $i < @lines; $i++) {
	@{$allwords[$i]} = parse_line($delim, $keep, $lines[$i]);
	return() unless (@{$allwords[$i]} || !length($lines[$i]));
    }
    return(@allwords);
}

sub parse_line {
    my($delimiter, $keep, $line) = @_;
    my($word, @pieces);

    no warnings 'uninitialized';	# we will be testing undef strings

    while (length($line)) {
        # This pattern is optimised to be stack conservative on older perls.
        # Do not refactor without being careful and testing it on very long strings.
        # See Perl bug #42980 for an example of a stack busting input.
        $line =~ s/^
                    (?: 
                        # double quoted string
                        (")                             # $quote
                        ((?>[^\\"]*(?:\\.[^\\"]*)*))"   # $quoted 
		    |	# --OR--
                        # singe quoted string
                        (')                             # $quote
                        ((?>[^\\']*(?:\\.[^\\']*)*))'   # $quoted
                    |   # --OR--
                        # unquoted string
		        (                               # $unquoted 
                            (?:\\.|[^\\"'])*?           
                        )		
                        # followed by
		        (                               # $delim
                            \Z(?!\n)                    # EOL
                        |   # --OR--
                            (?-x:$delimiter)            # delimiter
                        |   # --OR--                    
                            (?!^)(?=["'])               # a quote
                        )  
		    )//xs or return;		# extended layout                  
        my ($quote, $quoted, $unquoted, $delim) = (($1 ? ($1,$2) : ($3,$4)), $5, $6);

	return() unless( defined($quote) || length($unquoted) || length($delim));

        if ($keep) {
	    $quoted = "$quote$quoted$quote";
	}
        else {
	    $unquoted =~ s/\\(.)/$1/sg;
	    if (defined $quote) {
		$quoted =~ s/\\(.)/$1/sg if ($quote eq '"');
		$quoted =~ s/\\([\\'])/$1/g if ( $PERL_SINGLE_QUOTE && $quote eq "'");
            }
	}
        $word .= substr($line, 0, 0);	# leave results tainted
        $word .= defined $quote ? $quoted : $unquoted;
 
        if (length($delim)) {
            push(@pieces, $word);
            push(@pieces, $delim) if ($keep eq 'delimiters');
            undef $word;
        }
        if (!length($line)) {
            push(@pieces, $word);
	}
    }
    return(@pieces);
}

sub old_shellwords {

    # Usage:
    #	use ParseWords;
    #	@words = old_shellwords($line);
    #	or
    #	@words = old_shellwords(@lines);
    #	or
    #	@words = old_shellwords();	# defaults to $_ (and clobbers it)

    no warnings 'uninitialized';	# we will be testing undef strings
    local *_ = \join('', @_) if @_;
    my (@words, $snippet);

    s/\A\s+//;
    while ($_ ne '') {
	my $field = substr($_, 0, 0);	# leave results tainted
	for (;;) {
	    if (s/\A"(([^"\\]|\\.)*)"//s) {
		($snippet = $1) =~ s#\\(.)#$1#sg;
	    }
	    elsif (/\A"/) {
		require Carp;
		Carp::carp("Unmatched double quote: $_");
		return();
	    }
	    elsif (s/\A'(([^'\\]|\\.)*)'//s) {
		($snippet = $1) =~ s#\\(.)#$1#sg;
	    }
	    elsif (/\A'/) {
		require Carp;
		Carp::carp("Unmatched single quote: $_");
		return();
	    }
	    elsif (s/\A\\(.?)//s) {
		$snippet = $1;
	    }
	    elsif (s/\A([^\s\\'"]+)//) {
		$snippet = $1;
	    }
	    else {
		s/\A\s+//;
		last;
	    }
	    $field .= $snippet;
	}
	push(@words, $field);
    }
    return @words;
}

1;

__END__

