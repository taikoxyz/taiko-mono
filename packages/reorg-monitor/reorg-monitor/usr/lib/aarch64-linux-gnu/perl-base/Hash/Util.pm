package Hash::Util;

require 5.007003;
use strict;
use Carp;
use warnings;
no warnings 'uninitialized';
use warnings::register;
no warnings 'experimental::builtin';
use builtin qw(reftype);

require Exporter;
our @EXPORT_OK  = qw(
                     fieldhash fieldhashes

                     all_keys
                     lock_keys unlock_keys
                     lock_value unlock_value
                     lock_hash unlock_hash
                     lock_keys_plus
                     hash_locked hash_unlocked
                     hashref_locked hashref_unlocked
                     hidden_keys legal_keys

                     lock_ref_keys unlock_ref_keys
                     lock_ref_value unlock_ref_value
                     lock_hashref unlock_hashref
                     lock_ref_keys_plus
                     hidden_ref_keys legal_ref_keys

                     hash_seed hash_value hv_store
                     bucket_stats bucket_stats_formatted bucket_info bucket_array
                     lock_hash_recurse unlock_hash_recurse
                     lock_hashref_recurse unlock_hashref_recurse

                     hash_traversal_mask

                     bucket_ratio
                     used_buckets
                     num_buckets
                    );
BEGIN {
    # make sure all our XS routines are available early so their prototypes
    # are correctly applied in the following code.
    our $VERSION = '0.28';
    require XSLoader;
    XSLoader::load();
}

sub import {
    my $class = shift;
    if ( grep /fieldhash/, @_ ) {
        require Hash::Util::FieldHash;
        Hash::Util::FieldHash->import(':all'); # for re-export
    }
    unshift @_, $class;
    goto &Exporter::import;
}

sub lock_ref_keys {
    my($hash, @keys) = @_;

    _clear_placeholders(%$hash);
    if( @keys ) {
        my %keys = map { ($_ => 1) } @keys;
        my %original_keys = map { ($_ => 1) } keys %$hash;
        foreach my $k (keys %original_keys) {
            croak "Hash has key '$k' which is not in the new key set"
              unless $keys{$k};
        }

        foreach my $k (@keys) {
            $hash->{$k} = undef unless exists $hash->{$k};
        }
        Internals::SvREADONLY %$hash, 1;

        foreach my $k (@keys) {
            delete $hash->{$k} unless $original_keys{$k};
        }
    }
    else {
        Internals::SvREADONLY %$hash, 1;
    }

    return $hash;
}

sub unlock_ref_keys {
    my $hash = shift;

    Internals::SvREADONLY %$hash, 0;
    return $hash;
}

sub   lock_keys (\%;@) {   lock_ref_keys(@_) }
sub unlock_keys (\%)   { unlock_ref_keys(@_) }

#=item B<_clear_placeholders>
#
# This function removes any placeholder keys from a hash. See Perl_hv_clear_placeholders()
# in hv.c for what it does exactly. It is currently exposed as XS by universal.c and
# injected into the Hash::Util namespace.
#
# It is not intended for use outside of this module, and may be changed
# or removed without notice or deprecation cycle.
#
#=cut
#
# sub _clear_placeholders {} # just in case someone searches...

sub lock_ref_keys_plus {
    my ($hash,@keys) = @_;
    my @delete;
    _clear_placeholders(%$hash);
    foreach my $key (@keys) {
        unless (exists($hash->{$key})) {
            $hash->{$key}=undef;
            push @delete,$key;
        }
    }
    Internals::SvREADONLY(%$hash,1);
    delete @{$hash}{@delete};
    return $hash
}

sub lock_keys_plus(\%;@) { lock_ref_keys_plus(@_) }

sub lock_ref_value {
    my($hash, $key) = @_;
    # I'm doubtful about this warning, as it seems not to be true.
    # Marking a value in the hash as RO is useful, regardless
    # of the status of the hash itself.
    carp "Cannot usefully lock values in an unlocked hash"
      if !Internals::SvREADONLY(%$hash) && warnings::enabled;
    Internals::SvREADONLY $hash->{$key}, 1;
    return $hash
}

sub unlock_ref_value {
    my($hash, $key) = @_;
    Internals::SvREADONLY $hash->{$key}, 0;
    return $hash
}

sub   lock_value (\%$) {   lock_ref_value(@_) }
sub unlock_value (\%$) { unlock_ref_value(@_) }

sub lock_hashref {
    my $hash = shift;

    lock_ref_keys($hash);

    foreach my $value (values %$hash) {
        Internals::SvREADONLY($value,1);
    }

    return $hash;
}

sub unlock_hashref {
    my $hash = shift;

    foreach my $value (values %$hash) {
        Internals::SvREADONLY($value, 0);
    }

    unlock_ref_keys($hash);

    return $hash;
}

sub   lock_hash (\%) {   lock_hashref(@_) }
sub unlock_hash (\%) { unlock_hashref(@_) }

sub lock_hashref_recurse {
    my $hash = shift;

    lock_ref_keys($hash);
    foreach my $value (values %$hash) {
        my $type = reftype($value);
        if (defined($type) and $type eq 'HASH') {
            lock_hashref_recurse($value);
        }
        Internals::SvREADONLY($value,1);
    }
    return $hash
}

sub unlock_hashref_recurse {
    my $hash = shift;

    foreach my $value (values %$hash) {
        my $type = reftype($value);
        if (defined($type) and $type eq 'HASH') {
            unlock_hashref_recurse($value);
        }
        Internals::SvREADONLY($value,0);
    }
    unlock_ref_keys($hash);
    return $hash;
}

sub   lock_hash_recurse (\%) {   lock_hashref_recurse(@_) }
sub unlock_hash_recurse (\%) { unlock_hashref_recurse(@_) }

sub hashref_locked {
    my $hash=shift;
    Internals::SvREADONLY(%$hash);
}

sub hash_locked(\%) { hashref_locked(@_) }

sub hashref_unlocked {
    my $hash=shift;
    !Internals::SvREADONLY(%$hash);
}

sub hash_unlocked(\%) { hashref_unlocked(@_) }

sub legal_keys(\%) { legal_ref_keys(@_)  }
sub hidden_keys(\%){ hidden_ref_keys(@_) }

sub bucket_stats {
    my ($hash) = @_;
    my ($keys, $buckets, $used, @length_counts) = bucket_info($hash);
    my $sum;
    my $score;
    for (1 .. $#length_counts) {
        $sum += ($length_counts[$_] * $_);
        $score += $length_counts[$_] * ( $_ * ($_ + 1 ) / 2 );
    }
    $score = $score /
             (( $keys / (2 * $buckets )) * ( $keys + ( 2 * $buckets ) - 1 ))
                 if $keys;
    my ($mean, $stddev)= (0, 0);
    if ($used) {
        $mean= $sum / $used;
        $sum= 0;
        $sum += ($length_counts[$_] * (($_-$mean)**2)) for 1 .. $#length_counts;

        $stddev= sqrt($sum/$used);
    }
    return $keys, $buckets, $used, $keys ? ($score, $used/$buckets, ($keys-$used)/$keys, $mean, $stddev, @length_counts) : ();
}

sub _bucket_stats_formatted_bars {
    my ($total, $ary, $start_idx, $title, $row_title)= @_;

    my $return = "";
    my $max_width= $total > 64 ? 64 : $total;
    my $bar_width= $max_width / $total;

    my $str= "";
    if ( @$ary < 10) {
        for my $idx ($start_idx .. $#$ary) {
            $str .= $idx x sprintf("%.0f", ($ary->[$idx] * $bar_width));
        }
    } else {
        $str= "-" x $max_width;
    }
    $return .= sprintf "%-7s         %6d [%s]\n",$title, $total, $str;

    foreach my $idx ($start_idx .. $#$ary) {
        $return .= sprintf "%-.3s %3d %6.2f%% %6d [%s]\n",
            $row_title,
            $idx,
            $ary->[$idx] / $total * 100,
            $ary->[$idx],
            "#" x sprintf("%.0f", ($ary->[$idx] * $bar_width)),
        ;
    }
    return $return;
}

sub bucket_stats_formatted {
    my ($hashref)= @_;
    my ($keys, $buckets, $used, $score, $utilization_ratio, $collision_pct,
        $mean, $stddev, @length_counts) = bucket_stats($hashref);

    my $return= sprintf   "Keys: %d Buckets: %d/%d Quality-Score: %.2f (%s)\n"
                        . "Utilized Buckets: %.2f%% Optimal: %.2f%% Keys In Collision: %.2f%%\n"
                        . "Chain Length - mean: %.2f stddev: %.2f\n",
                $keys, $used, $buckets, $score, $score <= 1.05 ? "Good" : $score < 1.2 ? "Poor" : "Bad",
                $utilization_ratio * 100,
                $keys/$buckets * 100,
                $collision_pct * 100,
                $mean, $stddev;

    my @key_depth;
    $key_depth[$_]= $length_counts[$_] + ( $key_depth[$_+1] || 0 )
        for reverse 1 .. $#length_counts;

    if ($keys) {
        $return .= _bucket_stats_formatted_bars($buckets, \@length_counts, 0, "Buckets", "Len");
        $return .= _bucket_stats_formatted_bars($keys, \@key_depth, 1, "Keys", "Pos");
    }
    return $return
}

1;
