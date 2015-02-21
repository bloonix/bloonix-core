package Bloonix::SwitchUser;

use strict;
use warnings;
use POSIX qw(getgid getuid setgid setuid);

sub change_group {
    my ($class, $group) = @_;

    if ($group) {
        my $gid = getgrnam($group);

        if (!defined $gid) {
            die "Unable to get gid for group $group";
        }

        if ($gid != getgid) {
            setgid($gid) or die "Unable to change to gid($gid) - $!";
        }
    }
}

sub change_user {
    my ($class, $user) = @_;

    if ($user) {
        my $uid = getpwnam($user);

        if (!defined $uid) {
            die "Unable to get uid for user $user";
        }

        if ($uid != getuid) {
            setuid($uid) or die "Unable to change to uid($uid) - $!";
        }
    }
}

1;
