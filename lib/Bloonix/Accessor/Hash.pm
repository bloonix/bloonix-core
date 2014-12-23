package Bloonix::Accessor::Array;

use strict;
use warnings;

sub new {
    my $class = shift;

    return bless { hash => {} }, $class;
}

sub delete {
    my ($self, $key) = @_;

    return delete $self->{hash}->{$key};
}

sub add {
    my $self = shift;

    while (@_) {
        my $key = shift;
        my $value = shift;
        $self->{hash}->{$key} = $value;
    }
}

sub keys {
    my $self = shift;

    return keys %{$self->{hash}};
}

sub get {
    my ($self, $key) = @_;
    my $hash = $self->{hash};

    return $hash->{$key};
}

sub count {
    my $self = shift;

    return scalar CORE::keys %{$self->{hash}};
}

sub clear {
    my $self = shift;

    %{$self->{hash}} = ();
}

sub renew {
    my $self = shift;

    $self->{hash} = {};
}

1;
