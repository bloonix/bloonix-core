=head1 NAME

Bloonix::IPC::Cmd - Simple module to make system calls with open3.

=head1 SYNOPSIS

    my $ipc = Bloonix::IPC::Cmd->run(
        command     => "sleep",
        arguments   => 10,
        timeout     => 3,
        kill_signal => 9
    );

=head1 DESCRIPTION

=head1 METHODS

=head2 run

Execute a command. The method returns an object.

=head2 stdout

Returns the output from stdout.

=head2 stderr

Returns the output from stderr.

=head2 get_stdout, get_stderr

Returns the entries as list.

=head2 is_stdout

    if ($ipc->is_stdout) {
        print "STDOUT: ", $ipc->stdout;
    }

=head2 is_stderr

    if ($ipc->is_stderr) {
        print "STDERR: ", $ipc->stderr;
    }

=head2 timeout

    if ($ipc->timeout) {
        print "TIMEOUT: ", $ipc->timeout;
    }

=head2 exitcode

Returns the exit code.

=head2 unknown

Returns the unknown error message.

=head1 PREREQUISITES

    IO::Select;
    Params::Validate
    Log::Handler;
    Socket

=head1 AUTHOR

Jonny Schulz <support(at)bloonix.de>.

=head1 COPYRIGHT

Copyright (C) 2009-2014 by Jonny Schulz. All rights reserved.

=cut

package Bloonix::IPC::Cmd;

use strict;
use warnings;
use IPC::Open3;
use IO::Select;
use Params::Validate qw//;
use Socket qw( AF_UNIX SOCK_STREAM PF_UNSPEC );
use Log::Handler;

# The IPC::Open3 version of Perl version until 5.8 has a bug
# and is not upgradeable. For this reason a copy of IPC::Open3
# of Perl 5.14 is used is the Perl version is lower than 5.10.
BEGIN {
    if ($^V <= 5.8) {
        require Bloonix::IPC::Open3;
    }
}

use base qw(Bloonix::Accessor);
__PACKAGE__->mk_accessors(qw/log stdout stderr timeout exitcode unknown/);

use constant SYS_READ_LEN => 4096;
use constant ALRM_TIMEOUT =>    0;
use constant IS_WIN32     => $^O =~ /Win32/i ? 1 : 0;
use constant SYS_READ_LEN_WIN32 => 1024;

sub run {
    my $class = shift;
    my $args  = $class->_validate(@_);

    my $self = bless {
        log      => Log::Handler->get_logger("bloonix"),
        unknown  => "",
        timeout  => 0,
        exitcode => 3,
    }, $class;

    if (IS_WIN32) {
        $self->_run_win32($args);
    } else {
        $self->_run($args);
    }

    return $self;
}

sub get_stdout {
    my $self = shift;

    return @{ $self->stdout };
}

sub get_stderr {
    my $self = shift;

    return @{ $self->stderr };
}

sub is_stdout {
    my $self = shift;

    if (@{ $self->{stdout} }) {
        return 1;
    }

    return 0;
}

sub is_stderr { 
    my $self = shift;

    if (@{ $self->{stderr} }) {
        return 1;
    }

    return 0;
}

#
# private stuff
#

sub _run_win32 {
    my ($self, $args) = @_;
    my $command = $args->{command};
    my ($pid, $time, $timeout);

    if ($args->{arguments}) {
        $command .= " $args->{arguments}";
    }

    eval {
        local (*blx_in_r, *blx_in_w);
        local (*blx_out_r, *blx_out_w);
        local (*blx_err_r, *blx_err_w);

        my ($chld_in_r, $chld_in_w) = (\*blx_in_r, \*blx_in_w);
        my ($chld_out_r, $chld_out_w) = (\*blx_out_r, \*blx_out_w);
        my ($chld_err_r, $chld_err_w) = (\*blx_err_r, \*blx_err_w);

        socketpair($chld_in_r,  $chld_in_w,  AF_UNIX, SOCK_STREAM, PF_UNSPEC) or die $!;
        socketpair($chld_out_r, $chld_out_w, AF_UNIX, SOCK_STREAM, PF_UNSPEC) or die $!;
        socketpair($chld_err_r, $chld_err_w, AF_UNIX, SOCK_STREAM, PF_UNSPEC) or die $!;

        $self->log->debug("open $args->{command}");

        $timeout = $args->{timeout};
        $time = time + $args->{timeout};
        $pid = open3('>&blx_in_r', '<&blx_out_w', '<&blx_err_w', $command);
        close $chld_in_r;
        close $chld_out_w;
        close $chld_err_w;

        # Create the select for all handles
        $self->log->debug("create IO::Select object");
        my $sel = IO::Select->new($chld_out_r, $chld_err_r);

        while ($timeout > 0 && $sel->count) {
            foreach my $fh ($sel->can_read(1)) {
                next unless $fh;

                my $len = sysread($fh, my $buf, SYS_READ_LEN_WIN32);

                # For any reason the code doesn't work
                # and I don't know why :/
                #if (!defined $len) {
                #    next if $! =~ /^Interrupted/;
                #    warn "sysread error: $!";
                #}

                if ($len) {
                    if ($fh == $chld_out_r) {
                        $self->{stdout} .= $buf;
                    } elsif ($fh == $chld_err_r) {
                        $self->{stderr} .= $buf;
                    }
                } else {
                    $sel->remove($fh);
                }
            }

            $timeout = $time - time;
        }

        close $chld_in_w;
        close $chld_out_r;
        close $chld_err_r;
    };

    if ($@) {
        $self->log->trace(error => $@);
        $self->{unknown} = "an unexpected error occurs: $@";
    }

    if ($timeout < 1) {
        $self->{timeout} = "the command runs on a timeout after $args->{timeout} seconds";
    }

    if ($pid) {
        if ($timeout < 1) {
            kill $args->{kill_signal}, $pid;
        }
        waitpid($pid, 0);

        if ($? == -1) {
            $self->{exitcode} = 0;
        } else {
            $self->{exitcode} = $? >> 8;
        }
    }

    foreach my $std (qw/stdout stderr/) {
        if ($self->{$std}) {
            $self->{$std} = [ split /\n/, $self->{$std} ];
        } else {
            $self->{$std} = [ ];
        }
    }
}

sub _run {
    my ($self, $args) = @_;
    my $class    = ref($self);
    my $chld_in  = Symbol::gensym();
    my $chld_out = Symbol::gensym();
    my $chld_err = Symbol::gensym();
    my $command  = $args->{command};
    my $pid;

    if ($args->{arguments}) {
        $command .= " $args->{arguments}";
    }

    eval {
        $self->log->debug("open $command");
        $pid = open3($chld_in, $chld_out, $chld_err, $command);

        if ($args->{to_stdin}) {
            print $chld_in $args->{to_stdin}, "\n";
        }

        # we don't need stdin from child
        close $chld_in;

        # Create the selector for all handles
        $self->log->debug("create IO::Select object");
        my $sel = IO::Select->new($chld_out, $chld_err);

        # If something wents wrong, then alarm is still active.
        # We have to fallback in this case.
        local $SIG{__DIE__} = sub { alarm(0) };

        # Preparation of alarm() to make it possible to jump
        # out if the timeout is exceeded.
        local $SIG{ALRM} = sub {
            if ($args->{kill_signal}) {
                kill $args->{kill_signal}, $pid;
            }
            die "timeout";
        };

        $self->log->debug("set alarm to $args->{timeout}");
        alarm($args->{timeout});

        my $stdout_done = 0;
        my $stderr_done = 0;

        OUTER:
        while (my @ready = $sel->can_read) {
            foreach my $handle (@ready) {
                my $len = sysread($handle, my $buf, SYS_READ_LEN);

                if (!defined $len) {
                    next if $! =~ /^Interrupted/;
                    die "$class read error: $!";
                }

                if ($len) {
                    if ($handle == $chld_out) {
                        $self->{stdout} .= $buf;
                    } elsif ($handle == $chld_err) {
                        $self->{stderr} .= $buf;
                    }
                } elsif ($handle == $chld_out) {
                    $stdout_done = 1;
                } elsif ($handle == $chld_err) {
                    $stderr_done = 1;
                }

                if ($stdout_done && $stderr_done) {
                    last OUTER;
                }
            }
        }

        # fallback
        alarm(0);
    };

    # Save the error message
    my $error = $@;

    if ($error) {
        $self->log->warning($error);
    }

    # Wait for the process
    if ($pid) {
        waitpid $pid, 0;

        if ($? == -1) {
            $self->{exitcode} = 0;
        } else {
            $self->{exitcode} = $? >> 8;
        }
    }

    foreach my $std (qw/stdout stderr/) {
        if ($self->{$std}) {
            $self->{$std} = [ split /\n/, $self->{$std} ];
        } else {
            $self->{$std} = [ ];
        }
    }

    if ($error) {
        if ($error =~ /^timeout/) {
            $self->{timeout} = "command runs on a timeout after $args->{timeout} seconds";
        } else {
            $self->{unknown} = "an unexpected error occurs: $error";
        }
    }

    # closing stdout and stderr
    close $chld_out;
    close $chld_err;
}

sub _validate {
    my $class = shift;

    my %args = Params::Validate::validate(@_, {
        command => {
            type => Params::Validate::SCALAR,
        },
        arguments => {
            type => Params::Validate::SCALAR,
            optional => 1,
        },
        timeout => {
            default => 0,
            regex => qr/^\d+\z/,
        },
        kill_signal  => {
            type => Params::Validate::SCALAR,
            default => 0,
            regex => qr/^-{0,1}\d+\z/,
        },
        to_stdin => {
            type => Params::Validate::SCALAR,
            optional => 1,
        }
    });

    return \%args;
}

1;
