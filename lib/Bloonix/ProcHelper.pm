package Bloonix::ProcHelper;

use strict;
use warnings;
use Log::Handler;
use base qw(Bloonix::Accessor);
__PACKAGE__->mk_accessors(qw/log/);

sub new {
    my $class = shift;
    my $opts = $class->validate(@_);
    my $self = bless $opts, $class;
    $self->log(Log::Handler->get_logger("bloonix"));
    return $self;
}

sub is_server_status {
    my ($self, %opts) = @_;
    my ($addr, $authkey, $plain, $pretty);
    my $proc = $opts{proc};
    my $cgi = $opts{cgi};

    if ($cgi) {
        if ($cgi->path_info ne "/server-status") {
            return;
        }
        $addr = $cgi->remote_addr || "n/a";
        $authkey = $cgi->param("authkey") || "";
        $plain = defined $cgi->param("plain") ? 1 : 0;
        $pretty = defined $cgi->param("pretty") ? 1 : 0;
    }

    if ($self->{enabled} eq "yes") {
        my $allow_from = $self->{allow_from};

        if ($allow_from->{all} || $allow_from->{$addr} || ($self->{authkey} && $self->{authkey} eq $authkey)) {
            $self->log->info("server status request from $addr - access allowed");
            $proc->set_status_sending;

            if ($plain) {
                print "Content-Type: text/plain\n\n";
                print $proc->get_plain_server_status;
            } else {
                print "Content-Type: application/json\n\n";
                print $proc->get_json_server_status(pretty => $pretty);
            }
        } else {
            $self->log->warning("server status request from $addr - access denied");
            print "Content-Type: text/plain\n\n";
            print "access denied\n";
        }

        return 1;
    }

    return undef;
}

sub validate {
    my $class = shift;

    my %opts = Params::Validate::validate(@_, {
        enabled => {
            type => Params::Validate::SCALAR,
            default => "yes",
            regex => qr/^(0|1|no|yes)\z/
        },
        location => {
            type => Params::Validate::SCALAR,
            optional => 1
        },
        allow_from => {
            type => Params::Validate::SCALAR,
            default => "127.0.0.1"
        },
        authkey => {
            type => Params::Validate::SCALAR,
            optional => 1
        }
    });

    # deprecated
    delete $opts{location};

    if ($opts{enabled} eq "no") {
        $opts{enabled} = 0;
    }

    $opts{allow_from} =~ s/\s//g;
    $opts{allow_from} = {
        map { $_, 1 } split(/,/, $opts{allow_from})
    };

    return \%opts;
}

1;
