package Bloonix::Accessor::Hash;

use strict;
use warnings;

sub new {
    my $class = shift;

    return bless { ref => {} }, $class;
}

sub set {
    my $self = shift;

    while (@_) {
        my $key = shift;
        my $value = shift;
        $self->{ref}->{$key} = $value;
    }
}

sub get {
    my ($self, $key) = @_;
    my $ref = $self->{ref};

    return $ref->{$key};
}

sub reset {
    my $self = shift;

    if (@_) {
        if (ref $_[0] eq "HASH") {
            $self->{ref} = shift;
        } else {
            $self->{ref} = {};
            $self->set(@_);
        }
    } else {
        $self->{ref} = {};
    }
}

sub delete {
    my ($self, $key) = @_;

    return CORE::delete $self->{ref}->{$key};
}

sub keys {
    my $self = shift;

    return CORE::keys %{$self->{ref}};
}

sub count {
    my $self = shift;

    return scalar CORE::keys %{$self->{ref}};
}

sub clear {
    my $self = shift;

    %{$self->{ref}} = ();
}

1;
