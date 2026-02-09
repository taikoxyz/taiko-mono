#!/usr/bin/perl
# This file was preprocessed, do not edit!


package Debconf::Encoding;

use strict;
use warnings;

our $charmap;
BEGIN {
	no warnings;
	eval q{	use Text::Iconv };
	use warnings;
	if (! $@) {
		$charmap = `locale charmap`;
		chomp $charmap;
	}
	
	no warnings;
	eval q{ use Text::WrapI18N; use Text::CharWidth };
	use warnings;
	if (! $@ && Text::CharWidth::mblen("a") == 1) {
		*wrap = *Text::WrapI18N::wrap;
		*columns = *Text::WrapI18N::columns;
		*width = *Text::CharWidth::mbswidth;
	}
	else {
		require Text::Wrap;
		require Text::Tabs;
		sub _wrap { return Text::Tabs::expand(Text::Wrap::wrap(@_)) }
		*wrap = *_wrap;
		*columns = *Text::Wrap::columns;
		sub _dumbwidth { length shift }
		*width = *_dumbwidth;
	}
}

use base qw(Exporter);
our @EXPORT_OK=qw(wrap $columns width convert $charmap to_Unicode);

my $converter;
my $old_input_charmap;
sub convert {
	my $input_charmap = shift;
	my $string = shift;
	
	return unless defined $charmap;
	
	if (! defined $old_input_charmap || 
	    $input_charmap ne $old_input_charmap) {
		$converter = Text::Iconv->new($input_charmap, $charmap);
		$old_input_charmap = $input_charmap;
	}
	return $converter->convert($string);
}

my $unicode_conv;
sub to_Unicode {
	my $string = shift;
	my $result;

	return $string if utf8::is_utf8($string);
	if (!defined $unicode_conv) {
		$unicode_conv = Text::Iconv->new($charmap, "UTF-8");
	}
	$result = $unicode_conv->convert($string);
	utf8::decode($result);
	return $result;
}


1
