=head1 NAME

Bloonix::Validate::Constraints - Validate constraints.

=head1 SYNOPSIS

    my $con = Bloonix::Validate::Constraints->new();

    unless (&{$con->date}("2012-02-30")) {
        die "This is not a valid date!";
    }

=head1 DESCRIPTION

Constraints to parse extended strings like date time values.

=head1 METHODS

=head2 new

The constructor.

=head2 check_date($date)

Return true if the passed string is a valid timestamp in the following format:

    YYYY-MM-DD

=head2 check_daytime($daytime)

Return true if the passed string is a valid timestamp in the following format:

    hh:mm:ss

=head2 check_datetime($datetime)

Return true if the passed string is a valid timestamp in the following format:

    YYYY-MM-DD hh:mm:ss

=head2 check_datehourmin($datetime)

    YYYY-MM-DD hh:mm

Return true if the passed string is a valid timestamp in the following format:

=head2 check_from_to_time($from, $to, $zone)

Return true if the passed strings are valid timestamps in the following format:

    YYYY-MM-DD hh:mm:ss - YYYY-MM-DD hh:mm:ss
    YYYY-MM-DD hh:mm - YYYY-MM-DD hh:mm
    YYYY-MM-DD - YYYY-MM-DD

If the to-timestamp is not set, then it's set to the current time.

As third argument the timezone can be passed. This can be useful if the to-timestamp
is not set and must be generated.

=head2 check_timeperiod

Check a timeperiod with Bloonix::Timeperiod.

=head2 date, datehourmin, datetime, daytime, from_to_time, preparedate

This methods just returns the code for each constraint.

=head2 constraint_date, constraint_daytime, constraint_datetime, constraint_datehourmin, constraint_preparedate, constraint_from_to_time, constraint_timeperiod

=head1 PREREQUISITES

No prerequisites.

=head1 EXPORTS

No exports.

=cut

package Bloonix::Validate::Constraints;

use strict;
use warnings;
use base qw(Bloonix::Accessor);
use Bloonix::Timeperiod;

__PACKAGE__->mk_accessors(qw/
    date datetime datehourmin daytime preparedate from_to_time timeperiod
    param_value
/);

my $rx_year  = qr/\d{4}/;
my $rx_month = qr/(?:0[1-9]|1[0-2])/;
my $rx_day   = qr/(?:0[1-9]|[1-2][0-9]|3[0-1])/;
my $rx_hour  = qr/(?:[0-1][0-9]|2[0-3])/;
my $rx_min   = qr/[0-5][0-9]/;
my $rx_sec   = $rx_min;

my %constraint = (
    date => \&constraint_date,
    daytime => \&constraint_daytime,
    datetime => \&constraint_datetime,
    datehourmin => \&constraint_datehourmin,
    preparedate => \&constraint_preparedate,
    from_to_time => \&constraint_from_to_time,
    timeperiod => \&constraint_timeperiod,
    param_value => \&constraint_param_value
);

sub new {
    my $class = shift;

    return bless \%constraint, $class;
}

sub constraint_date {
    my ($value) = @_;

    if ($value && $value =~ /^($rx_year)-($rx_month)-($rx_day)\z/) {
        my ($year, $month, $day) = ($1, $2, $3);
        my $febdays = $year % 100 && $year % 4 ? 28 : 29;

        if (($month =~ /^(?:4|6|9|11)\z/ && $day > 30) || ($month == 2 && $day > $febdays)) {
            return undef;
        }

        return 1;
    }

    return undef;
}

sub constraint_daytime {
    my ($value) = @_;

    if ($value && $value =~ /^($rx_hour):($rx_min):($rx_sec)\z/) {
        return 1;
    }

    return undef;
}

sub constraint_datetime {
    my ($value) = @_;

    if ($value && $value =~ /^($rx_year)-($rx_month)-($rx_day)\s+($rx_hour):($rx_min):($rx_sec)\z/) {
        my ($year, $month, $day, $hour, $min, $sec) = ($1, $2, $3, $4, $5, $6);

        if (&{$constraint{date}}("$year-$month-$day")) {
            return 1;
        }
    }

    return undef;
}

sub constraint_datehourmin {
    my ($value) = @_;

    if ($value && $value =~ /^($rx_year)-($rx_month)-($rx_day)\s+($rx_hour):($rx_min)\z/) {
        my ($year, $month, $day, $hour, $min) = ($1, $2, $3, $4, $5);

        if (&{$constraint{date}}("$year-$month-$day")) {
            return 1;
        }
    }

    return undef;
}

sub constraint_preparedate {
    my ($date) = @_;

    if (!$date) {
        return undef;
    }

    if ($date =~ /^(\d{1,2}).\s*(ja|f|mar|ap|may|mai|jun|jul|au|s|o|n|d)[a-z]*.(\d\d\d\d)\z/i) {
        my ($day, $mon, $year) = ($1, $2, $3);
        $day = sprintf("%02d", $day);
        $mon = lc($mon);
        $mon = $mon eq "ja"     ? "01" : $mon;
        $mon = $mon eq "f"      ? "02" : $mon;
        $mon = $mon eq "mar"    ? "03" : $mon;
        $mon = $mon eq "ap"     ? "04" : $mon;
        $mon = $mon =~ /ma[iy]/ ? "05" : $mon;
        $mon = $mon eq "jun"    ? "06" : $mon;
        $mon = $mon eq "jul"    ? "07" : $mon;
        $mon = $mon eq "au"     ? "08" : $mon;
        $mon = $mon eq "s"      ? "09" : $mon;
        $mon = $mon eq "o"      ? "10" : $mon;
        $mon = $mon eq "n"      ? "11" : $mon;
        $mon = $mon eq "d"      ? "12" : $mon;
        $_[0] = "$year-$mon-$day";
    } elsif ($date =~ /^(\d\d)\.(\d\d)\.(\d\d\d\d)\z/) {
        $_[0] = "$3-$2-$1";
    }
}

sub constraint_from_to_time {
    my ($from, $to, $zone) = @_;

    if (!&{$constraint{datetime}}($from)) {
        if (&{$constraint{datehourmin}}($from)) {
            $from .= ":00";
        } elsif (&{$constraint{date}}($from)) {
            $from .= " 00:00:00";
        } else {
            return undef;
        }
        $_[0] = $from;
    }

    if (!&{$constraint{datetime}}($to)) {
        if (&{$constraint{datehourmin}}($to)) {
            $to .= ":00";
        } elsif (&{$constraint{date}}($to)) {
            $to .= " 00:00:00";
        } elsif (!$to) {
            my ($old, $tz);

            if ($zone) {
                $tz = exists $ENV{TZ} ? 1 : 0;
                $old = $ENV{TZ};
                $ENV{TZ} = $zone;
            }

            my @time = (localtime(time))[reverse 0..5];
            $time[0] += 1900;
            $time[1] += 1;
            $to = sprintf "%04d-%02d-%02d %02d:%02d:%02d", @time[0..5];

            if ($zone) {
                if ($tz) {
                    $ENV{TZ} = $old;
                } else {
                    delete $ENV{TZ};
                }
            }
        } else {
            return undef;
        }
        $_[1] = $to;
    }

    $from =~ s/\D//g;
    $to =~ s/\D//g;

    if ($to < $from) {
        return undef;
    }

    return 1;
}

sub constraint_timeperiod {
    my $time = $_[0];

    return Bloonix::Timeperiod->parse($time) ? 1 : 0;
}

sub constraint_param_value {
    if (!$_[0] || !length $_[0]) {
        return 1;
    }

    foreach my $pv (split /[\r\n]+/, $_[0]) {
        next if $pv =~ /^\s*\z/;
        next if $pv =~ /^\s*#/;
        if ($pv !~ /^\s*[a-zA-Z_0-9\.]+\s*=\s*([^\s].*)\z/) {
            return undef;
        }
    }

    return 1;
}

sub check_date {
    my $self = shift;

    return &{$self->{date}}(@_);
}

sub check_datetime {
    my $self = shift;

    return &{$self->{datetime}}(@_);
}

sub check_datehourmin {
    my $self = shift;

    return &{$self->{datehourmin}}(@_);
}

sub check_daytime {
    my $self = shift;

    return &{$self->{daytime}}(@_);
}

sub check_from_to_time {
    my $self = shift;

    return &{$self->{from_to_time}}(@_);
}

sub check_timeperiod {
    my $self = shift;

    return &{$self->{timeperiod}}(@_);
}

1;
