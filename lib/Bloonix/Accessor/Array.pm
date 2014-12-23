package Bloonix::Accessor::Array;

use strict;
use warnings;

sub new {
    my $class = CORE::shift;

    return bless { array => [] }, $class;
}

sub shift {
    my $self = CORE::shift;

    return CORE::shift @{$self->{array}};
}

sub push {
    my $self = CORE::shift;

    if (@_) {
        CORE::push @{$self->{array}}, @_;
    }
}

sub pop {
    my $self = CORE::shift;

    return CORE::pop @{$self->{array}};
}

sub unshift {
    my $self = CORE::shift;

    if (@_) {
        CORE::unshift @{$self->{array}}, @_;
    }
}

sub iterate {
    my $self = CORE::shift;

    return 0 .. $self->count - 1;
}

sub loop {
    my $self = CORE::shift;

    return @{$self->{array}};
}

sub get {
    my $self = CORE::shift;

    return wantarray ? @{$self->{array}} : $self->{array};
}

sub first {
    my $self = CORE::shift;

    return $self->{array}->[0];
}

sub last {
    my $self = CORE::shift;

    return $self->{array}->[-1];
}

sub count {
    my $self = CORE::shift;

    return scalar @{$self->{array}};
}

sub clear {
    my $self = CORE::shift;

    @{$self->{array}} = ();
}

sub renew {
    my $self = CORE::shift;

    if (@_) {
        if (@_ == 1 && ref $_[0] eq "ARRAY") {
            $self->{array} = CORE::shift;
        } else {
            $self->{array} = [@_];
        }
    } else {
        $self->{array} = [];
    }
}

1;
