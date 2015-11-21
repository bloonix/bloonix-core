=head1 NAME

Bloonix::Validate::ResultSet - Set of results after validation.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 new

=head2 data

=head2 copy

=head2 valid

=head2 invalid

=head2 missed

=head2 failed

=head2 remove

=head2 has_valid

=head2 has_invalid

=head2 has_missed

=head2 has_failed

=head2 is_valid

=head2 alias

=head2 aliases

=cut

package Bloonix::Validate::ResultSet;

use strict;
use warnings;

our $VERSION = "0.1";

sub new {
    my ($class, %opts) = @_;

    $opts{valid}   = { };
    $opts{invalid} = { };
    $opts{missed}  = { };
    $opts{failed}  = { };
    $opts{alias}   = { };

    $opts{has_invalid} = 0;
    $opts{has_missed}  = 0;
    $opts{has_failed}  = 0;

    return bless \%opts, $class;
}

sub data {
    my ($self, $data) = @_;

    if ($data) {
        $self->{data} = $data;
    }

    return $self->{data};
}

sub copy {
    my $self = shift;
    my %copy = ();

    foreach my $key (keys %{$self->{data}}) {
        $copy{$key} = $self->{data}->{$key};
    }

    return \%copy;
}

sub valid {
    my ($self, $param, $value) = @_;

    if ($param) {
        $self->{has_valid}++;
        $self->{valid}->{$param} = $value;
    }

    return wantarray ? keys %{$self->{valid}} : $self->{valid};
}

sub remove {
    my ($self, $from, $param) = @_;

    delete $self->{$from}->{$param};
}

sub invalid {
    my ($self, $param, $value) = @_;

    if ($param) {
        $self->failed($param, $value);
        $self->{has_invalid}++;
        $self->{invalid}->{$param} = $value;
    }

    return wantarray ? keys %{$self->{invalid}} : $self->{invalid};
}

sub missed {
    my ($self, $param) = @_;

    if ($param) {
        $self->failed($param);
        $self->{has_missed}++;
        $self->{missed}->{$param} = undef;
    }

    return wantarray ? keys %{$self->{missed}} : $self->{missed};
}

sub failed {
    my ($self, $param, $value) = @_;

    if ($param) {
        $self->{has_failed}++;
        $self->{failed}->{$param} = $value;
    }

    return wantarray ? keys %{$self->{failed}} : $self->{failed};
}

sub alias {
    my ($self, @param) = @_;

    if (@param == 1) {
        return $self->{alias}->{$param[0]};
    }

    return [ @{$self->{alias}}{@param} ];
}

sub aliases {
    my ($self, @param) = @_;

    return [ @{$self->{alias}}{@param} ];
}

sub has_valid   { $_[0]->{has_valid}   }
sub has_missed  { $_[0]->{has_missed}  }
sub has_invalid { $_[0]->{has_invalid} }
sub has_failed  { $_[0]->{has_failed}  }
sub is_valid    { !$_[0]->{has_failed} }

1;
