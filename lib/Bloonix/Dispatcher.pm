=head1 EXAMPLE

    use strict;
    use warnings;
    use Bloonix::Dispatcher;
    use Data::Dumper;

    my @job = qw(beer chips fish cola saltsticks);
    my @cache = @job;
    my @finish = ();

    my $dispatcher = Bloonix::Dispatcher->new(
        worker => 1,
        sock_file => "/tmp/bloonix-location-agent.sock"
    );

    $dispatcher->on(ready => sub {
        print "ready called\n";
        return shift @cache;
    });

    $dispatcher->on(process => sub {
        print "process object $_[0]\n";

        if ($_[0] eq "beer") {
            $dispatcher->send_done("successful");
        } elsif ($_[0] eq "cola") {
            $dispatcher->send_err("failed");
        } else {
            # send no message
        }
    });

    $dispatcher->on(finish => sub {
        print "finish called\n";

        while (@_) {
            my ($status, $object, $message) = (shift, shift, shift);
            print "<$status> : <$object> : <$message>\n";
            push @finish, { status => $status, object => $object, message => $message };
        }
    });

    $dispatcher->on(quit => sub {
        print "quit called\n";
        return @job == @finish ? 1 : 0;
    });

    $dispatcher->run;

    print Dumper(\@job);
    print Dumper(\@cache);
    print Dumper(\@finish);

=cut

package Bloonix::Dispatcher;

use strict;
use warnings;
use IO::Socket;
use IO::Select;
use POSIX qw(:sys_wait_h);
use JSON;
use Time::HiRes;
use Log::Handler;

# Some quick accessors.
use base qw(Bloonix::Accessor);
__PACKAGE__->mk_accessors(qw/on_reload on_finish on_ready on_process on_init on_quit sent_done/);
__PACKAGE__->mk_accessors(qw/select socket done reload log json is_win32 pid_file sock_file/);
__PACKAGE__->mk_accessors(qw/children children_alive_status reaped ready_children/);
__PACKAGE__->mk_accessors(qw/ready_objects objects_in_progress finished_objects/);

sub new {
    my $class = shift;
    my $opts = $class->validate(@_);
    my $self = bless $opts, $class;
    $self->init_dispatcher;
    return $self;
}

sub run {
    my $self = shift;
    $self->log->notice("start dispatcher");
    $self->run_dispatcher;
    $self->quit_dispatcher;
    $self->log->notice("dispatcher stopped");
}

sub on {
    my ($self, $alias, $callback) = @_;

    if ($alias !~ /^(reload|finish|ready|process|init|quit)\z/) {
        die "invalid on() value '$alias'";
    }

    $self->{"on_$alias"} = $callback;
}

sub init_dispatcher {
    my $self = shift;

    # Init the base system after we are running with the right user and group
    $self->log(Log::Handler->get_logger("bloonix"));
    $self->json(JSON->new);

    $self->log->notice("initialized dispatcher");

    # Create the pid file.
    $self->create_pid_file;

    # This is necessary because pwd returns an
    # error if the dispatcher was started from a directory
    # that will be deleted later.
    chdir("/");

    # Init the unix socket for the parent <-> client communication.
    $self->init_socket;

    # Store all children with their pid and the children.
    $self->children({});

    # Store the children that needs to be reaped.
    $self->reaped({});

    # Store the alive timestamp of each child.
    $self->children_alive_status({});

    # Safe the pid of the children that are ready to process.
    $self->ready_children([]);

    # Safe the objects that are ready to process.
    $self->ready_objects([]);

    # Safe temporary finished objects to flush them via on_finish
    $self->finished_objects([]);

    # Safe objects by pid that are in progress.
    $self->objects_in_progress({});

    # A flag that is set to 1 if the dispatcher receives signal term.
    $self->done(0);

    # A flag that is set to 1 if the dispatcher receives signal term.
    $self->reload(0);

    # Does the dispatcher runs on win32?
    $self->is_win32($^O =~ /Win32/i ? 1 : 0);

    # Handle signal chld
    $self->{CHLD} = $SIG{CHLD} = sub {
        $self->sig_child_handler(@_);
    };

    # Signal hup is used to reload the dispatcher
    $SIG{HUP} = sub {
        $self->log->notice("signal HUP received - reloading");
        $self->reload(1);
    };

    # Signal int will be ignored
    $SIG{INT} = sub {
        $self->log->notice("signal INT received - ignoring");
    };

    # Signal pipe will be ignored
    $SIG{PIPE} = sub {
        $self->log->notice("signal PIPE received - ignoring");
    };

    # Signal term is used to stop the dispatcher
    $SIG{TERM} = sub {
        $self->log->notice("signal TERM received");
        $self->done(1);
    };
}

sub init_socket {
    my $self = shift;

    $self->log->notice("initialize socket", $self->sock_file);

    require IO::Socket::UNIX;

    if (-e $self->sock_file) {
        unlink $self->sock_file
            or $self->log->die(error => "unable to delete sock_file", $self->sock_file, "-", $!);
    }

    my $socket = IO::Socket::UNIX->new(
        Local  => $self->sock_file,
        Type   => SOCK_STREAM,
        Listen => SOMAXCONN,
        ReuseAddr => 1
    );

    $self->socket($socket);
    $self->socket->blocking(0);
    $self->select(IO::Select->new);
    $self->select->add($socket);
}

sub quit_dispatcher {
    my $self = shift;
    $self->kill_children;
    $self->remove_sock_file;
    #$self->remove_pid_file;
}

sub run_dispatcher {
    my $self = shift;

    # Benchmark diff:
    #   while(...) { eval{ } }  -> 100% slower
    #   eval { while(...) }     -> 100% faster
    while ($self->done == 0) {
        eval {
            while ($self->done == 0) {
                $self->manage_children;
                $self->reap_children;
                $self->manage_requests;
                $self->manage_objects;
            }
        };

        if ($@) {
            $self->log->trace(error => $@);
            if ($self->done == 0) {
                sleep 1;
            }
        }
    }
}

sub manage_requests {
    my $self = shift;

    # Just wait a second for children that are finished.
    $self->log->debug("waiting for children pipes");

    while (my @ready_sockets = $self->select->can_read(0)) {
        $self->log->debug(
            "reading children info from",
            scalar @ready_sockets, "sockets"
        );

        foreach my $socket (@ready_sockets) {
            next unless $socket;

            $self->log->debug("waiting for accept");

            my $client = $socket->accept
                or next;

            $self->log->debug("reading from client");
            my $line = <$client>;

            if ($line =~ /^(\d+):(.+)$/) {
                my ($pid, $status) = ($1, $2);
            
                $self->log->debug("child $pid status $status");

                if ($status eq "ready") {
                    push @{$self->ready_children}, {
                        pid => $pid,
                        client => $client
                    };
                } elsif ($status eq "alive") {
                    $self->children_alive_status->{$pid} = time;
                } elsif ($status =~ /^done:(.*)\z/) {
                    my $message = $self->postpare_message($1);
                    my $object = delete $self->objects_in_progress->{$pid};
                    if ($object) { # reaped?
                        push @{$self->finished_objects}, ok => $object => $message;
                    }
                } elsif ($status =~ /^err:(.*)\z/) {
                    my $message = $self->postpare_message($1);
                    my $object = delete $self->objects_in_progress->{$pid};
                    if ($object) { # reaped?
                        push @{$self->finished_objects}, err => $object => $message;
                    }
                } else {
                    $self->log->error("invalid status received from client");
                    $self->log->dump(error => $line);
                }
            } else {
                $self->log->error("recv invalid request: $line");
            }
        }
    }
}

sub manage_objects {
    my $self = shift;

    if ($self->reload) {
        $self->reload(0);
        if ($self->on_reload) {
            my @ready = $self->on_reload->(@{$self->ready_objects});
            if (@ready && defined $ready[0] && ref $ready[0]) {
                @{$self->ready_objects} = @ready;
            }
        }
    }

    if (@{$self->finished_objects}) {
        my @finished = @{$self->finished_objects};
        $self->log->info("flushing", scalar @finished, "finished objects");
        @{$self->finished_objects} = ();
        if ($self->on_finish) {
            $self->on_finish->(@finished);
        }
    }

    if (!@{$self->ready_objects} || !@{$self->ready_children}) {
        Time::HiRes::usleep(200_000);
    }

    if (!@{$self->ready_objects} && $self->on_ready) {
        my @ready = $self->on_ready->();
        if (@ready && defined $ready[0]) {
            push @{$self->ready_objects}, @ready;
        }
    }

    if (@{$self->ready_objects} && @{$self->ready_children}) {
        my $count_children = scalar keys %{$self->children};
        my $ready_children = scalar @{$self->ready_children};
        $self->log->info(
            scalar @{$self->ready_objects}, "objects ready,",
            "$ready_children/$count_children children ready"
        );
    }

    while (@{$self->ready_objects} && @{$self->ready_children}) {
        my $child = shift @{$self->ready_children};
        my $pid = $child->{pid};
        my $client = $child->{client};

        if (!exists $self->children->{$pid}) {
            $self->log->warning(
                "child $pid does not exists any more,",
                "jump to the next child"
            );
            next;
        }

        my $object = shift @{$self->ready_objects};
        $self->log->info("send object to child $pid");

        # The pid of the child is stored, so we know which
        # child is processing the host.
        $self->objects_in_progress->{$pid} = $object;

        # Print the object configuration to the worker.
        print $client $self->json->encode({ job => $object }), "\n";
        close $client;
        $self->log->info("object send sent to child $pid");
    }

    if ($self->on_quit) {
        if ($self->on_quit->()) {
            $self->log->info("quit returns true");
            $self->done(1);
        }
    }
}

sub manage_children {
    my $self = shift;

    my $children = scalar keys %{ $self->children };

    if ($self->{worker} > $children) {
        $self->start_worker($self->{worker} - $children);
    } elsif ($self->{worker} < $children) {
        $self->stop_worker($children - $self->{worker});
    }

    foreach my $pid (keys %{$self->children_alive_status}) {
        if ($self->children->{$pid}) {
            my $time = time - $self->children_alive_status->{$pid};
            if ($time > $self->{alive_timeout}) {
                $self->log->alert("kill child $pid because the last alive status is ${time}s ago");
                $self->log->alert("child $pid is currently checking the following objects:");
                $self->log->dump(alert => $self->objects_in_progress->{$pid});
                kill 9, $pid;
            }
        } else {
            delete $self->children_alive_status->{$pid};
        }
    }
}

sub reap_children {
    my $self = shift;

    foreach my $pid (keys %{$self->reaped}) {
        delete $self->reaped->{$pid};

        # Delete the pid of reaped children.
        $self->log->info("reaping child $pid");

        if ($self->objects_in_progress->{$pid}) {
            my $object = delete $self->objects_in_progress->{$pid};
            push @{$self->finished_objects}, err => $object => undef;
        }
    }
}

sub start_worker {
    my ($self, $num) = @_;

    for (1..$num) {
        my $pid = fork;

        if ($pid) {
            # A new child is born - horay :-)
            $self->log->notice("child $pid forked");
            $self->children->{$pid}->{pid} = $pid;
        } elsif (!defined $pid) {
            # Maybe ulimit reached or there is not enough memory.
            die "unable to fork - $!";
        } else {
            # The child must be run in an eval-block because it
            # should never break out of start_worker.
            eval { $self->run_child };
            # Exit immediate
            exit($@ ? 9 : 0);
        }
    }
}

sub stop_worker {
    my ($self, $num) = @_;
    my @tokill = ();

    # Only each 10 seconds it's possible to kill worker
    # because it's necessary to reap the children from
    # the last kill.
    if ($self->{lastkill} && $self->{lastkill} + 10 > time) {
        return;
    }

    $self->{lastkill} = time;
    $self->log->notice("too much worker running, stopping $num worker");

    # Only kill processes that are not working.
    if (@{$self->ready_children}) {
        while (my $pid = shift @{$self->ready_children}) {
            push @tokill, $pid;
            $num--;
            last if $num == 0;
        }
        $self->log->notice("kill 9", @tokill);
        kill 9, @tokill;
    }
}

sub run_child {
    my $self = shift;
    $self->set_child_signals;

    if ($self->on_init) {
        $self->on_init->();
    }

    my ($socket, $select);
    my $connect = 1;

    while ($self->done == 0) {
        if ($connect == 1) {
            $socket = $self->send_ready;
            $select = IO::Select->new($socket);
            $connect = 0;
        }

        $self->log->info("waiting to get a job");
        my @sockets = $select->can_read(90);
        $self->send_alive;

        while (@sockets && $self->done == 0) {
            my $sock = shift @sockets;

            if (!$sock) {
                $self->log->info("empty socket, try next");
                next;
            }

            $self->log->info("reading job");
            my $line = <$sock>;
            close $sock;

            $self->log->info("got a job");
            $self->sent_done(0);

            if ($self->on_process) {
                my $r = $self->json->decode($line);
                $self->on_process->($r->{job});
            }

            if ($self->sent_done == 0) {
                $self->send_done;
            }

            $self->log->info("job finished");
            $connect = 1;
        }
    }
}

sub set_child_signals {
    my $self = shift;

    # Handle signal chld
    $SIG{CHLD} = "DEFAULT";

    # Signal hup is used to reload the dispatcher
    $SIG{HUP} = sub {
        $self->log->notice("signal HUP received");
        $self->done(1);
    };

    # Signal int will be ignored
    $SIG{INT} = sub {
        $self->log->notice("signal INT received - ignoring");
    };

    # Signal term is used to stop the dispatcher
    $SIG{TERM} = sub {
        $self->log->notice("signal TERM received");
        exit 0;
    };
}

sub set_worker {
    my ($self, $num) = @_;

    $self->{worker} = $num;    
}

sub kill_children {
    my $self = shift;

    # Don't TERM the dispatcher. At first we reap all children.
    local $SIG{TERM} = "IGNORE";

    $self->kill_and_wait(1, 5);
    $self->kill_and_wait(15, 5);
    $self->kill_and_wait(9, 5);
}

sub kill_and_wait {
    my ($self, $signal, $timeout) = @_;

    my @chld = keys %{$self->children}
        or return;

    $self->log->notice("send signal $signal to children", @chld);
    kill $signal, @chld;

    my $until = time + $timeout;

    while (scalar keys %{$self->children} && time < $until) {
        sleep 1;
    }
}

sub sig_child_handler {
    my $self = shift;

    while ((my $pid = waitpid(-1, WNOHANG)) > 0) {
        if ($? > 0) {
            $self->log->error("child $pid died: $?");
        } else {
            $self->log->notice("child $pid died: $?");
        }

        # Close the child pipes and delete the pid.
        delete $self->children->{$pid};
        $self->reaped->{$pid} = $pid;
    }

    $SIG{CHLD} = $self->{CHLD};
}

sub create_pid_file {
    my $self = shift;

    if (!$self->pid_file) {
        return;
    }

    open my $fh, ">", $self->pid_file
        or $self->log->die(error => "unable to open run file", $self->pid_file, "-", $!);

    print $fh $$
        or $self->log->die(error => "unable to write to run file", $self->pid_file, "-", $!);

    close $fh;
}

sub remove_sock_file {
    my $self = shift;

    unlink $self->sock_file;
}

sub remove_pid_file {
    my $self = shift;

    if ($self->pid_file && open my $fh, "<", $self->pid_file) {
        my $pid = <$fh>;
        chomp $pid;
        close $fh;

        if ($pid == $$) {
            unlink $self->pid_file;
        }
    }
}

sub validate {
    my $class = shift;

    my %args = Params::Validate::validate(@_, {
        worker => {
            type => Params::Validate::SCALAR,
            regex => qr/^[1-9]\d*\z/,
            default => 1
        },
        pid_file => {
            type => Params::Validate::SCALAR,
            optional => 1
        },
        sock_file => {
            type => Params::Validate::SCALAR,
        },
        alive_timeout => {
            type => Params::Validate::SCALAR,
            regex => qr/^[1-9]\d*\z/,
            # Example: 30 locations * 15s = 450s
            # 150s as time buffer
            default => 600
        }
    });

    my $time = time;
    $args{sock_file} .= ".$time.$$";

    return \%args;
}

sub connect_to_parent {
    my $self = shift;

    my $socket = IO::Socket::UNIX->new(
        Type => SOCK_STREAM,
        Peer => $self->sock_file
    ) or $self->log->die(error => "unable to connect to socket", $self->sock_file, "-", $!);

    return $socket;
}

sub prepare_message {
    my ($self, $message) = @_;

    if (!defined $message) {
        $message = "";
    }

    if (ref $message) {
        $message = "1:". $self->json->encode($message);
    } else {
        $message = "0:$message";
    }

    return $message;
}

sub postpare_message {
    my ($self, $message) = @_;
    my ($json, $object) = split /:/, $message, 2;

    $message = $json # 0 : 1
        ? $self->json->decode($object)
        : $object;

    return $message;
}

sub send_ready {
    my $self = shift;
    $self->send_status("ready");
}

sub send_done {
    my $self = shift;
    my $message = $self->prepare_message(@_);
    $self->sent_done(1);
    $self->send_status("done:$message");
}

sub send_err {
    my $self = shift;
    my $message = $self->prepare_message(@_);
    $self->sent_done(1);
    $self->send_status("err:$message");
}

sub send_alive {
    my $self = shift;
    $self->send_status("alive");
}

sub send_status {
    my ($self, $status) = @_;

    if (!$self->is_win32) {
        my $socket = $self->connect_to_parent;
        $self->log->info("child $$ status: $status");
        print $socket "$$:$status\n";

        if ($status eq "ready") {
            return $socket;
        }

        close $socket;
    }
}

1;
