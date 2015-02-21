package Bloonix::SwitchUser;

use strict;
use warnings;
use POSIX qw(getgid getuid setgid setuid);

sub to {
    my ($class, $user, $group) = @_;

    $class->swtich_group($group);
    $class->switch_user($user);
}

sub switch_group {
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

sub switch_user {
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
