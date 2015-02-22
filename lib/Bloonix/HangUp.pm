package Bloonix::HangUp;

use strict;
use warnings;
use Bloonix::SwitchUser;
use POSIX qw(setsid);

sub now {
    my ($class, %opts) = @_;
    my $self = bless \%opts, $class;
    $self->hang_up;
    $self->create_pid_file;
    $self->switch_group;
    $self->switch__user;
    $self->change_directory;
    $self->redirect_to_dev_null;
}

sub hang_up {
    my $self = shift;
    setsid();
    my $pid = fork;
    exit 0 if $pid;
    exit 1 if !defined $pid;
}

sub swtich_group {
    my ($self, $group) = @_;

    Bloonix::SwitchUser->switch_group(
        $group || $self->{group}
    );
}

sub swtich_user {
    my ($self, $user) = @_;

    Bloonix::SwitchUser->switch_user(
        $user || $self->{user}
    );
}

sub change_directory {
    my ($self, $dir) = @_;
    $dir ||= $self->{change_directory} || "/";
    chdir $dir;
}

sub create_pid_file {
    my ($self, $file) = @_;
    $file ||= $self->{pid_file};

    if ($file) {
        open my $fh, ">", $file
            or die "unable to open run file '$file': $!";
        print $fh $$
            or die "unable to write to run file '$file': $!";
        close $fh;
    }
}

sub redirect_to_dev_null {
    my $self = shift;

    if ($self->{redirect_to}) {
        if (!-e $self->{redirect_to}) {
            open my $fh, ">>", $self->{redirect_to}
                or die "unable to open '$self->{redirect_to}' - $!";
            close $fh;
        }
        open STDIN, "<", "/dev/null" or die $!;
        open STDOUT, ">>", $self->{redirect_to} or die $!;
        open STDERR, ">>", $self->{redirect_to} or die $!;
    } elsif (!defined $self->{dev_null} || $self->{dev_null}) {
        open STDIN, "<", "/dev/null" or die $!;
        open STDOUT, ">", "/dev/null" or die $!;
        open STDERR, ">", "/dev/null" or die $!;
    }
}

1;
