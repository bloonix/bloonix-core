=head1 NAME

Bloonix::IO::SIPC - Serialized socket communication.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 C<new>

=head2 C<connect>

=head2 C<accept>

=head2 C<is_timeout>

=head2 C<disconnect>

=head2 C<send>

=head2 C<recv>

=head2 C<sock>

=head2 C<errstr>

=head1 PREREQUISITES

    JSON
    IO::Socket
    IO::Socket::SSL
    Params::Validate

=head1 EXPORTS

No exports.

=head1 REPORT BUGS

Please report all bugs to <jschulz.cpan(at)bloonix.de>.

=head1 AUTHOR

Jonny Schulz <jschulz.cpan(at)bloonix.de>.

=head1 COPYRIGHT

Copyright (C) 2009 Jonny Schulz. All rights reserved.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

package Bloonix::IO::SIPC;

use strict;
use warnings;
use JSON;
use IO::Socket;
use IO::Socket::SSL;
use Log::Handler;
use Params::Validate qw//;

use base qw(Bloonix::Accessor);
__PACKAGE__->mk_accessors(qw/log recvbuf die_sub alrm_sub sock errstr json/);

our $VERSION = "0.1";

sub new {
    my $class = shift;
    my $opts = $class->validate(@_);
    my $self = bless $opts, $class;
    $self->init;
    return $self;
}

sub init {
    my $self = shift;

    $self->log(Log::Handler->get_logger("bloonix"));
    $self->json(JSON->new->utf8(1));

    if ($self->log->is_debug) {
        if ($self->{sockmod} eq "IO::Socket::SSL") {
            eval "use IO::Socket::SSL qw(debug3)";
        }

        $self->log->debug("create a new $self->{sockmod} object");
    }

    $self->die_sub(sub { alarm(0) });
    $self->alrm_sub(sub { die "connect runs on a timeout" });
}

sub connect {
    my $self = shift;
    my $timeout = shift || 0;
    my $is_timeout = 0;
    my $opts = $self->{sockopts};

    # BALANCE MODE .... NICHT VERGESSEN
    eval {
        local $SIG{__DIE__} = $self->die_sub;
        local $SIG{ALRM} = $self->alrm_sub;
        alarm($timeout);

        if ($self->{peeraddr}) {
            foreach my $peeraddr (@{ $self->{peeraddr} }) {
                $opts->{PeerAddr} = $peeraddr;

                if ($self->{sock} = $self->{sockmod}->new(%$opts)) {
                    last;
                }
            }
        } else {
            $self->{sock} = $self->{sockmod}->new(%$opts);
        }

        if (!$self->{sock}) {
            die "unable to create socket";
        }

        alarm(0);
    };

    if ($@) {
        return $self->_sock_error($@);
    }

    return $self->sock;
}

sub accept {
    my $self = shift;
    my $timeout = shift || 0;

    if (defined $timeout && $timeout !~ /^\d+\z/) {
        die "timeout isn't numeric";
    }

    if ($timeout) {
        $self->log->debug("set timeout to $timeout");
        $self->sock->timeout($timeout);
    }

    $self->log->debug("waiting for connection");
    my $sock = $self->sock->accept;

    if (!$sock) {
        if ($! == &Errno::ETIMEDOUT && $self->log->is_debug) {
            $self->log->warning($@);
        }
        return;
    }

    $self->log->debug("connect established");
    $self->log->debug("create a new Bloonix::IO::Socket object");

    my %new = %{$self};
    $new{sock} = $sock;
    return bless \%new, __PACKAGE__;
}

sub is_timeout {
    my $self = shift;

    return $! == &Errno::ETIMEDOUT;
}

sub disconnect {
    my $self = shift;

    if ($self->sock) {
        $self->log->debug("disconnect");
        close $self->sock
            or die "unable to close socket: $!";
        $self->sock(undef);
    }

    return 1;
}

sub send {
    my ($self, $data) = @_;
    my $ret;

    $self->log->debug("encode data");
    $data = $self->json->encode($data);
    $self->log->debug("pack data");
    $data = pack("N/a*", $data);
    $self->log->debug("send data");

    eval {
        local $SIG{__DIE__} = $self->die_sub;
        local $SIG{ALRM} = $self->alrm_sub;
        alarm($self->{send_timeout});
        $ret = $self->_send($data);
        alarm(0);
    };

    if ($@) {
        return $self->_errstr($@);
    }

    return $ret;
}

sub recv {
    my $self = shift;
    my $length = 0;
    my $data;

    eval {
        local $SIG{__DIE__} = $self->die_sub;
        local $SIG{ALRM} = $self->alrm_sub;
        alarm($self->{recv_timeout});
        ($data, $length) = $self->_recv_data(@_);
        alarm(0);
    };

    if ($@) {
        $self->_errstr($@);
        return (undef, 0);
    }

    return wantarray ? ($data, $length) : $data;
}

sub _recv_data {
    my $self = shift;
    my $maxbyt = $self->{revc_max_bytes};

    $self->log->debug("recv 4 bytes");
    my $length = $self->_recv(4);

    if (!defined $length) {
        die "no 4 bytes received";
    }

    $length = unpack("N", $length);

    if ($maxbyt && $length > $maxbyt) {
        die "the buffer length ($length bytes) exceeds recv_max_bytes";
    }

    $self->log->debug("recv $length bytes");
    my $data = $self->_recv($length);

    if (!defined $data) {
       die "no data received";
    }

    $data = $self->json->decode($data);
    return ($data, $length);
}

sub DESTROY {
    my $self = shift;

    if ($self->sock) {
        close $self->sock;
    }
}

#
# private stuff
#

sub _errstr {
    my $self = shift;
    $self->{errstr} = shift;
    return undef;
}

sub _send {
    my ($self, $data) = @_;
    my $maxbyt = $self->{send_max_bytes};
    my $sock = $self->sock;
    my $length = length $data;
    my $rest = $length;
    my $offset = 0;
    my $written;
    my $is_debug = $self->log->is_debug;

    if ($maxbyt && $length > $maxbyt) {
        $self->log->die("the data length ($length bytes) exceeds send_max_bytes");
    }

    $self->log->debug("send data, length $length");

    while ($rest) {
        $written = syswrite $sock, $data, $rest, $offset;

        if (!defined $written) {
            die "system write error: $!";
        } elsif ($written) {
            $rest   -= $written;
            $offset += $written;
        }

        if ($is_debug) { # that is much faster
            $self->log->debug("send $offset/$length bytes");
        }
    }

    return $length;
}

sub _recv {
    my ($self, $length) = @_;
    my ($packet, $len, $buf);
    my $sock = $self->sock;
    my $rest = $length;
    my $rdsz = $length < $self->recvbuf ? $length : $self->recvbuf;
    my $clen = 0;
    my $is_debug = $self->log->is_debug;

    while ($rest) {
        $len = sysread $sock, $buf, $rdsz;

        if (!defined $len) {
            next if $! =~ /^Interrupted/;
            die "system recv error: $!";
        } elsif ($len) {
            $packet .= $buf; # concat the data pieces
            $rest -= $len;   # this is the rest we have to read
            $clen += $len;   # the current len

            if ($is_debug) {
                $self->log->debug("recv $clen/$length bytes");
            }
        }

        if ($rest < $rdsz) {
            $rdsz = $rest; # otherwise sysread() hangs if we wants to read to much
        }
    }

    if (!defined $packet) {
        $packet = defined;
    }

    return $packet;
}

sub _sock_error {
    my $self = shift;
    $self->{errstr} = shift;

    if ($self->{sockmod} eq "IO::Socket::SSL") {
        my $sslerr = $self->sock ? $self->sock->errstr : IO::Socket::SSL->errstr;

        if ($sslerr) {
            $self->{errstr} .= " - $sslerr";
        }
    } else {
        $self->{errstr} .= " - $@";
    }

    return undef;
}

sub validate {
    my $class = shift;

    my %options = Params::Validate::validate(@_, {
        peeraddr => {
            type => Params::Validate::SCALAR,
            optional => 1,
        },
        peerport => {
            type => Params::Validate::SCALAR,
            optional => 1,
        },
        localaddr => {
            type => Params::Validate::SCALAR,
            optional => 1,
        },
        localport => {
            type => Params::Validate::SCALAR,
            optional => 1,
        },
        listen => {
            type => Params::Validate::SCALAR,
            regex => qr/^[01]\z/,
            optional => 1,
        },
        use_ssl => {
            type => Params::Validate::SCALAR,
            regex => qr/^[01]\z/,
            default => 0,
        },
        ssl_use_cert => {
            type => Params::Validate::SCALAR,
            optional => 1,
        },
        ssl_ca_file => {
            type => Params::Validate::SCALAR,
            optional => 1,
        },
        ssl_cert_file => {
            type => Params::Validate::SCALAR,
            optional => 1,
        },
        ssl_key_file  => {
            type => Params::Validate::SCALAR,
            optional => 1,
        },
        ssl_passwd_cb => {
            type => Params::Validate::SCALAR,
            optional => 1,
        },
        recv_max_bytes => {
            type => Params::Validate::SCALAR,
            regex => qr/^(?:unlimited|\d+(?:b{0,1}|[kmgt]b{0,1}))\z/,
            default => "512k",
        },
        send_max_bytes => {
            type => Params::Validate::SCALAR,
            regex => qr/^(?:unlimited|\d+(?:b{0,1}|[kmgt]b{0,1}))\z/,
            default => 0,
        },
        recv_timeout => {
            type => Params::Validate::SCALAR,
            regex => qr/^\d+\z/,
            default => 15,
        },
        send_timeout => {
            type => Params::Validate::SCALAR,
            regex => qr/^\d+\z/,
            default => 15,
        },
        timeout => {
            type => Params::Validate::SCALAR,
            regex => qr/^\d+\z/,
            optional => 1,
        },
        recvbuf => {
            type => Params::Validate::SCALAR,
            regex => qr/^\d+\z/,
            default => 16384
        }
    });

    if ($options{timeout}) {
        $options{recv_timeout} = $options{timeout};
        $options{send_timeout} = $options{timeout};
    }

    if ($options{peeraddr}) {
        $options{peeraddr} =~ s/\s//g;
        $options{peeraddr} = [ split /,/, $options{peeraddr} ];
    }

    # Mapping socket options
    my %sockopts = (
        localaddr => 'LocalAddr',
        localport => 'LocalPort',
        peerport  => 'PeerPort',
        #peeraddr  => 'PeerAddr',
    );

    while (my ($opt, $modopt) = each %sockopts) {
        if ($options{$opt}) {
            $options{sockopts}{$modopt} = $options{$opt};
        }
    }

    if ($options{listen}) {
        $options{sockopts}{Listen} = SOMAXCONN;
        $options{sockopts}{Reuse}  = 1;
        $options{sockopts}{Proto}  = "tcp";
    }

    if ($options{use_ssl}) {
        $options{sockmod} = "IO::Socket::SSL";

        if ($options{ssl_use_cert}) {
            foreach my $file (qw/ssl_key_file ssl_cert_file/) {
                if (!$options{$file}) {
                    die "Missing param '$file' in configuration";
                }
                if (!-r $options{$file}) {
                    die "File '$options{$file}' is not readable";
                }
            }

            if ($options{ssl_ca_file} && !-r $options{ssl_ca_file}) {
                die "File '$options{ssl_ca_file}' is not readable";
            }

            my %sslopts = (
                ssl_use_cert  => 'SSL_use_cert',
                ssl_ca_file   => 'SSL_ca_file',
                ssl_cert_file => 'SSL_cert_file',
                ssl_key_file  => 'SSL_key_file',
                ssl_passwd_cb => 'SSL_passwd_cb',
            );

            while (my ($opt, $modopt) = each %sslopts) {
                if ($options{$opt}) {
                    $options{sockopts}{$modopt} = $options{$opt};
                }
            }
        }
    } else {
        $options{sockmod} = "IO::Socket::INET";
    }

    eval "use $options{sockmod}";

    if ($@) {
        die "unable to load $options{sockmod}";
    }

    my %bytes = (
        b => 1,
        k => 1024,
        m => 1048576,
        g => 1073741824,
        t => 1099511627776,
    );

    foreach my $opt (qw/recv_max_bytes send_max_bytes/) {
        if ($options{$opt} =~ /^(\d+)([bkmgt]{0,1})\z/) {
            my ($num, $byt) = ($1, $2 || 'b');
            $options{$opt} = $num * $bytes{$byt};
        } else {
            $options{$opt} = 0;
        }
    }

    return \%options;
}

1;
