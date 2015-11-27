=head1 NAME

Bloonix::Validate::Regexes - Validate regexes.

=head1 SYNOPSIS

=head1 DESCRIPTION

Just for internal usage!

=head1 METHODS

=head2 new

=cut

package Bloonix::Validate::Regexes;

use strict;
use warnings;
use base qw(Bloonix::Accessor);

__PACKAGE__->mk_accessors(qw/
    digit number float alphas non_alphas
    bool true false email
    time date datetime datehourmin
    ipv4 ipv4net ipv6 ipv6net
    ipaddr ipaddr_all ipaddrnet ipaddrnet_all
    class_path
/);

my $rx_digit      = qr/^\d\z/;
my $rx_number     = qr/^\d+\z/;
my $rx_float      = qr/^\d+\.\d+\z/;
my $rx_alphas     = qr/^\w+\z/;
my $rx_non_alphas = qr/^\W+\z/;
my $rx_bool       = qr/^[01]\z/;
my $rx_true       = qr/^1\z/;
my $rx_false      = qr/^0\z/;
my $rx_class_path = qr!^(/[^"]+){0,}\z!;

# In the past I used Mail::RFC822::Address to parse mail addresses,
# but RFC822 really sucks! It allows mail addresses like
#
#   user@[IPv6:2001:db8:1ff::a0b:dbd0]
#   "very.(),:;<>[]\".VERY.\"very@\\ \"very\".unusual"@strange.example.com
#   "()<>[]:,;@\\\"!#$%&'*+-/=?^_`{}| ~.a"@example.org
#
# For this reason I wrote my own mail parser.
#
#   - only the signs a-z, A-Z, 0-9 and .-+_ are allowed in the name part
#   - doubled signs of .-+_ are not allowed in the name part
#   - only the signs a-z, A-Z, 0-9 and .- are allowed in the host part
#   - doubled signs of .- are not allowed in the host part
#   - both, the name and host part must begin and end with a-z, A-Z or 0-9
#
my $rx_email = qr/
    ^                                       # The beginning of the hell
    [a-zA-Z0-9]+([\.\-\+=_][a-zA-Z0-9]+)*   # this is the name part
    @                                       # delimiter between the name and host
    [a-zA-Z0-9]+([\.\-][a-zA-Z0-9]+)*       # subdomain with domain name
    \.                                      # delimiter betwenn domain and tld
    [a-zA-Z]{2,}                            # the top level domain name
    \z                                      # the end of the hell
/x;

my $rx_year  = qr/\d{4}/;
my $rx_month = qr/(?:0[1-9]|1[0-2])/;
my $rx_day   = qr/(?:0[1-9]|[1-2][0-9]|3[0-1])/;
my $rx_hour  = qr/(?:[0-1][0-9]|2[0-3])/;
my $rx_min   = qr/[0-5][0-9]/;
my $rx_sec   = $rx_min;
my $rx_date  = qr/^$rx_year-$rx_month-$rx_day\z/;
my $rx_time  = qr/^$rx_hour:$rx_min:$rx_sec\z/;

my $rx_datetime    = qr/^$rx_year-$rx_month-$rx_day\s$rx_hour:$rx_min:$rx_sec\z/;
my $rx_datehourmin = qr/^$rx_year-$rx_month-$rx_day\s$rx_hour:$rx_min\z/;

my $rx_port = qr/
    ^(?:
        6553[0-5]|655[0-2][0-9]|65[0-4][0-9]{2}|6[0-4][0-9]{3}|
        [0-5]?[0-9]{4}|
        [0-9]{2,4}|
        [1-9]
    )\z
/x;

my $rx_ipv4_base = qr/
    (?: 25[0-5] | 2[0-4][0-9] | 1[0-9][0-9] | 0{0,1}[1-9][0-9] | 0{0,2}[1-9] ) \.
    (?: 25[0-5] | 2[0-4][0-9] | 1[0-9][0-9] | 0{0,1}[1-9][0-9] | 0{0,2}[0-9] ) \.
    (?: 25[0-5] | 2[0-4][0-9] | 1[0-9][0-9] | 0{0,1}[1-9][0-9] | 0{0,2}[0-9] ) \.
    (?: 25[0-5] | 2[0-4][0-9] | 1[0-9][0-9] | 0{0,1}[1-9][0-9] | 0{0,2}[0-9] )
/x;

my $rx_ipv4 = qr/^$rx_ipv4_base\z/;
my $rx_ipv4net_base = qr/$rx_ipv4_base\/([0-9]|[12][0-9]|3[012])/;
my $rx_ipv4net = qr/^$rx_ipv4net_base\z/;

# No leading 0 is allowed
my $ipv6_part = '([0-9A-Fa-f]{1,4}|[0-9A-Fa-f])';

my $rx_ipv6_base = qr/^
    (
        ($ipv6_part:){7}$ipv6_part
        |($ipv6_part:){6}:$ipv6_part
        |($ipv6_part:){5}(:$ipv6_part){2}
        |($ipv6_part:){4}(:$ipv6_part){3}
        |($ipv6_part:){3}(:$ipv6_part){4}
        |($ipv6_part:){2}(:$ipv6_part){5}
        |$ipv6_part:(:$ipv6_part){6}
        |($ipv6_part:){5}:$ipv6_part
        |($ipv6_part:){4}(:$ipv6_part){2}
        |($ipv6_part:){2}(:$ipv6_part){4}
        |$ipv6_part:(:$ipv6_part){5}
        |($ipv6_part:){4}:$ipv6_part
        |$ipv6_part:(:$ipv6_part){4}
        |($ipv6_part:){1,3}(:$ipv6_part){1,3}
        |:(:$ipv6_part){1,7}
        |($ipv6_part:){1,7}:
        |::
    )
\z/x;

my $rx_ipv6 = qr/^$rx_ipv6_base\z/;
my $rx_ipv6net_base = qr/$rx_ipv6_base\/([0-9]|[1-9][0-9]|1[01][0-9]|12[0-8])/;
my $rx_ipv6net = qr/^$rx_ipv6net_base\z/;
my $rx_ipaddr = qr/^($rx_ipv4_base|$rx_ipv6_base)\z/x;
my $rx_ipaddr_all = qr/^($rx_ipv4_base|$rx_ipv6_base|all)\z/x;
my $rx_ipaddrnet = qr/^($rx_ipv4net_base|$rx_ipv6net_base)\z/x;
my $rx_ipaddrnet_all = qr/^($rx_ipv4net_base|$rx_ipv6net_base|all)\z/x;

sub new {
    my $class = shift;

    my $self = bless {
        digit           => $rx_digit,
        number          => $rx_number,
        float           => $rx_float,
        alphas          => $rx_alphas,
        non_alphas      => $rx_non_alphas,
        bool            => $rx_bool,
        true            => $rx_true,
        false           => $rx_false,
        email           => $rx_email,
        ipv4            => $rx_ipv4,
        ipv4net         => $rx_ipv4net,
        ipv6            => $rx_ipv6,
        ipv6net         => $rx_ipv6net,
        ipaddr          => $rx_ipaddr,
        ipaddr_all      => $rx_ipaddr_all,
        ipaddrnet       => $rx_ipaddrnet,
        ipaddrnet_all   => $rx_ipaddrnet_all,
        time            => $rx_time,
        date            => $rx_date,
        datetime        => $rx_datetime,
        datehourmin     => $rx_datehourmin,
        class_path      => $rx_class_path
    }, $class;

    return $self;
}

1;
