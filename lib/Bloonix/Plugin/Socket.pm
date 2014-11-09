package Bloonix::Plugin::Socket;

use strict;
use warnings;
use IO::Socket::INET;

sub new {
    my ($class, $opts) = (shift, {@_});

    return bless $opts, $class;
}

sub connect {
    my ($class, $opts) = (shift, {@_});

    my $sock = IO::Socket::INET->new(
        PeerAddr => $opts->{host},
        PeerPort => $opts->{port},
        Proto    => "tcp"
    );

    if ($sock) {
        $sock->autoflush(1);
        return $class->new(sock => $sock);
    }

    return undef;
}

sub send {
    my ($self, $opts) = (shift, {@_});

    my $sock = $self->{sock};
    my $rest = length $opts->{data};
    my $data = $opts->{data};
    my $offset = 0;

    while ($rest) {
        my $written = syswrite $sock, $data, $rest, $offset;

        if (!defined $written) {
            die "system write error: $!\n";
        }

        $rest -= $written;
        $offset += $written;
    }
}

sub read {
    my ($self, $opts) = (shift, {@_});

    if ($opts->{lines}) {
        return $self->read_lines($opts->{lines});
    }

    if ($opts->{length}) {
        return $self->read_length($opts->{length});
    }

    return ();
}

sub read_lines {
    my ($self, $lines) = @_;
    my $sock = $self->{sock};
    my @lines;

    foreach my $i (1 .. $self->{lines}) {
        push @lines, scalar <$sock>;
    }

    return @lines;
}

sub read_length {
    my ($self, $length) = @_;

    my $sock = $self->{sock};
    my $rest = $length;
    my $data = "";
    my $buf;

    while ($rest) {
        my $read = sysread $sock, $buf, $rest;

        if (!defined $read) {
            next if $! =~ /^Interrupted/;
            die "system read error: $!\n";
        }

        $rest -= $read;
        $data .= $buf;
    }

    return $data;
}

sub readline {
    my $self = shift;
    my $sock = $self->{sock};
    my $data = "";
    my $buf;

    while (1) {
        my $read = sysread $sock, $buf, 1;

        if (!defined $read) {
            next if $! =~ /^Interrupted/;
            die "system read error: $!\n";
        }

        $data .= $buf;
        last if $buf eq "\r\n" || $buf eq "\n";
    }

    return $data;
}

sub disconnect {
    my $self = shift;

    close($self->{sock});
}

1;
