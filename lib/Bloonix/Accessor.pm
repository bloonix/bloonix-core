=head1 NAME

Bloonix::Accessor - Create accessors.

=head1 SYNOPSIS

    use base qw(Bloonix::Accessor);

    __PACKAGE__->mk_accessor(qw/this that/);

    my $self = bless { }, __PACKAGE__;

    $self->this("hello");
    $self->that("world");

    print join(" ", $self->this, $self->that);

=head1 DESCRIPTION

Create simple accessors.

=head1 FUNCTIONS

=head2 mk_accessors

=head2 mk_counters

=head2 make_accessor

=head1 AUTHOR

Jonny Schulz <support(at)bloonix.de>.

=head1 COPYRIGHT

Copyright (C) 2009-2014 by Jonny Schulz. All rights reserved.

=cut

package Bloonix::Accessor;

use strict;
use warnings;
use Bloonix::Accessor::Array;

sub mk_accessors {
    my ($class, @accessors) = @_;

    foreach my $accessor (@accessors) {
        $class->make_accessor(
            $accessor => sub {
                $_[0]->{$accessor} = $_[1] if @_ == 2;
                return $_[0]->{$accessor};
            }
        );
    }
}

sub mk_counters {
    my ($class, @accessors) = @_;

    foreach my $accessor (@accessors) {
        $class->make_accessor(
            $accessor => sub {
                $_[0]->{$accessor} += $_[1] if @_ == 2;
                return $_[0]->{$accessor} || 0;
            }
        );
    }
}

sub mk_arrays {
    my ($class, @accessors) = @_;

    foreach my $accessor (@accessors) {
        my $array = Bloonix::Accessor::Array->new();

        $class->make_accessor(
            $accessor => sub {
                return $array;
            }
        );
    }
}

sub mk_hashs {
    my ($class, @accessors) = @_;

    foreach my $accessor (@accessors) {
        my $hash = Bloonix::Accessor::Hash->new();

        $class->make_accessor(
            $accessor => sub {
                return $hash;
            }
        );
    }
}

sub make_accessor {
    my ($class, $accessor, $code) = @_;
    no strict 'refs';

    if ($accessor =~ /::/) {
        *{"$accessor"} = $code;
    } else {
        *{"${class}::$accessor"} = $code;
    }
}

1;
