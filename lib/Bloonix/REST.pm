=head1 NAME

Bloonix::REST - REST api.

=head1 SYNOPSIS

    use Bloonix::REST;

    my $api = Bloonix::REST->new(
        proto => "http",
        host => "127.0.0.1:8080, 127.0.0.2:8080",
        timeout => 60,
        mode => "balanced",
    );

=head1 DESCRIPTION

This module provides a REST API.

=head1 PARAMETER

=over 4

=item proto

Which protocol to use. Allowed are http and https.

=item host

The host and port number to send the http request.

=item timeout

The timeout for a complete http request.

=item mode

How to connect to the list of hosts. C<balanced> means to balance the requests.
C<failover> means to use the next available host if the connection to the last
host failed.

=back

=head1 METHODS

=head2 new

Create a new api object.

=head2 get, post, put, delete ("path" => { data => 1 })

Send a GET, POST, PUT or DELETE request.

=head2 request(GET => "path" => { data => 1 })

This method is called by C<get>, C<post> and C<put>.

=head2 jsonstr

Returns the raw json string after a request.

=head2 length

Returns the length of the raw json data.

=head2 errstr

The last error message.

=head2 validate

Validaten options.

=head2 http

Accessor to HTTP::Tiny.

=head2 json

Accessor to JSON.

=head2 log

Accessor to Log::Handler.

=head2 default_data

Set some data that are send by each json request.

=head2 set_header

Add the header to each request.

=head2 add_pre_check, add_post_check

    $rest->add_pre_check(sub {});
    $rest->add_post_check(sub {});

=head2 pre_check, post_check

Run callbacks before and after a request.

=head1 PREREQUISITES

    HTTP::Tiny
    IO::Uncompress::Gunzip
    Log::Handler
    JSON

=head1 AUTHOR

Jonny Schulz <support(at)bloonix.de>.

=head1 COPYRIGHT

Copyright (C) 2013-2014 by Jonny Schulz. All rights reserved.

=cut

package Bloonix::REST;

use strict;
use warnings;
use IO::Uncompress::Gunzip;
use IO::Socket::SSL 1.77;
use JSON;
use Log::Handler 0.84;
use HTTP::Tiny 0.022;
use Carp qw(croak);

use base qw/Bloonix::Accessor/;
__PACKAGE__->mk_accessors(qw/http json log jsonstr/);

sub new {
    my $class = shift;
    my $opts = $class->validate(@_);
    my $self = bless $opts, $class;

    my %http_opts = (
        timeout => $opts->{timeout},
        default_headers => {
            "Accept-Encoding" => "compress, gzip",
            "Content-Type" => "application/json; charset=UTF-8"
        }
    );

    if ($self->{ssl_options}) {
        $http_opts{SSL_options} = $self->{ssl_options};
    }

    $self->{default_data} = $opts->{default_data};
    $self->{http} = HTTP::Tiny->new(%http_opts);
    $self->{http}->timeout($opts->{timeout});
    $self->{json} = $opts->{utf8} ? JSON->new->utf8 : JSON->new;
    $self->{log} = Log::Handler->get_logger("bloonix");
    $self->{set_header} = {};

    return $self;
}

sub utf8 {
    my ($self, $flag) = @_;

    $self->json->utf8($flag);
}

sub put {
    my $self = shift;

    $self->request("PUT", @_);
}

sub post {
    my $self = shift;

    $self->request("POST", @_);
}

sub get {
    my $self = shift;

    $self->request("GET", @_);
}

sub delete {
    my $self = shift;

    $self->request("DELETE", @_);
}

sub set_pre_check {
    my ($self, $code) = @_;

    $self->{pre_check} = $code;
}

sub set_post_check {
    my ($self, $code) = @_;

    $self->{post_check} = $code;
}

sub request {
    my $self = shift;
    my $method = shift;
    my $opts = {@_};
    my $uris = $self->{uri};
    my $count = scalar @$uris;

    $self->_pre_check;
    $self->_inject_content_type($opts);
    $self->_inject_default_data($opts);
    $self->_serialize_data($opts);
    $self->_process_path($opts);

    my $req_opts = $self->_get_req_opts($opts);

    while ($count--) {
        my $uri = $uris->[0];

        if ($self->{mode} eq "balanced") {
            push @$uris, shift @$uris;
        }

        $self->log->info("rest: request '$uri/$opts->{path}");

        my $res = $self->http->request(
            $method,
            "$uri/$opts->{path}",
            $req_opts
        );

        if ($res->{success}) {
            $self->log->info("rest: request was successful");
            return $self->_process_content($res);
        }

        if ($self->{mode} eq "failover") {
            push @$uris, shift @$uris;
        }

        $self->errstr(
            "rest: request failed to '$uri/$opts->{path}': ["
            . $res->{status} . " " . $res->{reason}
            ."], message: ["
            . $res->{content}
            ."]"
        );
    }

    $self->_post_check;
    return undef;
}

sub default_data {
    my $self = shift;

    if (@_) {
        my $data = @_ > 1 ? {@_} : shift;
        $self->{default_data} ||= { };
        %{$self->{default_data}} = (%{$self->{default_data}}, %$data);
    }

    return $self->{default_data};    
}

sub set_header {
    my $self = shift;

    if (@_) {
        my $header = @_ > 1 ? {@_} : shift;

        foreach my $key (keys %$header) {
            $self->{set_header}->{$key} = $header->{$key};
        }
    }

    return $self->{set_header};
}

sub reuse_cookies {
    my ($self, $headers) = @_;
    my $reuse = $self->{reuse_cookies};

    if (!$headers->{"set-cookie"}) {
        return;
    }

    if (ref $headers->{"set-cookie"} ne "ARRAY") {
        $headers->{"set-cookie"} = [ $headers->{"set-cookie"} ];
    }

    foreach my $header (@{$headers->{"set-cookie"}}) {
        my @parts = split /\s*;\s*/, $header;
        foreach my $part (@parts) {
            my ($key, $value) = split /=/, $part;
            if (exists $reuse->{$key}) {
                $self->set_header(Cookie => "$key=$value");
            }
        }
    }
}

sub length {
    my $self = shift;

    return length $self->jsonstr;
}

sub errstr {
    my ($self, $errstr, $dump) = @_;

    if ($errstr) {
        $self->{errstr} = $errstr;
        $self->log->trace(error => $errstr);
        if ($dump) {
            $self->log->dump(error => $dump);
        }
        if ($self->{autodie}) {
            croak $errstr;
        }
        return undef;
    }

    return $self->{errstr};
}

sub validate {
    my $class = shift;

    my %opts = Params::Validate::validate(@_, {
        proto => {
            type => Params::Validate::SCALAR,
            regex => qr/^(http|https)\z/,
            default => "http"
        },
        host => {
            type => Params::Validate::SCALAR,
            default => "127.0.0.1"
        },
        timeout => {
            type => Params::Validate::SCALAR,
            regex => qr/^\d+\z/,
            default => 60
        },
        mode => {
            type => Params::Validate::SCALAR,
            regex => qr/^(balanced|failover)\z/,
            default => "balanced"
        },
        content_type => {
            type => Params::Validate::SCALAR,
            default => "application/json"
        },
        compress => {
            type => Params::Validate::SCALAR,
            regex => qr/^(yes|no)\z/,
            default => "yes"
        },
        autodie => {
            type => Params::Validate::SCALAR,
            regex => qr/^(yes|no)\z/,
            default => "no"
        },
        ssl_options => {
            type => Params::Validate::HASHREF,
            optional => 1
        },
        default_data => {
            type => Params::Validate::HASHREF,
            optional => 1
        },
        utf8 => {
            type => Params::Validate::SCALAR,
            regex => qr/^(yes|no)\z/,
            default => "no"
        },
        reuse_cookies => {
            type => Params::Validate::SCALAR,
            optional => 1
        },
        safe_cookies => {
            type => Params::Validate::SCALAR,
            optional => 1
        },
        cookie_file => {
            type => Params::Validate::SCALAR,
            optional => 1
        }
    });

    $opts{host} =~ s!/$!!;
    if ($opts{host} =~ s!^(https{0,1})://!!) {
        $opts{proto} = $1;
    }

    foreach my $key (qw/autodie utf8/) {
        $opts{$key} = $opts{$key} eq "yes" ? 1 : 0;
    }

    foreach my $host (split /,/, $opts{host}) {
        $host =~ s/\s//g;
        push @{$opts{uri}}, "$opts{proto}://$host";
    }

    if ($opts{ssl_options}) {
        my $ssl_opts = $opts{ssl_options};
        $opts{ssl_options} = { };
        foreach my $key (keys %$ssl_opts) {
            my $value = $ssl_opts->{$key};
            $key =~ s/^ssl/SSL/;
            $opts{ssl_options}{$key} = $value;
        }
    }

    foreach my $opt (qw/reuse_cookies safe_cookies/) {
        if ($opts{$opt}) {
            $opts{$opt} =~ s/\s//g;
            $opts{$opt} = { map { $_ => undef } split(/,/, $opts{$opt}) };
        }
    }

    if ($opts{safe_cookies} && !$opts{cookie_file}) {
        my $home = $ENV{HOME} || (getpwuid($<))[7];

        if (!$home && !-d $home) {
            die "ERR: unable to determine home directory\n";
        }

        my $host = $opts{host};
        $host =~ s/[a-zA-Z0-9\.\-]/_/g;
        $opts{cookie_file} = "$home/.bloonix-rest-sid-$host";
    }

    return \%opts;
}

sub _pre_check {
    my $self = shift;

    if ($self->{pre_check}) {
        my $code = $self->{pre_check};
        return &$code(@_);
    }
}

sub _post_check {
    my $self = shift;

    if ($self->{post_check}) {
        my $code = $self->{post_check};
        return &$code(@_);
    }
}

sub _inject_content_type {
    my ($self, $opts) = @_;

    if (!defined $opts->{content_type}) {
        $opts->{content_type} = $self->{content_type};
    }
}

sub _inject_default_data {
    my ($self, $opts) = @_;

    if ($self->{default_data}) {
        %{$opts->{data}} = $opts->{data}
            ? (%{$self->{default_data}}, %{$opts->{data}})
            : %{$self->{default_data}};
    }
}

sub _serialize_data {
    my ($self, $opts) = @_;

    if (defined $opts->{data}) {
        if (ref $opts->{data}) {
            $opts->{data} = $self->json->encode($opts->{data});
        }
    }
}

sub _process_path {
    my ($self, $opts) = @_;

    if (defined $opts->{request}) {
        $opts->{path} = $opts->{request};
    }

    if (!defined $opts->{path}) {
        $opts->{path} = "";
    } else {
        $opts->{path} =~ s!^/!!;
    }
}

sub _get_req_opts {
    my ($self, $opts) = @_;
    my $req_opts = {};

    if ($self->{set_header}) {
        $req_opts->{headers} = $self->{set_header};
    }

    # temporary header
    if ($opts->{header}) {
        foreach my $key (keys %{$opts->{header}}) {
            $req_opts->{headers}->{$key} = $opts->{header}->{$key};
        }
    }

    if ($opts->{data}) {
        $req_opts->{content} = $opts->{data};
    }

    return $req_opts;
}

sub _process_content {
    my ($self, $res) = @_;
    my $content;
    my $headers = $res->{headers};
    my $encoding = $headers->{"content-encoding"};

    if ($self->{reuse_cookies}) {
        $self->reuse_cookies($headers);
    }

    eval {
        if ($encoding && ($encoding eq "gzip" || $encoding eq "x-gzip")) {
            $self->log->info("rest: start uncompress content");
            IO::Uncompress::Gunzip::gunzip(\$res->{content}, \$content, Transparent => 0)
                or die "Can't gunzip content: $IO::Uncompress::Gunzip::GunzipError";
            $self->log->info("rest: uncompress finished");
        } else {
            $content = $res->{content}
        }

        $self->log->info("rest: start de-serializing json data");
        $self->jsonstr($content);
        $content = $self->json->decode($content);
    };

    if ($@) {
        $self->errstr("rest: de-serializing/de-compressing failed: $@");
        $self->_post_check;
        return undef;
    }

    $self->log->info("rest: de-serializing json data finished");
    $self->_post_check($content);
    return $content;
}

1;
