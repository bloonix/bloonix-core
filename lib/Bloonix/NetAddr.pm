package Bloonix::NetAddr;

use strict;
use warnings;
use NetAddr::IP qw();

sub ip_in_range {
    my ($self, $a, $b) = @_;
    my $ret = 0;

    if (ref $b eq "ARRAY") {
        $b = join(",", @$b);
    }

    if (!$a || !$b) {
        return $ret;
    }

    $a =~ s/\s//g;
    $b =~ s/\s//g;

    if ($b eq "all") {
        return 1;
    }

    eval {
        my $ip_a = NetAddr::IP->new($a);

        foreach my $ip (split /,/, $b) {
            # compare only ipv4 with ipv4 and ipv6 with ipv6
            if (($a =~ /:/ && $ip =~ /:/) || ($a !~ /:/ && $ip !~ /:/)) {
                my $ip_b = NetAddr::IP->new($ip);

                if ($ip_a->within($ip_b)) {
                    $ret = 1;
                    last;
                }
            }
        }
    };

    return $ret;
}

1;
