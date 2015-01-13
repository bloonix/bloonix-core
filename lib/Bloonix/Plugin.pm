package Bloonix::Plugin;

use strict;
use warnings;
use JSON;
use Time::HiRes qw();
use Bloonix::IPC::Cmd;
use base qw(Bloonix::Accessor);

__PACKAGE__->mk_accessors(qw/json progname shortname version options option options_order flags/);
__PACKAGE__->mk_accessors(qw/plugin_libdir host_id service_id libfile config_path ip_version/);

sub new {
    my ($class, %opts) = @_;
    my $self = bless \%opts, $class;

    $self->{exitcode} = {
        0 => 0, OK => 0,
        1 => 1, WARNING => 1,
        2 => 2, CRITICAL => 2,
        3 => 3, UNKNOWN => 3
    };

    $self->{ip_version} = "IPv4";
    $self->{json} = JSON->new;
    $self->{option} = { };
    $self->{options} = { };
    $self->{result} = { };
    $self->{options_order} = [ ];
    $self->{progname} = do { $0 =~ m!([^/\\]+)\z!; $1 };
    $self->{shortname} = do { $self->progname =~ /^([\w\-]+)/; $1 };
    $self->{plugin_libdir} = $ENV{PLUGIN_LIBDIR} || "/tmp";
    $self->{host_id} = $ENV{CHECK_HOST_ID} || 0;
    $self->{service_id} = $ENV{CHECK_SERVICE_ID} || 0;
    $self->{config_path} = $ENV{CONFIG_PATH} || "/etc/bloonix/agent";
    $self->{flags} = "";

    $self->{libfile} = join("-",
        "bloonix",
        $self->shortname,
        $self->host_id,
        $self->service_id
    );

    $self->{libfile} = join("/",
        $self->{plugin_libdir},
        $self->{libfile}
    );

    $self->{libfile} .= ".json";

    return $self;
}

sub add_option {
    my ($self, %opts) = @_;

    if (!defined $opts{value_type} || $opts{value_type} eq "none") {
        $opts{value_type} = 0;
    }

    foreach my $opt (qw/option description/) {
        if (!exists $opts{$opt}) {
            $self->exit(
                status => "UNKNOWN",
                message => "missing mandatory option '$opt' by the call of plugin->add_option()"
            );
        }
    }

    if (defined $opts{regex} && ref $opts{regex} ne "ARRAY") {
        $opts{regex} = [ $opts{regex} ];
    }

    if ($opts{option} !~ /^[a-zA-Z0-9\-]+\z/) {
        $self->exit(
            status => "UNKNOWN",
            message => "option '$opts{option}' is invalid"
        );
    }

    my $_option = $opts{option};
    $_option =~ tr/-/_/;

    $opts{mandatory} = $opts{mandatory} ? 1 : 0;
    $opts{multiple} = $opts{multiple} ? 1 : 0;
    $opts{default} = defined $opts{default} ? $opts{default} : undef;

    $self->set_option($_option => \%opts);
    push @{$self->options_order}, $_option;
}

sub _add_default_options {
    my $self = shift;

    $self->add_option(
        name => "Version",
        option => "version",
        description => "Print the version.",
        command_line_only => 1
    );

    $self->add_option(
        name => "Help",
        option => "help",
        description => "Print the help.",
        command_line_only => 1
    );

    $self->add_option(
        name => "Plugin information",
        option => "plugin-info",
        description => "Print plugin information as JSON string.",
        command_line_only => 1
    );

    $self->add_option(
        name => "Pretty output",
        option => "pretty",
        description => "Print the plugin information in pretty format",
        command_line_only => 1
    );
}

sub get_option {
    my ($self, $option) = @_;
    my $options = $self->{options};
    return $options->{$option};
}

sub set_option {
    my ($self, $option, $value) = @_;

    $self->{options}->{$option} = $value;
}

sub get_options {
    my $self = shift;

    return @{$self->{options_order}};
}

sub parse_options {
    my $self = shift;
    $self->_add_default_options;

    foreach my $_option ($self->get_options) {
        my $option = $self->get_option($_option);

        if (defined $option->{default}) {
            if ($option->{multiple} && ref $option->{default} ne "ARRAY") {
                $self->exit(
                    status => "UNKNOWN",
                    message => "invalid default value for option '$option->{option}'"
                );
            }

            $self->option->{$_option} = $option->{default};
        } elsif ($option->{multiple}) {
            $self->option->{$_option} = [ ];
        } else {
            $self->option->{$_option} = undef;
        }
    }

    if ($ARGV[0] && $ARGV[0] eq "--stdin") {
        if ($ARGV[1] && $ARGV[1] eq "--pretty") {
            $self->option->{pretty} = 1;
        }
        $self->parse_stdin_arguments;
    } elsif ($ARGV[0] && $ARGV[0] =~ /^\s*{/) {
        $self->parse_json_arguments($ARGV[0]);
    } else {
        $self->parse_command_line_arguments;
    }

    if ($self->option->{help}) {
        $self->print_help;
    }

    if ($self->option->{version}) {
        $self->print_version;
    }

    if ($self->option->{plugin_info}) {
        $self->print_plugin_info;
    }

    $self->check_options;

    if ($self->option->{secret_file}) {
        ($self->option->{username}, $self->option->{password})
            = $self->get_secret_file;
    }

    if ($self->option->{use_ipv6}) {
        $self->ip_version("IPv6");
    }

    return $self->option;
}

sub parse_stdin_arguments {
    my $self = shift;

    my $args = <STDIN>;
    chomp $args;

    $self->parse_json_arguments($args);
}

sub parse_json_arguments {
    my ($self, $json) = @_;
    my $options;

    CORE::eval { $options = $self->json->decode($json) };

    if ($@) {
        $self->exit(
            status => "UNKNOWN",
            message => "json parse error - unable to parse command line options"
        );
    }

    if (ref $options ne "HASH") {
        $self->exit(
            status => "UNKNOWN",
            message => "invalid json input data - expect a hash ref instead an array"
        );
    }

    foreach my $option (keys %$options) {
        my $_option = $option;
        $_option =~ tr/-/_/;

        if (!$self->get_option($_option)) {
            $self->exit(
                status => "UNKNOWN",
                message => "unknown option '$option'"
            );
        }

        if ($self->get_option($_option)->{multiple}) {
            $self->option->{$_option} = ref $options->{$option} eq "ARRAY"
                ? $options->{$option}
                : [ $options->{$option} ];
        } elsif (!$self->get_option($_option)->{value_type}) {
            # options with no value are single arguments (flags)
            # and must be set to a true value if the option exists.
            $self->option->{$_option} = 1;
        } else {
            $self->option->{$_option} = $options->{$option};
        }
    }
}

sub parse_command_line_arguments {
    my $self = shift;

    while (@ARGV) {
        my $option = shift @ARGV;
        my ($_option, $value);

        if ($option =~ /^--([a-zA-Z0-9][a-zA-Z0-9\-]*)\z/) {
            $_option = $1;
            $_option =~ tr/-/_/;
        } else {
            $self->exit(
                status => "UNKNOWN",
                message => "Invalid option '$option'"
            );
        }

        if (!defined $_option || !$self->get_option($_option)) {
            $self->exit(
                status => "UNKNOWN",
                message => "Unknown option '$option'"
            );
        }

        if ($self->get_option($_option)->{value_type}) {
            $value = shift @ARGV;
            my $value_type = $self->get_option($_option)->{value_type};

            if (!defined $value) {
                $self->exit(
                    status => "UNKNOWN",
                    message => "Missing value for option '$option'"
                );
            } elsif (
                ($value_type eq "int" && $value !~ /^\d+\z/)
                || ($value_type eq "number" && $value !~ /^[1-9]\d*\z/)
                || ($value_type eq "array" && ref $value ne "ARRAY")
                || ($value_type eq "hash" && ref $value ne "HASH")
            ) {
                $self->exit(
                    status => "UNKNOWN",
                    message => "Invalid value '$value' for option '$option'"
                );
            }
            if (ref $self->option->{$_option} eq "ARRAY") {
                if (!$self->{parsed}->{$_option}) {
                    @{$self->option->{$_option}} = ();
                    $self->{parsed}->{$_option} = 1;
                }
                push @{$self->option->{$_option}}, $value;
            } else {
                $self->option->{$_option} = $value;
            }
        } else {
            $self->option->{$_option} = 1;
        }
    }
}

sub one_must_have_options {
    my ($self, @params) = @_;
    $_ =~ tr/-/_/ for @params;
    $self->{one_must_have_options} = \@params;
}

sub check_options {
    my $self = shift;

    foreach my $_option ($self->get_options) {
        my $option = $self->get_option($_option);
        my $value = $self->option->{$_option};
        my $value_type = $option->{value_type} || "none";

        # Remove not allowed characters!
        if (defined $value) {
            $value =~ s/[`'\\]//g;
        }

        if ($option->{mandatory} && (!defined $value || (ref $value eq "ARRAY" && !@$value)) && (!$self->{has_list_objects} || !$self->option->{list})) {
            $self->exit(
                status => "UNKNOWN",
                message => "Missing mandatory option '$_option'"
            );
        }

        if ($option->{multiple} && ref $value ne "ARRAY") {
            $self->exit(
                status => "UNKNOWN",
                message => "option '$_option' must be an array reference"
            );
        }

        if (!$option->{multiple} && (ref $value && $option->{value_type} !~ /^(array|hash)\z/)) {
            $self->exit(
                status => "UNKNOWN",
                message => "option '$_option' must be a string and not a reference"
            );
        }

        if (defined $value && (
            ($value_type eq "int" && $value !~ /^\d+\z/)
            || ($value_type eq "number" && $value !~ /^[1-9]\d*\z/)
            || ($value_type eq "array" && ref $value ne "ARRAY")
            || ($value_type eq "hash" && ref $value ne "HASH")
        )) {
            $self->exit(
                status => "UNKNOWN",
                message => "Invalid value '$value' for option '$_option'"
            );
        }

        if (defined $value && $option->{prepare}) {
            $option->{prepare}($value);
            $self->option->{$_option} = $value;
        }

        if ($option->{regex} && defined $value) {
            if (ref $value eq "ARRAY") {
                foreach my $item (@$value) {
                    if (!$self->_check_option_by_regex($item => $option->{regex})) {
                        $self->exit(
                            status => "UNKNOWN",
                            message => "Invalid value '$item' for option '$option->{option}'"
                        );
                    }
                }
            } elsif (!$self->_check_option_by_regex($value => $option->{regex})) {
                $self->exit(
                    status => "UNKNOWN",
                    message => "Invalid value '$value' for option '$option->{option}'"
                );
            }
        }
    }

    if ($self->{one_must_have_options}) {
        my $hit = 0;

        foreach my $opt (@{$self->{one_must_have_options}}) {
            if (defined $self->option->{$opt}) {
                if (ref $self->option->{$opt} ne "ARRAY" || (ref $self->option->{$opt} eq "ARRAY" && @{$self->option->{$opt}})) {
                    $hit = 1;
                    last;
                }
            }
        }

        if ($hit == 0) {
            $self->exit(
                status => "UNKNOWN",
                message => join(" ",
                    "At least one of the following options must",
                    "be set: ". join(", ", @{$self->{one_must_have_options}})
                )
            );
        }
    }
}

sub _check_option_by_regex {
    my ($self, $option, $regexes) = @_;

    foreach my $regex (@$regexes) {
        if ($option =~ $regex) {
            return 1;
        }
    }

    return 0;
}

sub print_help {
    my $self = shift;
    my $examples = $self->{examples};
    my @units = grep !/^none\z/, keys %{$self->{keys_by_unit}};

    print "\nUsage: ", $self->progname, " [ OPTIONS ]\n\n";

    if ($self->info) {
        print "Info:\n\n";
        print join("\n", @{$self->{info}}), "\n\n";
    }

    print "Options:\n\n";

    foreach my $_option ($self->get_options) {
        my $option = $self->get_option($_option);
        print "--$option->{option}";

        if ($option->{value_desc}) {
            print " <$option->{value_desc}>\n";
        } elsif ($option->{value}) { # deprecated
            print " <$option->{value}>\n";
        } else {
            print "\n";
        }

        if (exists $option->{description}) {
            if (ref $option->{description} ne "ARRAY") {
                $option->{description} = [ $option->{description} ];
            }

            $_ = "    $_" for @{$option->{description}};
            print join("\n", @{$option->{description}}), "\n";
        }

        if (defined $option->{default} && length $option->{default}) {
            print "    Default: $option->{default}\n";
        } elsif ($option->{mandatory}) {
            print "    This option is mandatory.\n";
        }
    }

    if ($examples) {
        print "\nExamples:\n";

        foreach my $example (@$examples) {
            my $e = ref $example->{description} eq "ARRAY"
                ? $example->{description}
                : [ $example->{description} ];

            my $first = "  * " . shift @$e;
            $_ = "    $_" for @$e;
            unshift @$e, $first;
            print "\n", join("\n", @$e), "\n\n";

            my @c = @{$example->{arguments}};
            print "      ", $self->progname;

            while (@c) {
                my $param = shift @c;
                my $value = shift @c;
                print " --$param";
                if (defined $value) {
                    print " '$value'";
                }
            }

            print "\n";
        }
    }

    if ($self->{has_threshold}) {
        my $info = $self->get_threshold_info;
        print "\n", @$info;
        print "  The allowed keys to check are\n\n";

        my $str = "";
        foreach my $thr (@{$self->{has_threshold}}) {
            if (length($str) + length($thr->{key}) > 100) {
                print "    $str\n";
                $str = "";
            }
            $str = $str ? "$str, $thr->{key}" : $thr->{key};
        }
        print "\n";
    }

    print "\nCommand line options as JSON string\n\n";
    print "  * It's possible to pass the command line options as a JSON string:\n\n";
    print "    $self->{progname} '", '{"option":"value","multiple":["value1","value"]}', "'\n\n";
    print "  * It's also possible to pass the JSON string to STDIN of the plugin:\n\n";
    print "    $self->{progname} --stdin <<EOT\n";
    print '    {"option":"value","multiple":["value1","value"]}', "\n";
    print "    EOT\n\n";

    exit 3;
}

sub get_threshold_info {
    my $self = shift;
    my @units = grep !/^none\z/, keys %{$self->{keys_by_unit}};
    my @info;

    push @info, "How to set warning and critical thresholds:\n\n";
    push @info, "  It's possible to set thresholds for one or more statistic keys.\n";

    if ($self->{has_threshold_info}) {
        foreach my $line (@{$self->{has_threshold_info}}) {
            push @info, $line eq "" ? "\n" : "  $line\n";
        }
        push @info, "\n";
    }

    push @info, "  The format to add a threshold for a statistic key is:\n\n";
    push @info, "    key:operator:threshold\n\n";

    if (@units) {
        push @info, "  or if a unit makes sense\n\n";
        push @info, "    key:operator:threshold + UNIT\n\n";
        push @info, "  where the unit can be in ", join(" or ", @units), ".\n\n";
    }

    push @info, "  If no operator is set then the default operator is 'ge'.\n\n";
    push @info, "  The following operators are available:\n\n";
    push @info, "    lt = less than\n";
    push @info, "    le = less than or equal\n";
    push @info, "    gt = greater than\n";
    push @info, "    ge = greater than or equal\n";
    push @info, "    eq = equal\n";
    push @info, "    ne = not equal\n";

    if (@units) {
        push @info, "\n";
        foreach my $unit (@units) {
            if ($unit eq "bytes") {
                push @info, "  Allowed units for bytes:\n\n";
                push @info, "    KB = Kilobytes   TB = Terabytes   ZB = Zettabytes\n";
                push @info, "    MB = Megabytes   PB = Petabytes   YB = Yottabytes\n";
                push @info, "    GB = Gigabytes   EB = Exabytes\n\n";
            } else {
                push @info, "  Allowed units for percent: %\n\n";
            }
        }
    }

    return \@info;
}

sub print_version {
    my $self = shift;
    print $self->progname, " v", $self->version, "\n";
    exit 3;
}

sub print_plugin_info {
    my $self = shift;
    my $examples = $self->{examples};
    my @plugins;

    my %output = (
        plugin => $self->progname,
        version => $self->version,
        options => \@plugins,
        flags => $self->flags
    );

    if ($self->info) {
        $output{info} = $self->info;
    }

    if ($self->{has_threshold}) {
        $output{thresholds}{options} = $self->{has_threshold};
    }

    if ($self->{has_threshold}) {
        $output{thresholds}{info} = $self->get_threshold_info;
    }

    if ($examples) {
        foreach my $example (@$examples) {
            my @args = @{$example->{arguments}};
            my @command_line = ($self->progname);
            my $description = $example->{description} eq "ARRAY"
                ? join("\n", @{$example->{description}})
                : $example->{description};

            while (@args) {
                my $param = shift @args;
                my $value = shift @args;

                if (defined $value) {
                    push @command_line, "--$param '$value'";
                } else {
                    push @command_line, "--$param";
                }
            }

            push @{$output{examples}}, {
                description => $description,
                arguments => $example->{arguments},
                command_line => join(" ", @command_line)
            };
        }
    }

    foreach my $_option ($self->get_options) {
        my $option = $self->get_option($_option);

        if ($option->{command_line_only}) {
            next;
        }

        my %plugin = (
            name => $option->{name},
            option => $option->{option},
            mandatory => $option->{mandatory},
            multiple => $option->{multiple},
            value_type => $option->{value_type}
        );

        if (defined $option->{value_desc}) {
            $plugin{value_desc} = $option->{value_desc};
        } elsif (defined $option->{value}) { # deprecated
            $plugin{value_desc} = $option->{value};
        }

        if (defined $option->{example}) {
            $plugin{example} = $option->{example};
        }

        $plugin{description} = ref $option->{description} eq "ARRAY"
            ? join("\n", @{$option->{description}})
            : $option->{description};

        if (exists $option->{default}) {
            $plugin{default} = $option->{default};
        }

        push @plugins, \%plugin;
    }

    if ($self->option->{pretty}) {
        $self->json->pretty(1);
    }

    print $self->json->encode(\%output);

    exit 0;
}

sub info {
    my ($self, @info) = @_;

    if (@info) {
        $self->{info} = \@info;
    }

    return wantarray ? @{$self->{info}} : $self->{info};
}

sub example {
    my ($self, %opts) = @_;

    if (ref $opts{description} ne "ARRAY") {
        $opts{description} = [ $opts{description} ];
    }

    push @{$self->{examples}}, \%opts;
}

sub delta { # return undef if a overflow is detected
    my ($self, %opts) = @_;
    $opts{time} ||= time;
    my $init = $self->load_json;
    my $ret = 1;

    $self->safe_json({ data => $opts{stat}, time => $opts{time} });

    # If init->{data} doesn't exists then it's possible
    # that the script was migrated to use plugin->delta.
    if (!defined $init || $opts{time} - $init->{time} == 0 || !$init->{data}) {
        $ret = undef;
        foreach my $key (@{$opts{keys}}) {
            $opts{stat}{$key} = "0.00";
        }
    } else {
        my $delta = $opts{time} - $init->{time};
        $init = $init->{data};

        foreach my $key (@{$opts{keys}}) {
            # Handle counter? No!
            # 32bit = 2147483647
            # 64bit = 9223372036854775807
            # The problem is if the host is rebooted... the difference that is calculated
            # could be too high in this case! For this reason the statistic is set to 0.00.
            # If anybody has another idea... let me know it.
            if ($init->{$key} >= $opts{stat}{$key} || $delta == 0) {
                $opts{stat}{$key} = "0.00";
            } else {
                $opts{stat}{$key} = sprintf("%.2f", ($opts{stat}{$key} - $init->{$key}) / $delta);
            }
        }
    }

    return $ret;
}

sub eval {
    my ($self, $opts) = (shift, {@_});

    $opts->{timeout} ||= 10;
    $opts->{action} ||= "execution";
    $opts->{timeout_status} = "CRITICAL";
    $opts->{unknown_status} = "UNKNOWN";

    CORE::eval {
        local $SIG{__DIE__} = sub { alarm(0) };
        local $SIG{ALRM} = sub { die "timeout" };
        alarm($opts->{timeout});
        &{$opts->{callback}}();
        alarm(0);
    };

    my $error = $@;

    if ($error) {
        if ($error =~ /timeout/) {
            if ($opts->{add_mtr}) {
                $self->add_mtr($opts->{add_mtr});
            }

            $self->exit(
                status => $opts->{timeout_status},
                message => $opts->{message} || "$opts->{action} timed out after $opts->{timeout} seconds"
            );
        }

        $self->exit(
            status => "CRITICAL",
            message => "error: $error"
        );
    }
}

sub execute {
    my ($self, %opts) = @_;

    my $action = delete $opts{action} || "command execution";
    my $callback = delete $opts{callback};
    my $debug = delete $opts{debug};

    $opts{kill_signal} ||= 9;
    $opts{timeout} ||= 10;

    my $ipc = Bloonix::IPC::Cmd->run(%opts);

    if ($ipc->timeout) {
        $self->exit(
            status => "CRITICAL",
            message => "$action runs on a timeout"
        );
    }

    if ($ipc->unknown) {
        $self->exit(
            status => "CRITICAL",
            message => $ipc->unknown
        );
    }

    if ($ipc->is_stderr) {
        print STDERR join("\n", @{$ipc->stderr}), "\n";
    }

    if ($debug) {
        print STDERR $self->json->pretty->encode([
            $ipc->{command},
            $ipc->stdout,
            $ipc->stderr
        ]);
    }

    if ($callback) {
        my @ret;
        eval { @ret = &$callback($ipc) };
        if ($@) {
            $self->exit(
                status => "UNKNOWN",
                message => $@
            );
        }
        return wantarray ? @ret : $ret[0];
    }

    return $ipc;
}

sub get_ip_by_hostname {
    my ($self, $type, $hostname, $do_not_exit) = @_;

    if ($hostname =~ /^\d+\.\d+\.\d+\.\d+\z/ || $hostname =~ /:.*:/) {
        return $hostname;
    }

    if ($hostname !~ /^[a-zA-Z0-9]+([.-][a-zA-Z0-9]+){0,}\z/) {
        $self->exit(
            status => "UNKNOWN",
            message => "invalid hostname $hostname"
        );
    }

    require Net::DNS::Resolver;

    if ($type =~ /ipv4/i) {
        $type = "A";
    } elsif ($type =~ /ipv6/i) {
        $type = "AAAA";
    }

    my $res = Net::DNS::Resolver->new;
    my $query = $res->search($hostname, $type);
    my $ipaddr;

    if ($query) {
        foreach my $rr ($query->answer) {
            next unless $rr->type eq $type;
            $ipaddr = $rr->address;
        }
    }

    if (!$ipaddr && !$do_not_exit) {
        $self->exit(
            status => "UNKNOWN",
            message => "unable to resolv hostname $hostname"
        );
    }

    return $ipaddr;
}

sub add_mtr {
    my ($self, $host) = @_;

    $self->{add_mtr} = $host;
}

sub get_mtr {
    my ($self, $ipaddr) = @_;

    my $output = "";
    my $command = "mtr --no-dns -trc 3 $ipaddr";
    my $timeout = 30;
    my @output;
    my %result = (result => \@output, ipaddr => $ipaddr, status => "ok");

    eval {
        local $SIG{__DIE__} = sub { alarm(0) };
        local $SIG{ALRM} = sub { die "timeout" };
        alarm($timeout);
        $output = qx{$command};
        alarm(0);
    };

    if ($@) {
        if ($@ =~ /^timeout/) {
            $result{message} = "MTR timed out after $timeout seconds";
        } else {
            $result{message} = "an unexpected error occurs, please contact the administrator";
        }
        $result{status} = "err";
        return \%result;
    }

    my @lines = split /\n/, $output;
    my @header = split /\s+/, shift @lines;

    foreach my $line (@lines) {
        $line =~ s/^\s*//;
        my %data;
        @data{qw(step ipaddr loss snt last avg best wrst stdev)}
            =  split /\s+/, $line;
        $data{step} =~ s/\|.+//;
        $data{loss} =~ s/%//;
        push @output, \%data;
    }

    return \%result;
}

sub result {
    my ($self, $key, $value) = @_;

    if (defined $key && defined $value) {
        $self->{result}->{$key} = $value;
    }

    return $self->{result};
}

sub exit {
    my ($self, %opts) = @_;
    my $exitcode = $self->{exitcode};

    foreach my $key (keys %{$self->result}) {
        $opts{$key} = $self->result->{$key};
    }

    if (!defined $opts{status} || !exists $exitcode->{$opts{status}}) {
        $self->exit(
            status => "UNKNOWN",
            message => "invalid exitcode '$opts{status}'"
        );
    }

    if ($self->{add_mtr}) {
        $opts{debug}{mtr} = $self->get_mtr($self->{add_mtr});
    }

    if (exists $opts{set_tags}) {
        my $set_tags = delete $opts{set_tags};
        my @tags;
        foreach my $tag (keys %$set_tags) {
            if ($set_tags->{$tag}) {
                push @tags, $tag;
            }
        }
        if ($opts{tags}) {
            push @tags, $opts{tags};
        }
        if (@tags) {
            $opts{tags} = join(",", @tags);
        }
    }

    if ($self->option->{pretty}) {
        $self->json->pretty(1);
    }

    print $self->json->encode(\%opts);

    if (!$self->option->{pretty}) {
        print "\n";
    }

    CORE::exit $exitcode->{$opts{status}};
}

sub load_json {
    my ($self, $file) = @_;

    if (!defined $file || !length $file) {
        $file = $self->libfile;
    }

    open my $fh, "<", $file or return undef;
    my $data = do { local $/; <$fh> };
    close $fh;

    CORE::eval { $data = $self->json->decode($data) };

    if ($@) {
        return undef;
    }

    return $data;
}

sub safe_json {
    my ($self, $data, $file) = @_;

    if (!defined $file || !length $file) {
        $file = $self->libfile;
    }

    open my $fh, ">", $file or $self->exit(
        status => "UNKNOWN",
        message => "unable to open lib file '$file' for writing - $!"
    );

    print $fh $self->json->encode($data);

    close $fh;
}

sub gettimeofday {
    return sprintf("%.3f", scalar Time::HiRes::gettimeofday());
}

sub runtime {
    my $self = shift;

    if (!defined $self->{time}) {
        $self->{time} = Time::HiRes::gettimeofday();
    }

    my $ret = sprintf("%.3f", Time::HiRes::gettimeofday() - $self->{time});

    $self->{time} = Time::HiRes::gettimeofday();

    return $ret;
}

sub get_secret_file {
    my ($self, $file) = @_;
    my ($username, $password);
    my $config_path = $self->config_path;
    $file ||= $self->option->{secret_file};
    $file =~ s!^$config_path/!!;

    if ($file !~ m/^[\w\.\-]+\z/) {
        $self->exit(
            status => "UNKNOWN",
            message => "invalid characters found in file name. Allowed signs are: a-zA-Z0-9_.-",
        );
    }

    $file = join("/", $config_path, $file);

    open my $fh, "<", $file or do {
        $self->exit(
            status => "UNKNOWN",
            message => "unable to open secret file '$file' - $!"
        );
    };

    while (my $line = <$fh>) {
        chomp $line;

        if ($line =~ /^\s*(?:user|username)\s*=\s*([^\s]+)/) {
            $username = $1;
        } elsif ($line =~ /^\s*password\s*=\s*([^\s]+)/) {
            $password = $1;
        }

        last if $username && $password;
    }

    return ($username, $password);
}

sub check_thresholds {
    my ($self, %opts) = @_;
    my $stats = $opts{stats};
    my $upshot_keys = $opts{upshot_keys};
    my $hits = { };
    my $result = { status => "OK", hits => $hits };
    my (@upshot, %checked);

    foreach my $status (qw/warning critical/) {
        next if !$self->option->{$status} || !@{$self->option->{$status}};

        foreach my $rule (@{$self->option->{$status}}) {
            my ($key, $op, $value, $threshold);

            if ($rule =~ /^([^:]+):(le|lt|ge|gt|eq|ne):(.+)\z/) {
                ($key, $op, $threshold) = ($1, $2, $3);
            } elsif ($rule =~ /^([^:]+):(.+)\z/) {
                ($key, $op, $threshold) = ($1, "ge", $2);
            }

            if (!exists $stats->{$key}) {
                $self->exit(
                    status => "UNKNOWN",
                    message => "unable to check threadhold for key '$key' - statistic key does not exists"
                );
            }

            $value = $self->convert_to_bytes($threshold);

            if ($op ne "eq" && $op ne "ne" && (!defined $value || $value !~ /^-{0,1}\d+(\.\d+){0,1}\z/)) {
                $self->exit(
                    status => "UNKNOWN",
                    message => "value of threshold '$key' is not numeric"
                );
            }

            if ($self->compare($stats->{$key}, $op, $value)) {
                $hits->{$key}->{status} = uc $status;
                $hits->{$key}->{value} = $stats->{$key};
                $hits->{$key}->{op} = $op;
                $hits->{$key}->{threshold} = $threshold;
                $result->{status} = uc $status;
            }
        }
    }

    if ($upshot_keys && @$upshot_keys) {
        foreach my $key (keys %$hits) {
            @$upshot_keys = grep !/^$key\z/, @$upshot_keys;
        }
    }

    foreach my $key (keys %$hits, @$upshot_keys) {
        next if exists $checked{$key};
        next unless exists $stats->{$key};
        $checked{$key} = 1;

        # maybe the stats key exists but is not added via has_thresholds
        $self->{has_units}->{$key} ||= "none";

        my $upshot = "$key=";

        if ($self->{has_units}->{$key} eq "bytes") {
            $upshot .= $self->convert_bytes_to_string($stats->{$key});
        } elsif ($self->{has_units}->{$key} eq "percent") {
            $upshot .= $stats->{$key} . "%";
        } else {
            $upshot .= $stats->{$key};
        }

        if (exists $hits->{$key}) {
            $upshot .= " " . join(" ",
                $self->convert_operator_to_string($hits->{$key}->{op}),
                $hits->{$key}->{threshold},
            );
            if ($opts{add_unit}) {
                $upshot .= $opts{add_unit};
            }
            $upshot .= " [". do { $hits->{$key}->{status} =~ /^(.)/; uc($1) } ."]";
        }

        push @upshot, $upshot;
    }

    $result->{upshot} = join(", ", @upshot);

    if ($opts{exit} && $opts{exit} ne "no") {
        $self->exit(
            status => $result->{status},
            message => $result->{upshot},
            stats => $opts{stats}
        );
    }

    return $result;
}

sub convert_to_operator {
    my ($self, $op) = @_;

    if ($op eq "ge") {
        return ">=";
    }
    if ($op eq "le") {
        return "<=";
    }
    if ($op eq "gt") {
        return ">";
    }
    if ($op eq "lt") {
        return "<";
    }
    if ($op eq "eq") {
        return "==";
    }
    if ($op eq "ne") {
        return "!=";
    }
}

sub convert_operator_to_string {
    my ($self, $op) = @_;

    if ($op eq "ge") {
        return "is greater than or equal";
    }
    if ($op eq "le") {
        return "is less than or equal";
    }
    if ($op eq "gt") {
        return "is greater than";
    }
    if ($op eq "lt") {
        return "is less than";
    }
    if ($op eq "eq") {
        return "is equal";
    }
    if ($op eq "ne") {
        return "is not equal";
    }
}

sub compare {
    my ($self, $value, $op, $threshold) = @_;

    if ($op !~ /^(ne|eq)\z/ && $threshold !~ /^-{0,1}\d+(\.\d+){0,1}\z/) {
        $self->exit(
            status => "UNKNOWN",
            message => "threshold '$threshold' is invalid and not comparable with operator '$op'"
        );
    }

    if ($op eq "ge") {
        return $value >= $threshold;
    }
    if ($op eq "le") {
        return $value <= $threshold;
    }
    if ($op eq "gt") {
        return $value > $threshold;
    }
    if ($op eq "lt") {
        return $value < $threshold;
    }
    if ($op eq "eq") {
        return $value eq $threshold;
    }
    if ($op eq "ne") {
        return $value ne $threshold;
    }

    $self->exit(
        status => "UNKNOWN",
        message => "invalid compare operator '$op'"
    );
}

sub convert_to_bytes {
    my ($self, $value) = @_;

    if ($value =~ s/([KMGTPEZYC]B)\z//) {
        my $unit = $1;

        if ($unit eq "KB") {
            $value = $value * 1024;
        } elsif ($unit eq "MB") {
            $value = $value * 1048576;
        } elsif ($unit eq "GB") {
            $value = $value * 1073741824;
        } elsif ($unit eq "TB") {
            $value = $value * 1099511627776;
        } elsif ($unit eq "PB") {
            $value = $value * 1125899906842624;
        } elsif ($unit eq "EB") {
            $value = $value * 1152921504606846976;
        } elsif ($unit eq "ZB") {
            $value = $value * 1180591620717411303424;
        } elsif ($unit eq "YB") {
            $value = $value * 1208925819614629174706176;
        }
    }

    return $value;
}

sub convert_bytes_to_string {
    my ($self, $value) = @_;
    my $unit = "B";

    if ($value >= 1208925819614629174706176) {
        $value /= 1208925819614629174706176;
        $unit = "YB";
    } elsif ($value >= 1180591620717411303424) {
        $value /= 1180591620717411303424;
        $unit = "ZB"
    } elsif ($value >= 1152921504606846976) {
        $value /= 1152921504606846976;
        $unit = "EB";
    } elsif ($value >= 1125899906842624) {
        $value /= 1125899906842624;
        $unit = "PB";
    } elsif ($value >= 1099511627776) {
        $value /= 1099511627776;
        $unit = "TB";
    } elsif ($value >= 1073741824) {
        $value /= 1073741824;
        $unit = "GB";
    } elsif ($value >= 1048576) {
        $value /= 1048576;
        $unit = "MB";
    } elsif ($value >= 1024) {
        $value /= 1024;
        $unit = "KB";
    }

    return sprintf("%.1f%s", $value, $unit);
}

sub has_threshold {
    my ($self, %opts) = @_;
    my (%keys_by_unit, @regexes);
    $self->{keys_by_unit} = \%keys_by_unit;

    if ($opts{info}) {
        $self->{has_threshold_info} = ref $opts{info} ne "ARRAY"
            ? [ $opts{info} ]
            : $opts{info};
    }

    foreach my $item (@{$opts{keys}}) {
        my ($unit, $key);

        if (ref $item eq "HASH") {
            $item->{unit} ||= "none";
            $unit = $item->{unit};
            $key = $item->{key};
            push @{$self->{has_threshold}}, $item;
        } else {
            $unit = $opts{unit} || "none";
            $key = $item;
            push @{$self->{has_threshold}}, { key => $key, unit => $unit };
        }

        push @{$keys_by_unit{$unit}}, $key;
        $self->{has_units}->{$key} = $unit;
    }

    foreach my $unit (keys %keys_by_unit) {
        my $keys = join "|", @{$keys_by_unit{$unit}};

        if ($unit eq "none") {
            push @regexes, qr/^($keys):((lt|le|gt|ge):){0,1}(\d+(?:\.\d+){0,1})\z/;
            push @regexes, qr/^($keys):((eq|ne):){0,1}(.+)\z/;
        } elsif ($unit eq "percent") {
            push @regexes, qr/^($keys):((lt|le|gt|ge|eq|ne):){0,1}(\d+(?:\.\d+){0,1})%{0,1}\z/;
        } elsif ($unit eq "bytes") {
            push @regexes, qr/^($keys):((lt|le|gt|ge|eq|ne):){0,1}(\d+(?:\.\d+){0,1})([KMGTPEZYC]B){0,1}\z/;
        }
    }

    my $warning_opts = $opts{warning} || {};
    my $critical_opts = $opts{critical} || {};

    $warning_opts->{option} = "warning";
    $warning_opts->{description} = "This is the warning threshold. When the value exceeds the threshold a warning status is triggered. Please see the examples for more information.";

    $critical_opts->{option} = "critical";
    $critical_opts->{description} = "This is the critical threshold. When the value exceeds the threshold a critical status is triggered. Please see the examples for more information.";

    $warning_opts->{value_type} = $critical_opts->{value_type} = "string";
    $warning_opts->{multiple} = $critical_opts->{multiple} = 1;
    $warning_opts->{keys} = $critical_opts->{keys} = $opts{keys};
    $warning_opts->{units} = $critical_opts->{units} = $self->{has_units};
    $warning_opts->{regex} = $critical_opts->{regex} = \@regexes;
    $warning_opts->{value_desc} = $critical_opts->{value_desc} = "key:value or key:op:value";

    $self->add_option(name => "Warning threshold", %$warning_opts);
    $self->add_option(name => "Critical threshold", %$critical_opts);
}

sub has_warning {
    my ($self, %opts) = @_;

    $self->add_option(
        name => "Warning threshold",
        option => "warning",
        value => "seconds",
        value_type => "number",
        description => "A value in seconds. When the check takes longer than this time then a warning status is triggered.",
        %opts
    );
}

sub has_critical {
    my ($self, %opts) = @_;

    $self->add_option(
        name => "Critical threshold",
        option => "critical",
        value => "seconds",
        value_type => "number",
        description => "A value in seconds. When the check takes longer than this time then a critical status is triggered.",
        %opts
    );
}

sub has_timeout {
    my ($self, %opts) = @_;

    $self->add_option(
        name => "Timeout",
        option => "timeout",
        value => "seconds",
        value_type => "number",
        description => "A timeout in seconds after its expiration the check is aborted and a critical status is triggered.",
        %opts
    );
}

sub has_host {
    my ($self, %opts) = @_;

    $self->add_option(
        name => "Hostname or IP address",
        option => "host",
        value => "hostname or ip address",
        value_type => "string",
        regex => qr/^[^\s]+\z/,
        description => "A hostname or IP address to connect to.",
        %opts
    );
}

sub has_port {
    my ($self, %opts) = @_;

    $self->add_option(
        name => "Port number",
        option => "port",
        value => "port",
        value_type => "int",
        regex => qr/^(?:6553[0-5]|655[0-2][0-9]|65[0-4][0-9]{2}|6[0-4][0-9]{3}|[0-5]?[0-9]{4}|[0-9]{2,4}|[1-9])\z/,
        description => "A port number to connect to.",
        %opts
    );
}

sub has_bind {
    my ($self, %opts) = @_;

    $self->add_option(
        name => "Bind to IP address",
        option => "bind",
        value => "ipaddr",
        value_type => "string",
        regex => qr/^[a-fA-F0-9\.:]+\z/,
        description => "A local IP address to bind to.",
        %opts
    );
}

sub has_url {
    my ($self, %opts) = @_;

    $self->add_option(
        name => "URL",
        option => "url",
        value => "url",
        value_type => "string",
        prepare => sub {
            if ($_[0] =~ m@^https{0,1}://[^/]+\z@) {
                $_[0] = "$_[0]/";
            }
        },
        regex => qr@^https{0,1}://[^']+/[^\s']*\z@,
        description => "This is the HTTP or HTTPS request you want to check. Please enter the full URL with the query string.",
        example => "http://www.bloonix.de/",
        %opts
    );
}

sub has_use_ipv6 {
    my ($self, %opts) = @_;

    $self->add_option(
        name => "Use IPv6",
        option => "use-ipv6",
        description => "Use IPv6 to connect to the host.",
        %opts
    );
}

sub has_use_ssl {
    my ($self, %opts) = @_;

    $self->add_option(
        name => "Use secure connection via SSL",
        option => "use-ssl",
        description => "Use secure connection via SSL.",
        %opts
    );
}

sub has_auth_basic {
    my ($self, %opts) = @_;

    $self->add_option(
        name => "Username",
        option => "username",
        value => "username",
        value_type => "string",
        regex => qr/^[^\s]+\z/,
        description => "A username for a HTTP Auth-Basic authentication.",
        %opts
    );

    $self->add_option(
        name => "Password",
        option => "password",
        value => "password",
        value_type => "string",
        regex => qr/^[^\s]+\z/,
        description => "A password for a HTTP Auth-Basic authentication.",
        %opts
    );
}

sub has_login_username {
    my ($self, %opts) = @_;

    $self->add_option(
        name => "Username",
        option => "username",
        value => "username",
        value_type => "string",
        regex => qr/^[^\s]+\z/,
        description => "The username to use for the login.",
        %opts
    );
}

sub has_login_password {
    my ($self, %opts) = @_;

    $self->add_option(
        name => "Password",
        option => "password",
        value => "password",
        value_type => "string",
        regex => qr/^[^\s]+\z/,
        description => "The password for the user to login.",
        %opts
    );
}

sub has_database_name {
    my ($self, %opts) = @_;

    $self->add_option(
        name => "Database",
        option => "database",
        value => "database",
        value_type => "string",
        regex => qr/^[^\s]+\z/,
        description => "Set the database to connect to.",
        %opts
    );
}

sub has_database_driver {
    my ($self, %opts) = @_;

    $self->add_option(
        name => "Database driver",
        option => "driver",
        value => "driver",
        value_type => "string",
        regex => qr/^[a-zA-Z0-9]+\z/,
        description => "Which perl DBD driver to use. Example: mysql, Pg, DB2 ...",
        %opts
    );
}

sub has_login_secret_file {
    my ($self, %opts) = @_;

    my $secret_file = $opts{default} || delete $opts{"example-file"} || "passwd.conf";

    $self->add_option(
        name => "Secret file",
        option => "secret-file",
        value => "filename",
        value_type => "string",
        description => "This is the secret file with the username and password to connect to the service.",
        %opts
    );

    $self->example(
        description => [
            join(" ",
                "To read the username and password from a configuration file",
                "it's possible to use the option 'secret-file'. The path to",
                "the file is hard set to:"
            ),
            "",
            "    /etc/bloonix/agent",
            "",
            join(" ",
                "All what you have to do is to create the file in '/etc/bloonix/agent'",
                "and fill the filename into the field 'secret-file'. The content",
                "of the file should looks like:"
            ),
            "",
            "    username=root",
            "    password=secret"
        ],
        arguments => [
            "secret-file" => $secret_file
        ]
    );
}

sub has_mailbox {
    my ($self, %opts) = @_;

    $self->add_option(
        name => "Mailbox",
        option => "mailbox",
        value => "mailbox",
        value_type => "string",
        regex => qr/^[a-zA-Z]+\z/,
        description => "The mailbox to query.",
        %opts
    );
}

sub has_debug {
    my ($self, %opts) = @_;

    $self->add_option(
        name => "Debug",
        option => "debug",
        description => "Turn on debugging. Just useful if you want to test something on the command line.",
        command_line_only => 1,
        %opts
    );
}

sub has_use_apop {
    my ($self, %opts) = @_;

    $self->add_option(
        name => "Use APOP",
        option => "apop",
        description => "Use apop to login.",
        %opts
    );
}

sub has_list_objects {
    my ($self, %opts) = @_;

    $opts{option} ||= "list";
    $opts{description} ||= "List available objects.";
    $opts{command_line_only} = 1;
    $self->{has_list_objects} = 1;
    $self->add_option(%opts);
}

### SNMP special

sub start_snmp_session {
    my $self = shift;

    my %opts = (
        -hostname => $self->option->{host},
        -community => $self->option->{community},
        -version => $self->option->{snmp_version},
        -port => $self->option->{port},
        -timeout => $self->{snmp_timeout}
    );

    if ($self->option->{snmp_version} == 3) {
        if (!$self->option->{username}) {
            $self->exit(
                status => "UNKNOWN",
                message => "Missing SNMPv3 username in argument list"
            );
        }

        $opts{"-username"} = $self->option->{username};

        foreach my $key (qw/authpassword authprotocol privpassword privprotocol/) {
            if ($self->option->{$key}) {
                $opts{"-$key"} = $self->option->{username};
            }
        }
    }

    my ($snmp, $error) = Net::SNMP->session(%opts);

    if (!defined $snmp) {
        chomp($error);
        $self->exit(
            status => "CRITICAL",
            message => "unable to connect to snmp host ".$self->option->{host}.": $error"
        );
    }

    return $snmp;
}

sub has_snmp {
    my ($self, %opts) = @_;

    require Net::SNMP;
    $self->has_host(default => $opts{host} || "127.0.0.1");
    $self->has_port(default => $opts{port} || 161);
    $self->has_snmp_community(default => $opts{community} || "public");
    $self->has_snmp_version(default => $opts{community} || 2);
    $self->has_snmp_username;
    $self->has_snmp_authpassword;
    $self->has_snmp_authprotocol;
    $self->has_snmp_privpassword;
    $self->has_snmp_privprotocol;
    $self->{snmp_timeout} = $opts{timeout} || 15;
}

sub has_snmp_community {
    my ($self, %opts) = @_;

    $self->add_option(
        name => "SNMP community",
        option => "community",
        value => "community",
        value_type => "string",
        default => "public",
        regex => qr/^[^\s]+\z/,
        description => "The SNMP community to connect to the host.",
        %opts
    );
}

sub has_snmp_version {
    my ($self, %opts) = @_;

    $self->add_option(
        name => "SNMP version",
        option => "snmp-version",
        value => "version",
        value_type => "string",
        default => 2,
        regex => qr/^[123]\z/,
        description => "The SNMP version to use to connect to the host.",
        %opts
    );
}

sub has_snmp_username {
    my ($self, %opts) = @_;

    $self->add_option(
        name => "SNMPv3 username",
        option => "username",
        value => "username",
        value_type => "string",
        regex => qr/^.{0,32}\z/,
        description => "The SNMPv3 username.",
        %opts
    );
}

sub has_snmp_authpassword {
    my ($self, %opts) = @_;

    $self->add_option(
        name => "SNMPv3 auth password",
        option => "authpassword",
        value => "authpassword",
        value_type => "string",
        description => "The SNMPv3 auth password.",
        %opts
    );
}

sub has_snmp_privpassword {
    my ($self, %opts) = @_;

    $self->add_option(
        name => "SNMPv3 priv password",
        option => "privpassword",
        value => "privpassword",
        value_type => "string",
        description => "The SNMPv3 priv password.",
        %opts
    );
}

sub has_snmp_authprotocol {
    my ($self, %opts) = @_;

    $self->add_option(
        name => "SNMPv3 auth protocol",
        option => "authprotocol",
        value => "authprotocol",
        value_type => "string",
        description => "The SNMPv3 auth protocol.",
        %opts
    );
}

sub has_snmp_privprotocol {
    my ($self, %opts) = @_;

    $self->add_option(
        name => "SNMPv3 priv protocol",
        option => "privprotocol",
        value => "privprotocol",
        value_type => "string",
        description => "The SNMPv3 priv protocol.",
        %opts
    );
}

1;

=head1 NAME

Bloonix::Plugin::Base - The Bloonix plugin helper.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head2 How to handle values of options and values of values

    1. pass multiple values comma separated or with multiple options

        --interface eth0,eth1,...
        --interface eth0 --interface eth1

    2. pass multiple values of values separated via colon

        --interface eth0:1000,eth1:1000
        --interface eth0:1000 --interface eth1:1000

    3. pass operators between values of values

        --interface eth0:lt:1000,eth1:lt:1000
        --interface eth0:lt:1000 --interface eth1:lt:1000

        lt = less than
        le = less than or equal
        gt = greater than
        ge = greater than or equal
        eq = equal
        ne = not equal

=head1 METHODS

=head2 new

=head2 add_option

    * value types

    i = positive number
    n = positive number, but must be higher than 0
    s = string

    * special options

    ! = is mandatory
    @ = multiple values possible

=head2 get_option

=head2 set_option

=head2 get_options

=head2 option

=head2 parse_options

=head2 check_options

=head2 version

=head2 info

=head2 example

=head2 print_help

=head2 print_version

=head2 print_plugin_info

=head2 get_threshold_info

=head2 parse_command_line_arguments

=head2 parse_json_arguments

=head2 parse_stdin_arguments

=head2 load_json

=head2 safe_json

=head2 gettimeofday

=head2 exit

=head2 runtime

=head2 one_must_have_options

=head2 get_secret_file

=head2 convert_operator_to_string

=head2 convert_to_operator

=head2 convert_to_bytes

=head2 convert_bytes_to_string

=head2 compare

=head2 check_thresholds

=head2 has_auth_basic

=head2 has_bind

=head2 has_database_driver

=head2 has_database_name

=head2 has_error_login_status

=head2 has_connection_refuse_status

=head2 has_host

=head2 has_port

=head2 has_login_password

=head2 has_login_secret_file

=head2 has_login_username

=head2 has_timeout

=head2 has_use_ipv6

=head2 has_use_ssl

=head2 has_warning

=head2 has_critical

=head2 has_threshold

=head2 has_mailbox

=head2 has_use_apop

=head2 has_debug

=head1 PREREQUISITES

    JSON
    Time::HiRes
    Getopt::Long

=head1 AUTHOR

Jonny Schulz <support(at)bloonix.de>.

=head1 COPYRIGHT

Copyright (C) 2013-2014 by Jonny Schulz. All rights reserved.

=cut
