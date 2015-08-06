package Bloonix::Accessor::Array;

use strict;
use warnings;

sub new {
    my $class = CORE::shift;

    return bless { ref => [] }, $class;
}

sub shift {
    my $self = CORE::shift;

    return CORE::shift @{$self->{ref}};
}

sub push {
    my $self = CORE::shift;

    if (@_) {
        CORE::push @{$self->{ref}}, @_;
    }
}

sub pop {
    my $self = CORE::shift;

    return CORE::pop @{$self->{ref}};
}

sub unshift {
    my $self = CORE::shift;

    if (@_) {
        CORE::unshift @{$self->{ref}}, @_;
    }
}

sub iterate {
    my $self = CORE::shift;

    return 0 .. $self->count - 1;
}

sub loop {
    my $self = CORE::shift;

    return @{$self->{ref}};
}

sub get {
    my $self = CORE::shift;

    return wantarray ? @{$self->{ref}} : $self->{ref};
}

sub join {
    my ($self, $str) = @_;

    return CORE::join $str, @{$self->{ref}};
}

sub first {
    my $self = CORE::shift;

    return $self->{ref}->[0];
}

sub last {
    my $self = CORE::shift;

    return $self->{ref}->[-1];
}

sub count {
    my $self = CORE::shift;

    return scalar @{$self->{ref}};
}

sub clear {
    my $self = CORE::shift;

    @{$self->{ref}} = ();
}

sub renew {
    my $self = CORE::shift;

    if (@_) {
        if (@_ == 1 && ref $_[0] eq "ARRAY") {
            $self->{ref} = CORE::shift;
        } else {
            $self->{ref} = [@_];
        }
    } else {
        $self->{ref} = [];
    }
}

1;
