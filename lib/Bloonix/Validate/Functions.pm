=head1 NAME

Bloonix::Validate::Functions - Validate functions.

=head1 SYNOPSIS

=head1 DESCRIPTION

Just for internal usage!

=head1 METHODS

=head2 new

=cut

package Bloonix::Validate::Functions;

use strict;
use warnings;
use base qw(Bloonix::Accessor);

__PACKAGE__->mk_accessors(qw/
    size min_size max_size min_val max_val lesser greater equal not_equal regex regexcl regexwl
    prepare postprod constraint constraint_any constraint_all options multioptions type
/);

our $VERSION = "0.1";

# $_[0] is the value
# $_[1] is the rule
my %functions = (
    size       => sub { length($_[0]) == $_[1] },
    min_size   => sub { length($_[0]) >= $_[1] }, # min_size of 0 is not valid!
    max_size   => sub { length($_[0]) <= $_[1] },
    min_val    => sub { $_[0] =~ /^-{0,1}\d+\z/ && $_[0] >= $_[1] },
    max_val    => sub { $_[0] =~ /^-{0,1}\d+\z/ && $_[0] <= $_[1] },
    lesser     => sub { $_[0] =~ /^\d+\z/ && $_[0] < $_[1] },
    greater    => sub { $_[0] =~ /^\d+\z/ && $_[0] > $_[1] },
    equal      => sub { $_[0] eq $_[1] },
    not_equal  => sub { $_[0] ne $_[1] },
    regex      => sub { $_[0] =~ $_[1] },
    regexcl    => sub { for my $s (split /\s*,\s*/, $_[0], -1) { return 0 if $s !~ $_[1] } return 1 },
    regexwl    => sub { for my $s (split /\s+/, $_[0]) { return 0 if $s !~ $_[1] } return 1 },
    prepare    => sub { $_[1]($_[0]) },
    postprod   => sub { $_[1]($_[0]) },
    constraint => sub { $_[1]($_[0]) },
    constraint_any => sub { for my $c (@{$_[1]}) { return 1 if &$c($_[0]) }; return 0 },
    constraint_all => sub { for my $c (@{$_[1]}) { return 0 unless &$c($_[0]) }; return 1 },
    options => sub {
        my ($value, $struct) = @_;

        if (ref($struct) eq "HASH") {
            if (exists $struct->{$value}) {
                return 1;
            }
        } elsif (ref($struct->[0]) eq "HASH") {
            foreach my $ref (@$struct) {
                # <option name="foo">value</option>
                # option name must match $value
                if ($ref->{value} eq $value) {
                    return 1;
                }
            }
        } elsif (grep /^\Q$value\E\z/, @$struct) {
            return 1;
        }

        return 0;
    },
    min_items => sub {
        my ($value, $options) = @_;

        if (!defined $options || ref $options ne "ARRAY") {
            return 0;
        }

        my $len = scalar @$options;

        if ($len <= $value) {
            return 0;
        }

        return 1;
    },
    type => sub {
        my $ref = ref($_[0])||"scalar";
        return scalar $ref =~ qr/^$_[1]\z/i;
    },
);

$functions{multioptions} = sub {
    my ($values, $options) = @_;

    foreach my $value (@$values) {
        if (! $functions{options}($value, $options) ) {
            return 0;
        }
    }

    return 1;
};

sub new {
    my $class = shift;

    return bless \%functions, $class;
}
