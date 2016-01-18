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
use IO::Socket::INET;
use IO::Socket::SSL;
use Log::Handler;
use Params::Validate qw//;

use base qw(Bloonix::Accessor);
__PACKAGE__->mk_accessors(qw/log recvbuf die_sub alrm_conn_sub alrm_send_sub alrm_recv_sub sock errstr json/);

our $VERSION = "0.1";

sub new {
    my $class = shift;
    my $opts = $class->validate(@_);
    my $self = bless $opts, $class;
    $self->init;

    if ($self->{auto_connect}) {
        $self->connect;
    }

    return $self;
}

sub init {
    my $self = shift;

    $self->log(Log::Handler->get_logger("bloonix"));
    $self->json(JSON->new->utf8(1));

    if ($self->log->is_debug) {
        if ($self->{sockmod} eq "IO::Socket::SSL") {
            eval "use IO::Socket::SSL 'debug3'";
        }

        $self->log->debug("create a new $self->{sockmod} object");
    }

    $self->die_sub(sub { alarm(0) });
    $self->alrm_conn_sub(sub { die "connect() runs on a timeout" });
    $self->alrm_send_sub(sub { die "send() runs on a timeout" });
    $self->alrm_recv_sub(sub { die "recv() runs on a timeout" });
}

sub connect {
    my $self = shift;
    my $timeout = shift || 0;
    my %opts = %{$self->{sockopts}};
    my @err;

    eval {
        local $SIG{__DIE__} = $self->die_sub;
        local $SIG{ALRM} = $self->alrm_conn_sub;

        if ($self->{peeraddr}) {
            my $peers = $self->{peeraddr};
            my $count = scalar @$peers;

            if ($timeout) {
                $opts{Timeout} = $timeout;
                $timeout = $timeout * $count + 5;
                alarm($timeout);
            }

            while ($count--) {
                my $peer = $peers->[0];

                if ($self->{mode} eq "balanced") {
                    push @$peers, shift @$peers;
                }

                $opts{PeerAddr} = $peer;
                $self->{sock} = $self->{sockmod}->new(%opts);

                if ($self->{sock}) {
                    last;
                }

                if ($self->{mode} eq "failover") {
                    push @err, "$peer:$opts{PeerPort}";
                    push @$peers, shift @$peers;
                }
            }

            if (!$self->{sock}) {
                die "unable to connect to ". join(", ", @err);
            }
        } else {
            # a listen socket
            if ($timeout) {
                alarm($timeout);
            }
            $self->{sock} = $self->{sockmod}->new(%opts)
                or die "unable to create socket";
        }

        alarm(0);
    };

    if ($@) {
        $self->log->error($@);
        $self->_sock_error($@);
        die $self->errstr;
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
    my $self = shift;
    my $data = @_ > 1 ? {@_} : shift;
    my $ret;

    $self->log->debug("encode data");
    $data = $self->json->encode($data);
    $self->log->debug("pack data");
    $data = pack("N/a*", $data);
    $self->log->debug("send data");
    $data = "00" . $data;

    eval {
        local $SIG{__DIE__} = $self->die_sub;
        local $SIG{ALRM} = $self->alrm_send_sub;
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
        local $SIG{ALRM} = $self->alrm_recv_sub;
        alarm($self->{recv_timeout});
        ($data, $length) = $self->_recv_data(@_);
        alarm(0);
    };

    if ($@) {
        $self->_errstr($@);
        return wantarray ? (undef, 0) : undef;
    }

    return wantarray ? ($data, $length) : $data;
}

sub _recv_data {
    my $self = shift;
    my $maxbyt = $self->{revc_max_bytes};

    # This 2 bytes are reserved for data options like
    # compression, encryption and so on...
    $self->log->debug("recv 2 bytes (opts)");
    my $opts = $self->_recv(2);

    if (!defined $opts) {
        die "no 2 bytes received (opts)";
    }

    $self->log->debug("recv 4 bytes (length)");
    my $length = $self->_recv(4);

    if (!defined $length) {
        die "no 4 bytes received (length)";
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
        $self->{errstr} .= " - ". IO::Socket::SSL->errstr;
        if ($IO::Socket::SSL::SSL_ERROR && $IO::Socket::SSL::SSL_ERROR ne IO::Socket::SSL->errstr) {
            $self->{errstr} .= " - ". $IO::Socket::SSL::SSL_ERROR;
        }
    } else {
        $self->{errstr} .= " - $@";
    }

    return undef;
}

sub validate {
    my $class = shift;

    my %opts = Params::Validate::validate(@_, {
        host => {
            type => Params::Validate::SCALAR,
            optional => 1
        },
        port => {
            type => Params::Validate::SCALAR,
            optional => 1
        },
        peeraddr => {
            type => Params::Validate::SCALAR,
            optional => 1
        },
        peerport => {
            type => Params::Validate::SCALAR,
            optional => 1
        },
        localaddr => {
            type => Params::Validate::SCALAR,
            optional => 1
        },
        localport => {
            type => Params::Validate::SCALAR,
            optional => 1
        },
        listen => {
            type => Params::Validate::SCALAR,
            regex => qr/^(0|1|no|yes)\z/,
            optional => 1
        },
        use_ssl => {
            type => Params::Validate::SCALAR,
            regex => qr/^(0|1|no|yes)\z/,
            default => 0
        },
        ssl_ca_file => {
            type => Params::Validate::SCALAR,
            optional => 1
        },
        ssl_ca_path => {
            type => Params::Validate::SCALAR,
            optional => 1
        },
        ssl_cert_file => {
            type => Params::Validate::SCALAR,
            optional => 1
        },
        ssl_key_file  => {
            type => Params::Validate::SCALAR,
            optional => 1
        },
        ssl_verify_mode => {
            type => Params::Validate::SCALAR,
            regex => qr/^(0|none|1|peer)\z/,
            default => "peer"
        },
        ssl_verifycn_name => {
            type => Params::Validate::SCALAR,
            optional => 1
        },
        ssl_verifycn_scheme => {
            type => Params::Validate::SCALAR,
            optional => 1
        },
        recv_max_bytes => {
            type => Params::Validate::SCALAR,
            regex => qr/^(?:unlimited|\d+(?:b{0,1}|[kmgt]b{0,1}))\z/,
            default => "512k"
        },
        send_max_bytes => {
            type => Params::Validate::SCALAR,
            regex => qr/^(?:unlimited|\d+(?:b{0,1}|[kmgt]b{0,1}))\z/,
            default => 0
        },
        recv_timeout => {
            type => Params::Validate::SCALAR,
            regex => qr/^\d+\z/,
            default => 15
        },
        send_timeout => {
            type => Params::Validate::SCALAR,
            regex => qr/^\d+\z/,
            default => 15
        },
        timeout => {
            type => Params::Validate::SCALAR,
            regex => qr/^\d+\z/,
            optional => 1
        },
        connect_timeout => {
            type => Params::Validate::SCALAR,
            regex => qr/^\d+\z/,
            default => 10
        },
        recvbuf => {
            type => Params::Validate::SCALAR,
            regex => qr/^\d+\z/,
            default => 16384
        },
        auto_connect => {
            type => Params::Validate::SCALAR,
            regex => qr/^(0|1|no|yes)\z/,
            default => 0
        },
        mode => {
            type => Params::Validate::SCALAR,
            regex => qr/^(failover|balanced)\z/,
            default => "failover"
        },
        force_ipv4 => {
            type => Params::Validate::SCALAR,
            regex => qr/^(0|1|no|yes|auto)\z/,
            default => "auto"
        }
    });

    foreach my $key (qw/listen use_ssl auto_connect force_ipv4/) {
        if (defined $opts{$key}) {
            $opts{$key} = $opts{$key} =~ /^(yes|1)\z/ ? 1 : 0;
        }
    }

    if ($opts{host}) {
        if ($opts{listen}) {
            $opts{localaddr} = delete $opts{host};
        } else {
            $opts{peeraddr} = delete $opts{host};
        }
    }

    if ($opts{port}) {
        if ($opts{listen}) {
            $opts{localport} = delete $opts{port};
        } else {
            $opts{peerport} = delete $opts{port};
        }
    }

    if (!$opts{listen} && !$opts{ssl_verifycn_scheme}) {
        $opts{ssl_verifycn_scheme} = "http";
    }

    if (($opts{force_ipv4} eq "auto" && !$opts{listen}) || $opts{force_ipv4}) {
        eval "use IO::Socket::SSL 'inet4'";
    }

    if ($opts{timeout}) {
        $opts{recv_timeout} = $opts{timeout};
        $opts{send_timeout} = $opts{timeout};
    }

    if ($opts{peeraddr}) {
        $opts{peeraddr} =~ s/\s//g;
        $opts{peeraddr} = [ split /,/, $opts{peeraddr} ];
    }

    # Mapping socket opts
    my %sockopts = (
        localaddr => 'LocalAddr',
        localport => 'LocalPort',
        peerport  => 'PeerPort',
        peeraddr  => 'PeerAddr'
    );

    while (my ($opt, $modopt) = each %sockopts) {
        if ($opts{$opt}) {
            $opts{sockopts}{$modopt} = $opts{$opt};
        }
    }

    if ($opts{listen}) {
        $opts{sockopts}{Listen} = SOMAXCONN;
        $opts{sockopts}{ReuseAddr}  = 1;
        $opts{sockopts}{Proto}  = "tcp";
    } elsif ($opts{connect_timeout}) {
        $opts{sockopts}{Timeout} = $opts{connect_timeout};
    }

    if ($opts{use_ssl}) {
        $opts{sockmod} = "IO::Socket::SSL";

        if ($opts{ssl_key_file} || $opts{ssl_cert_file}) {
            foreach my $file (qw/ssl_key_file ssl_cert_file/) {
                if (!$opts{$file}) {
                    die "missing param '$file' in configuration";
                }
                if (!-r $opts{$file}) {
                    die "file '$opts{$file}' is not readable";
                }
            }

            if ($opts{ssl_ca_file} && !-r $opts{ssl_ca_file}) {
                die "file '$opts{ssl_ca_file}' is not readable";
            }
        }

        if (defined $opts{ssl_verify_mode}) {
            if ($opts{ssl_verify_mode} eq "0" || $opts{ssl_verify_mode} eq "none") {
                $opts{ssl_verify_mode} = SSL_VERIFY_NONE;
            } elsif ($opts{ssl_verify_mode} eq "1" || $opts{ssl_verify_mode} eq "peer") {
                $opts{ssl_verify_mode} = SSL_VERIFY_PEER;
            }
        }

        my %sslopts = (
            ssl_use_cert => "SSL_use_cert",
            ssl_ca_file  => "SSL_ca_file",
            ssl_ca_path  => "SSL_ca_path",
            ssl_cert_file => "SSL_cert_file",
            ssl_key_file => "SSL_key_file",
            ssl_verify_mode => "SSL_verify_mode",
            ssl_verifycn_name => "SSL_verifycn_name",
            ssl_verifycn_scheme => "SSL_verifycn_scheme"
        );

        while (my ($opt, $modopt) = each %sslopts) {
            if (defined $opts{$opt}) {
                $opts{sockopts}{$modopt} = $opts{$opt};
            }
        }
    } else {
        $opts{sockmod} = "IO::Socket::INET";
    }

    if ($@) {
        die "unable to load $opts{sockmod}";
    }

    my %bytes = (
        b => 1,
        k => 1024,
        m => 1048576,
        g => 1073741824,
        t => 1099511627776,
    );

    foreach my $opt (qw/recv_max_bytes send_max_bytes/) {
        if ($opts{$opt} =~ /^(\d+)([bkmgt]{0,1})\z/) {
            my ($num, $byt) = ($1, $2 || 'b');
            $opts{$opt} = $num * $bytes{$byt};
        } else {
            $opts{$opt} = 0;
        }
    }

    return \%opts;
}

1;
