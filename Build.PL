use strict;
use warnings;
use Module::Build;

my $build = Module::Build->new(
    create_makefile_pl => "traditional",
    module_name => "Bloonix::Core",
    dist_author => "Jonny Schulz",
    dist_abstract => "Bloonix Core",
    sign => 0,
    requires => {
#        "HTTP::Tiny" => "0.022",
#        "IO::Select" => 0,
#        "IO::Socket" => 0,
#        "IO::Socket::INET6" => 0,
#        "IO::Socket::SSL" => "1.77",
#        "IO::Uncompress::Gunzip" => 0,
#        "IPC::Open3" => 0,
        "JSON" => 0,
#        "Log::Handler" => "0.84",
#        "Params::Validate" => 0,
#        "Socket6" => 0,
#        "Term::ReadKey" => 0,
#        "Time::HiRes" => 0,
#        "Time::ParseDate" => 0
    }
);

$build->create_build_script;
