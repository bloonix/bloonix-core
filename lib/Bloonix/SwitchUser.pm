package Bloonix::SwitchUser;

use strict;
use warnings;
use POSIX qw(getgrnam getpwnam getgid getuid setgid setuid);

# to() switch both. if the group is not set, the user is used as group
sub to {
    my ($class, $user, $group) = @_;
    $class->switch_group($group || $user);
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
            if (getuid != 0) {
                die "you need root permission to run this program";
            }
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
            if (getuid != 0) {
                die "you need root permission to run this program";
            }
            setuid($uid) or die "Unable to change to uid($uid) - $!";
        }
    }
}

1;
