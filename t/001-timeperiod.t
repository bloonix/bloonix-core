use strict;
use warnings;
use Test::More tests => 54;
use Bloonix::Timeperiod;
use Time::ParseDate;

# 2016-04-04 was a Monday
my $time1 = Time::ParseDate::parsedate("2016-04-04 16:59:00");
my $time2 = Time::ParseDate::parsedate("2016-04-04 17:00:00");
my $debug = 0;
my $timeperiod = Bloonix::Timeperiod->new();

sub simple_test {
    my ($alias, $ts) = @_;

    foreach my $t (@$ts) {
        ok($timeperiod->parse($t), $alias);
        ok($timeperiod->check($t, $time1), $alias);
        ok(!$timeperiod->check($t, $time2), $alias);
    }
}

&simple_test("weekday", [
    "Monday 09:00 - 16:59, 17:01 - 18:59",
    "Mon 09:00 - 16:59, 17:01 - 18:59",
    "Monday - Friday 09:00 - 16:59, 17:01 - 18:59",
    "Mon - Fri 09:00 - 16:59, 17:01 - 18:59"
]);

&simple_test("month", [
    "April 09:00 - 16:59, 17:01 - 18:59",
    "Apr 09:00 - 16:59, 17:01 - 18:59",
    "January - July 09:00 - 16:59, 17:01 - 18:59",
    "Jan - Jul 09:00 - 16:59, 17:01 - 18:59"
]);

&simple_test("month_day", [
    "April 04 09:00 - 16:59, 17:01 - 18:59",
    "Apr 04 09:00 - 16:59, 17:01 - 18:59",
    "January 01 - July 01 09:00 - 16:59, 17:01 - 18:59",
    "Jan 01 - Jul 01 09:00 - 16:59, 17:01 - 18:59"
]);

&simple_test("year", [
    "2016 09:00 - 16:59, 17:01 - 18:59",
    "2016 - 2016 09:00 - 16:59, 17:01 - 18:59"
]);

&simple_test("year_month", [
    "2016-04 09:00 - 16:59, 17:01 - 18:59",
    "2015-08 - 2016-05 09:00 - 16:59, 17:01 - 18:59"
]);

&simple_test("date", [
    "2016-04-04 09:00 - 16:59, 17:01 - 18:59",
    "2016-03-08 - 2016-04-12 09:00 - 16:59, 17:01 - 18:59"
]);

