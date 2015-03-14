package Bloonix::IPC::SharedFile;

use strict;
use warnings;
use Fcntl qw( O_CREAT O_RDWR :flock );

use constant PARENT_PID => $$;
use constant RECVBUF => 16384;

sub new {
    my ($class, $slots, $lockfile) = @_;
    my $self = bless { }, $class;

    $self->{free_slots} = [ 0 .. $slots - 1 ];
    $self->{used_slots} = { };
    $self->{slot_size}  = 1024;
    $self->{slot_count} = $slots;

    if ($lockfile) {
        my $pid_and_time = PARENT_PID .".". time;
        $lockfile =~ s/%P/$pid_and_time/g;
    } else {
        $lockfile ||= join(".", "/var/run/blxipc", PARENT_PID, time, "lock");
    }

    if (-e $lockfile) {
        unlink($lockfile)
            or die "unable to remove lock file '$lockfile' - $!";
    }

    $self->{lockfile} = $lockfile;
    my $fh = $self->_open_lockfile;
    print $fh "\0" x ($slots * $self->{slot_size});

    $self->{keys} = {
        # key - offset - size
        pid     => [   0,   5 ],
        status  => [   5,   1 ],
        time    => [   6,  10 ],
        ttlreq  => [  16,  20 ],
        client  => [  36,  39 ],
        request => [  75, 949 ],
    };

    return $self;
}

sub locking {
    my ($self, $bool) = @_;

    if (defined $bool) {
        $self->{locking} = $bool;
    }

    return $self->{locking};
}

sub get_free_slot {
    my $self = shift;
    my $slot = shift @{$self->{free_slots}};
    return $slot;
}

sub init_free_slot {
    my ($self, $slot, $pid, %pairs) = @_;
    $self->{used_slots}->{$pid} = $slot;

    $pairs{pid} //= $pid;
    $pairs{status} //= "S";
    $pairs{time} //= time;
    $pairs{ttlreq} //= 0;
    $pairs{client} //= "0.0.0.0";
    $pairs{request} //= "initializing";

    $self->set($pid, %pairs);
}

sub wait_for_slot {
    my ($self, $slot, $pid) = @_;
    $self->{used_slots}->{$pid} = $slot;

    while ( 1 ) {
        my $p = $self->get($pid);

        if ($p->{pid} eq $pid) {
            last;
        }

        sleep 1;
    }
}

sub freeslots {
    my $self = shift;

    return scalar @{$self->{free_slots}};
}

sub remove {
    my ($self, $pid) = @_;
    my $slot = delete $self->{used_slots}->{$pid};
    my $length = $self->{slot_size};
    my $offset = ($slot * $length);
    my $value = "\0" x $length;

    $self->_lock;
    $self->_write($value, $offset, $length);
    $self->_unlock;

    push @{$self->{free_slots}}, $slot;
}

sub set {
    my ($self, $pid, %pairs) = @_;
    my $keys = $self->{keys};
    my $slot = $self->{used_slots}->{$pid};

    $self->_lock;

    foreach my $key (keys %pairs) {
        die unless exists $keys->{$key};
        my ($offset, $length) = @{$keys->{$key}};
        $offset += ($slot * $self->{slot_size});
        $self->_write($pairs{$key}, $offset, $length);
    }

    $self->_unlock;
}

sub get {
    my ($self, $pid) = @_;
    my $used = $self->{used_slots};
    my $keys = $self->{keys};
    my $slot = $used->{$pid};
    my %pairs;

    if (!defined $slot) {
        return undef;
    }

    $self->_lock;

    foreach my $key (keys %$keys) {
        my ($offset, $length) = @{$keys->{$key}};
        $offset += ($slot * $self->{slot_size});
        $pairs{$key} = $self->_read($offset, $length);
    }

    $self->_unlock;
    return \%pairs;
}

sub proc_status {
    my $self = shift;
    my $keys = $self->{keys};
    my $fh = $self->{fh};
    my @proc_list;

    flock($fh, LOCK_EX);

    foreach my $slot (0..$self->{slot_count} - 1) {
        push @proc_list, \my %proc;
        foreach my $key (keys %$keys) {
            my ($offset, $length) = @{$keys->{$key}};
            $offset += ($slot * $self->{slot_size});
            $proc{$key} = $self->_read($offset, $length);
        }
    }

    flock($fh, LOCK_UN);
    return \@proc_list;
}

sub _open_lockfile {
    my $self = shift;
    my $lockfile = $self->{lockfile};

    if ($self->{curpid} && $self->{curpid} == $$) {
        return $self->{fh};
    }

    sysopen my $fh, $lockfile, O_CREAT | O_RDWR
        or die "unable to create lockfile '$lockfile' - $!";

    $self->{fh} = $fh;
    $self->{curpid} = $$;

    my $oldfh = select $fh;
    $| = 1;
    select $oldfh;
    return $fh;
}

sub _lock {
    my $self = shift;
    my $fh = $self->{fh};

    # Locking 0: LOCK_SH
    # Locking 1: LOCK_EX
    #
    # Why this dubious locking?
    #
    # The children will always write data in its slots and will
    # never overwrite data of other children. For this reason a
    # shared lock is adequate.
    #
    # The parent process needs to read a constistent state of the
    # from the shared memory of its children. For this reason the
    # parent process needs to lock always in exclusive mode for all
    # operations.
    #
    # In the end a child can only obtain a shared lock if the parent
    # does not lock in exlusive mode.

    if ($self->{locking}) {
        flock($fh, LOCK_EX);
    } else {
        flock($fh, LOCK_SH);
    }
}

sub _unlock {
    my $self = shift;
    my $fh = $self->{fh};
    flock($fh, LOCK_UN);
}

sub _write {
    my ($self, $string, $offset, $length) = @_;
    my $fh = $self->_open_lockfile;
    my $rest = $length;
    my $written = 0;

    if (!defined $string) {
        $string = "";
    }

    if (length $string > $length) {
        $string = substr($string, 0, $length);
    } elsif (length $string < $length) {
        $string .= "\0" x ($length - length $string);
    }

    $self->_seek($fh, $offset);
    $offset = 0;

    while ($rest) {
        $written = syswrite $fh, $string, $rest, $offset;

        if (!defined $written) {
            die "unable to write to shared file - $!";
        } elsif ($written) {
            $rest -= $written;
            $offset += $written;
        }
    }
}

sub _seek {
    my ($self, $fh, $offset) = @_;
    my $counter = 0;

    while ($offset != sysseek($fh, 0, 1)) {
        sysseek($fh, $offset, 0);
        $counter++;

        if ($counter > 10) {
            warn "ERR: unable to seek to lock file pos $offset";
            sleep 1;
        }
    }
}

sub _read {
    my ($self, $offset, $length) = @_;
    my ($data, $len, $buf);
    my $fh = $self->_open_lockfile;
    my $rest = $length;
    my $rdsz = $length < RECVBUF ? $length : RECVBUF;
    my $clen = 0;

    $self->_seek($fh, $offset);

    while ($rest) {
        $len = sysread $fh, $buf, $rdsz;

        if (!defined $len) {
            if ($! =~ /^Interrupted/) {
                Time::HiRes::sleep(0.1); # careful
                next;
            }
            die "unable to read from shared file - $!";
        } elsif ($len) {
            $data .= $buf;  # concat the data pieces
            $rest -= $len;  # this is the rest we have to read
            #$clen += $len;  # the current len
            #warn "read $clen/$length bytes";
        } elsif ($rest) {
            # Oh, doh, this should never happends.
            # Maybe the other end dies.
            #die "unable to read all data from client (rest $rest, length $len, read size $rdsz)";
            Time::HiRes::sleep(0.1); # careful
        }

        if ($rest < $rdsz) {
            # otherwise sysread() hangs if we wants to read to much
            $rdsz = $rest;
        }
    }

    $data =~ s/\0+\z//;
    return $data;
}

sub destroy {
    my $self = shift;
    $self->DESTROY;
}

sub DESTROY {
    if ($$ == PARENT_PID) {
        my $self = shift;
        unlink($self->{lockfile});
    }
}

1;
