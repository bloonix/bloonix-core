package Bloonix::CreateSSL;

use strict;
use warnings;

sub simple_key_pair {
    my ($class, %opts) = @_;

    $opts{bytes} ||= 4096;
    $opts{key_file} ||= "private.key";
    $opts{cert_file} ||= "public.cert";

    system("openssl genrsa -out $opts{key_file} $opts{bytes}");
    return undef if $?;
    system("openssl rsa -pubout -in $opts{key_file} -out $opts{cert_file}");
    return undef if $?;

    return 1;
}

1;
