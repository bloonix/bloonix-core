package Bloonix::ProcManager;

use strict;
use warnings;
use Bloonix::IPC::SharedFile;
use JSON;
use Log::Handler;
use Params::Validate qw();
use POSIX qw(:sys_wait_h);
use Sys::Hostname qw();
use Time::HiRes qw();

use base qw(Bloonix::Accessor);
__PACKAGE__->mk_accessors(qw/children done hostname ipc json kill_procs log next_kill parent_pid reload request socket to_reap/);
__PACKAGE__->mk_counters(qw/ttlreq/);

our $VERSION = "0.1";

# Proc status
#  S  =  Starting up
#  _  =  Waiting for connection
#  R  =  Reading request
#  P  =  Processing request
#  W  =  Sending reply
#  N  =  No request received

sub new {
    my $class = shift;
    my $opts = $class->validate(@_);
    my $self = bless $opts, $class;

    $self->init;
    $self->ipc->locking(1);
    $self->daemonize;

    return $self;
}

sub init {
    my $self = shift;

    $self->parent_pid($$);
    $self->log(Log::Handler->get_logger("bloonix"));
    $self->ipc(Bloonix::IPC::SharedFile->new($self->{max_servers}, $self->{lockfile}));
    $self->done(0);
    $self->hostname(Sys::Hostname::hostname());
    $self->children({});
    $self->to_reap({});
    $self->kill_procs(0);
    $self->next_kill(time);
    $self->json(JSON->new->utf8);
}

sub daemonize {
    my $self = shift;
    my $reap = $self->to_reap;

    $self->set_parent_sigs;

    while ($self->done == 0) {
        # Reap timed out children.
        $self->reap_children;

        my ($idle, $running, $total, @idle) = $self->check_process_status;

        # Kill children if max_spare_servers was reached
        # and try only to kill children in idle state.
        $self->kill_children(@idle);

        if ($idle >= $self->{max_spare_servers}) {
            $self->kill_procs(1);
        } elsif ($idle < $self->{min_spare_servers}) {
            $self->kill_procs(0);

            if ($total < $self->{max_servers}) {
                my $to_spawn;

                if ($self->{start_servers}) {
                    $to_spawn = $self->{start_servers};
                    $self->{start_servers} = 0;
                    $self->log->info("spawn $to_spawn processes at program start");
                } else {
                    $to_spawn = $self->{min_spare_servers} - $idle;
                    $self->log->info("min_spare_servers reached - spawn $to_spawn processes");
                }

                if ($to_spawn && $self->spawn_process($to_spawn)) {
                    # the child returns a pid
                    return;
                }
            } else {
                $self->log->warning("max_servers of $self->{max_servers} reached");
            }
        }

        $self->log->debug("$idle processed idle, $running processes running");
        Time::HiRes::usleep(50_000);
    }

    $self->stop_server;
    $self->ipc->destroy;
    exit 0;
}

sub spawn_process {
    my ($self, $to_spawn) = @_;

    for (1 .. $to_spawn) {
        my $slot = $self->ipc->get_free_slot;

        if (!defined $slot) {
            $self->log->warning("no free slots available");
            return 0;
        }

        my $pid = fork;

        if ($pid) {
            $self->log->info("spawn server process $pid - slot $slot");
            $self->log->info("ipc left slots:", $self->ipc->freeslots);
            $self->ipc->init_free_slot($slot => $pid);
            $self->children->{$pid} = $pid;
        } elsif (!defined $pid) {
            die "unable to fork() - $!";
        } else {
            $self->set_child_sigs;
            $self->ipc->locking(0);
            $self->ipc->wait_for_slot($slot => $$);
            return $$;
        }
    }

    return 0;
}

sub set_parent_sigs {
    my $self = shift;

    $SIG{CHLD} = sub { $self->sig_chld_handler(@_) };

    $SIG{HUP} = sub {
        $self->done(1);
        $self->reload(1);
    };

    foreach my $sig (qw/INT TERM PIPE/) {
        $SIG{$sig} = sub {
            $self->log->notice("signal $sig received");
            $self->done(1);
        };
    }

    foreach my $sig (qw/USR1 USR2/) {
        $SIG{$sig} = sub {
            my @chld = keys %{$self->{children}};
            $self->log->notice("signal $sig received");
            $self->log->notice("sending $sig to", @chld);
            kill $sig, @chld;
        };
    }
}

sub set_child_sigs {
    my $self = shift;

    $SIG{CHLD} = "DEFAULT";

    foreach my $sig (qw/HUP INT TERM PIPE/) {
        $SIG{$sig} = sub {
            $self->log->notice("signal $sig received");
            $self->done(1);
        };
    }

    foreach my $sig (qw/USR1 USR2/) {
        $SIG{$sig} = sub {
            $self->log->notice("signal $sig received - ignoring");
        };
    }
}

sub check_process_status {
    my $self = shift;

    # Process status counter
    my ($idle, $running, $total) = (0, 0, 0);

    # Each idle process is stored, because if there are too much
    # processes running, then sig-term is send only to processes
    # that are currently in idle state. Yes, there is a race condition,
    # but it's better to try to kill only processes in idle state as
    # to try any process. @idle is passed to kill_child.
    my @idle;

    # Count the status of all processes.
    my %status = qw(S 0 _ 0 R 0 W 0 P 0 N 0);
    my %pidstatus;

    foreach my $pid (keys %{$self->children}) {
        my $process = $self->ipc->get($pid)
            or next;

        $status{$process->{status}}++;
        $pidstatus{$pid} = $process->{status};

        if ($process->{status} =~ /[RPW]/) {
            if ($process->{time} + $self->{timeout} <= time) {
                $self->log->warning("process $pid runs on a timeout - kill hard");
                kill 9, $pid;
                next;
            }
            $running++;
        } else {
            push @idle, $pid;
            $idle++;
        }

        $total++;
    }

    # Log a total process status.
    $self->log->debug(join(", ", map { "$_:$pidstatus{$_}" } sort keys %pidstatus));
    $self->log->debug("S[$status{S}] _[$status{_}] R[$status{R}] P[$status{P}] W[$status{W}] N[$status{N}]");

    return ($idle, $running, $total, @idle);
}

sub kill_children {
    my ($self, @idle) = @_;
    my $reap = $self->to_reap;

    # Nothing to do.
    if (!$self->kill_procs) {
        return;
    }

    # There are no idle processes or the count of
    # idle processes is already equal the minimum
    # count of spare servers.
    if (!@idle || @idle <= $self->{min_spare_servers}) {
        $self->kill_procs(0);
        return;
    }

    # Killing cpu friendly.
    if ($self->next_kill > time) {
        return;
    }

    $self->log->info(
        "max spare servers were reached - kill 1 process,",
        @idle - $self->{min_spare_servers}, "left"
    );

    foreach my $pid (@idle) {
        if (!exists $reap->{$pid}) {
            # Kill only one child per second.
            $self->next_kill(time + 1);
            # A timeout is stored. If the process doesn't died
            # within the timeout, the process will be killed hard
            # in reap_children.
            $reap->{$pid} = time + $self->{timeout};
            kill 15, $pid;
            # We killing only one process at one time.
            last;
        }
    }
}

sub reap_children {
    my $self = shift;
    my $reap = $self->to_reap;

    foreach my $pid (keys %$reap) {
        if ($reap->{$pid} <= time) {
            $self->log->notice("process $pid runs on a reap timeout - kill hard");
            kill 9, $pid;
        }
    }
}

sub stop_server {
    my $self = shift;
    my @chld = keys %{$self->children};
    my $wait = 15;

    if (!@chld) {
        return;
    }

    # Kill soft
    kill 15, @chld;

    while ($wait-- && @chld) {
        sleep 1;
        @chld = keys %{$self->children};
    }

    if (@chld) {
        # Kill hard
        kill 9, @chld;
    }
}

sub sig_chld_handler {
    my $self = shift;
    my $children = $self->children;
    my $reap = $self->to_reap;

    while ((my $child = waitpid(-1, WNOHANG)) > 0) {
        if ($? > 0 && $? != 13) {
            $self->log->error("child $child died: $?");
        } else {
            $self->log->notice("child $child died: $?");
        }

        $self->ipc->remove($child);
        $self->log->info("ipc free slots:", $self->ipc->freeslots);
        delete $children->{$child};
        delete $reap->{$child};
    }

    $SIG{CHLD} = sub { $self->sig_chld_handler(@_) };
}

sub set_status {
    my $self = shift;

    $self->ipc->set($$, time => time, @_);
}

sub set_status_waiting {
    my $self = shift;

    if ($self->{auto_check_process_size}) {
        $self->check_process_size;
    }

    $self->set_status(status => "_", @_);
}

sub set_status_reading {
    my $self = shift;

    $self->set_status(status => "R");
}

sub set_status_processing {
    my $self = shift;

    $self->set_status(status => "P", ttlreq => $self->ttlreq(1), @_);
}

sub set_status_sending {
    my $self = shift;

    $self->set_status(status => "W", @_);
}

sub set_status_none {
    my $self = shift;

    $self->set_status(status => "N", @_);
}

sub proc_status {
    my $self = shift;

    return $self->ipc->proc_status;
}

sub statm {
    my ($self, $pid) = @_;

    if (!$self->{statm} || $pid) {
        $pid //= $$;

        my $file = "/proc/$pid/statm";
        my %stat = ();

        open my $fh, '<', $file or return undef;
        my @line = split /\s+/, <$fh>;
        close($fh);

        @{$self->{statm}}{qw(size resident share trs lrs drs dtp)} = map { $_ * 4096 } @line;
    }

    return $self->{statm};
}

sub check_process_size {
    my $self = shift;

    # Reset memory statistics
    $self->{statm} = undef;

    if ($self->{max_requests} && $self->ttlreq > $self->{max_requests}) {
        $self->log->warning("$$ reached max_requests of $self->{max_requests} - good bye");
        exit 0;
    }

    if ($self->{max_process_size} && $self->statm && $self->statm->{resident} > $self->{max_process_size}) {
        $self->log->warning(
            "$$ reached max_process_size of",
            $self->{max_process_size_readable},
            sprintf("(%.1fMB)", $self->statm->{resident} / 1048576),
            "- good bye"
        );
        exit 0;
    }
}

sub generate_server_statistics {
    my $self = shift;
    my $procs = $self->ipc->proc_status;

    my $stats = {
        procs => [], ttlreq => 0,
        F => 0, S => 0, _ => 0, R => 0,
        P => 0, W => 0, N => 0,
    };

    foreach my $proc (@$procs) {
        my $status = $proc->{status} || "F";
        $stats->{ttlreq} += $proc->{ttlreq} || 0;
        $stats->{$status}++;

        if ($proc->{pid}) {
            push @{$stats->{procs}}, $proc;
        }
    }

    return $stats;
}

sub get_plain_server_status {
    my $self = shift;
    my $stats = $self->generate_server_statistics;
    my $format = "%6s  %6s  %15s  %19s  %39s  %s\n";
    my @content;

    push @content, (
        "Content-Type: text/plain\n\n",

        "Hostname: ". $self->hostname ."\n\n",

        "* Column description\n\n",
        "    PID     - The process id.\n",
        "    STATUS  - The current status of the process.\n",
        "    TTLREQ  - The total number of processed requests.\n",
        "    TIME    - The time when the last request was processed.\n",
        "    CLIENT  - The IP address of the client that is/were processed.\n",
        "    REQUEST - The request of the client that is/were processed.\n\n",

        "* Status description\n\n",
        "    S - Starting up\n",
        "    _ - Waiting for connection\n",
        "    R - Reading request\n",
        "    P - Processing request\n",
        "    W - Sending reply\n",
        "    N - No request received\n\n",
        "    If the status is in RWN then the columns TIME, CLIENT and REQUEST\n",
        "    shows information about the last request the process processed.\n\n",

        "* Statistics\n\n",
        "    Server time: ", $self->timestamp(time), "\n\n",
        #"    Total requests procesesed: $stats->{ttlreq}\n\n",

        sprintf("%8s worker starting up\n", $stats->{S}),
        sprintf("%8s worker waiting for incoming request\n", $stats->{_}),
        sprintf("%8s worker reading request\n", $stats->{R}),
        sprintf("%8s worker procesing request\n", $stats->{P}),
        sprintf("%8s worker sending data\n", $stats->{W}),
        sprintf("%8s worker in status n/a\n", $stats->{N}),
        sprintf("%8s free slots available\n\n", $stats->{F}),

        "* Process list\n\n",
        sprintf($format, qw(PID STATUS TTLREQ TIME CLIENT REQUEST))
    );

    foreach my $proc (@{$stats->{procs}}) {
        push @content, sprintf($format,
            $proc->{pid},
            $proc->{status},
            $proc->{ttlreq},
            $self->timestamp($proc->{time}),
            $proc->{client},
            $proc->{request}
        );
    }

    return join("", @content);
}

sub get_json_server_status {
    my ($self, %opts) = @_;

    my $json = $opts{pretty}
        ? JSON->new->pretty(1)
        : JSON->new->pretty(0);

    return $json->encode({ status => "ok", hostname => $self->hostname, data => $self->ipc->proc_status });
}

sub get_raw_server_status {
    my ($self, %opts) = @_;

    return $self->ipc->proc_status;
}

sub timestamp {
    my $self = shift;
    my $time = shift || time;
    my @time = (localtime($time))[reverse 0..5];
    $time[0] += 1900;
    $time[1] += 1;
    return sprintf "%04d-%02d-%02d %02d:%02d:%02d", @time[0..5];
}

sub validate {
    my $class = shift;

    my %options = Params::Validate::validate(@_, {
        min_spare_servers => {
            type  => Params::Validate::SCALAR,
            regex => qr/^\d+\z/,
            default => 10
        },
        max_spare_servers => {
            type  => Params::Validate::SCALAR,
            regex => qr/^\d+\z/,
            default => 20
        },
        max_servers => {
            type  => Params::Validate::SCALAR,
            regex => qr/^\d+\z/,
            default => 50
        },
        max_requests => {
            type  => Params::Validate::SCALAR,
            regex => qr/^\d+\z/,
            default => 0
        },
        max_process_size => {
            type => Params::Validate::SCALAR,
            regex => qr/^(\d+\s*(M|G)B{0,1}|0)\z/i,
            default => "1GB"
        },
        start_servers => {
            type  => Params::Validate::SCALAR,
            regex => qr/^\d+\z/,
            default => 0
        },
        auto_check_process_size => {
            type => Params::Validate::SCALAR,
            regex => qr/^(0|1|no|yes)\z/,
            default => "yes"
        },
        timeout => {
            type  => Params::Validate::SCALAR,
            regex => qr/^\d+\z/,
            default => 300
        },
        lockfile => {
            type => Params::Validate::SCALAR,
            default => "/var/lib/bloonix/ipc/%P.lock"
        }
    });

    if ($options{start_servers} > $options{max_servers}) {
        die "ERR: start_servers cannot be higher than max_servers";
    }

    if ($options{auto_check_process_size} eq "no") {
        $options{auto_check_process_size} = 0;
    }

    if ($options{max_process_size}) {
        $options{max_process_size_readable} = $options{max_process_size};
        $options{max_process_size_readable} =~ s/\s//g;
        my ($size, $unit) = ($options{max_process_size_readable} =~ /^(\d+)(M|G)B{0,1}\z/i);
        $unit = uc $unit;
        $options{max_process_size} = $unit eq "M" ? $size * 1048576 : $size * 1073741824;
    }

    return \%options;
}

sub DESTROY {
    my $self = shift;

    if ($$ == $self->{parent_pid}) {
        if ($self->{socket}) {
            my $socket = $self->{socket};
            close $socket;
        }
    }
}

1;

=head1 NAME

Bloonix::ProcManager - A forking process manager.

=head1 SYNOPSIS

Totaly simple!

    use IO::Socket::INET;
    use Bloonix::ProcManager;

    my $sock = IO::Socket::INET->new(
        LocalAddr => "127.0.0.1",
        LocalPort => 9000
        Listen => 10
        Reuse => 1,
        Proto => "tcp"
    );

    my $proc = Bloonix::ProcManager->new(
        min_spare_servers => 10,
        max_spare_servers => 20,
        max_servers => 30,
        max_process_size => "100m"
    ); # the forking machine starts immediate!

    # The children arives here

    # USR1, USR2 kills all processes hard
    # HUP, INT, TERM, PIPE sets done() to 1
    # HUP sets realod() to 1 - set it back to 0 yourself after realing your daemon!
    while ( !$proc->done ) {
        # The child is waiting for an incoming request
        $prot->set_status_waiting;
        my $client = $sock->accept;

        # The child is reading the request
        $proc->set_status_reading;
        my $request = <$client>;

        # The child is processing the request
        $proc->set_status_processing(
            client => $client->remote,
            request => "clients says hello"
        );

        # --------------------
        # do something here...
        # --------------------

        # The child is sending data
        $proc->set_status_sending;
        print $sock "Hello Client\n";
    }

It's really important that you set the state of your processes!
Use the following methods in any case:

    $prot->set_status_waiting;
    $proc->set_status_processing;

The following methods are nice to have:

    $proc->set_status_reading;
    $proc->set_status_sending;

And please check if you have to exit! Example:

    if ($proc->done) {
        exit;
    }

=head1 DESCRIPTION

=head1 METHODS

=head1 EXPORTS

No exports.

=head1 REPORT BUGS

Please report all bugs to <support(at)bloonix.de>.

=head1 AUTHOR

Jonny Schulz <support(at)bloonix.de>.

=head1 COPYRIGHT

Copyright (C) 2009 by Jonny Schulz. All rights reserved.

=cut
