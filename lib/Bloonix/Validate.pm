=head1 NAME

Bloonix::Validate - Validating parameter, forms, configurations.

=head1 SYNOPSIS

    use Bloonix::Validate;

    my $validator = Bloonix::Validate->new(
        autodie  => 1,
        autotrim => 1,
    );

    $validator->set(
        username => {
            min_size => 3,
            max_size => 20,
        },
        email => {
            regex => $validator->regex->email,
            optional => 1
        },
        avatar => {
            options => [ qw/Monk Smiley Superman Nightmare Jackass/ ],
            default => "",
            optional => 1,
        },
        interests => {
            desc => "Choose your favite programming languages.",
            options => [ qw/Perl Python Ruby Haskell C C++ Java/ ],
        },
        company => {
            options => {
                2382 => "Foo GmbH",
                3842 => "Bar AG",
            },
        },
    );

    # validate() returns an object of Bloonix::Validate::ResultSet
    my $rs = $validator->validate(\%params);

    # Fetch all parameter
    my @valid   = $rs->valid;
    my @invalid = $rs->invalid;
    my @missed  = $rs->missed;
    my @failed  = $rs->failed;

    # Fetch all parameter and values as a hash reference
    my $valid   = $rs->valid;
    my $invalid = $rs->invalid;
    my $missed  = $rs->missed;
    my $failed  = $rs->failed;

=head1 DESCRIPTION

This module provides just another validator for key-value pairs, parameters,
html forms or configurations files. It's possible to define form with rules
and retrieve form data from a C<CGI> or C<Catalyst::Request> or C<Dragon>
object. If you retrieve the parameters already you can pass it as a hash reference.
The parameter will be validated and splitted into valid, missed or invalid.

=head1 RULES

=over 4

=item type                  SCALAR|HASH|ARRAY|GLOB

=item size                  string length.

=item min_size              min string length.

=item max_size              max string length.

=item min_val               min value.

=item max_val               max value.

=item lesser                lesser than...

=item greater               greater than...

=item equal                 is equal

=item not_equal             is not equal

=item regex                 regex match

=item regexcl               each value in a comma separated list must match

=item regexwl               each value in a white space separated list must match

=item prepare               do something with the value before the rules tries to match

=item postprod              do something after the value was successfully validated

=item constraint            pass a constraint

=item constraint_any        any constraint must match

=item constraint_all        all constraints must match

=item options               the value must match a string in the option list

=item multioptions          each value must match a string in the option list

=back

=head1 REGEXES

=over 4

=item digit         - on digit

=item number        - one or more digits

=item float         - such as 0.01

=item alphas        - one char of a-z A-Z 0-9 _

=item non_alphas    - the opposite of ALPHA

=item bool          - 0 1

=item true          - 1

=item false         - 0

=item email         - email address

=item ipv4          - a ip v4 address

=item ipv6          - a ip v6 address

=item ipaddr        - a ip v4 or v6 address

=item time          - time stamp hh:mm:ss

=item date          - date stamp yyyy-mm-dd

=item datetime      - date and time stamp yyyy-mm-dd hh:mm:ss

=back

=head1 CONSTRAINTS

=over 4

=item constraint_date  - check the date and month days with leap year (yyyy-mm-dd hh:mm:ss)

=back

=head1 METHODS

=head2 new()

Creates a new Bloonix::Validate object.

=over 4

=item autotrim

Remove leading and trailing whitespaces from all values.

Default: 1

=item autodie

Turn this parameter on if you want that the validator dies with
an error message that includes all parameters that couldn't be
successfully validated.

Default: 0

=back

=head2 convert( \%param )

Convert HTML special characters.

=head2 regex

C<regex> returns a object of Bloonix::Validate::Regexes.

Example:

    $validator->regex->email;

=head2 constraint

C<constraint> returns a object of Bloonix::Validate::Constraint.

Example:

    $validator->constraint->datetime;

=head2 set(\%rules)

Register a complete new set of parameters with rules. That means
that the old set of parameters will be deleted first. If you just
want to add or overwrite parameters, use put() instead!

    $validator->set(
        param-name => {
            # parameter handling
            default     => $default,  # string or reference or whatever
            optional    => 1,         # This option is a little bit confusing
                                      # and means that empty params are ok.
                                      # But if the param is not empty it must
                                      # hit any rule

            prepare     => sub { },   # $value will be passed as a reference
                                      # and before all parameter rules will
                                      # be checked

            # simple parameter rules
            size         => 10,
            min_size     => 10,
            max_size     => 100,
            min_val      => 10,
            max_val      => 100,
            lesser       => 100,
            greater      => 10,
            equal        => "string",
            not_equal    => "string",
            number       => 12345,
            regex        => qr/regex/,
            regex        => $validator->regex->ipv4,
            regexcl      => $validator->regex->ipv4, # comma seperated list (ip1, ip2, ip3)
            regexwl      => $validator->regex->ipv4, # whitespace separated list (ip1 ip2 ip3)
            cut_newlines => 1, # cut newlines before check other rules
            options      => [ qw{would try to grep(/^$value\z/) from array} ],
            options      => { "just" => "check", "if" => "the", "hashkey" => "exists" },
            options      => [ # ordered select options
                {
                    name  => "the option name/alias",
                    value => "check if value is eq options value",
                },
            ],

            # the Bloonix::Validate object and the $value will be passed to each code reference
            constraint     => sub { }, # must return 1 for success
            constraint_all => [ sub { }, sub { } ], # all must return 1 for success
            constraint_any => [ sub { }, sub { } ], # any must return 1 for success
            type => "array" # if type is array and a constraint is set then the array is passed to the constraint
    });

    $validator->postcheck(
        sub {
            my $data = shift;
            # ... validation and return failed parameter
        }
    );

=head2 put()

The same like set() but the complete set will not be deleted first.

=head2 postcheck()

With this method it's possible to define a postcheck.

The method expects a code reference.

    $validator->postcheck(
        sub {
            my $data = shift;

            # ... validate data ...

            return ("foo", "bar"); # failed keys
        },
    );

=head2 options()

Return the options.

=head2 params()

Returns all params as a array in list context and as a array
reference in scalar context.

    @params = $validator->params; # array
    $params = $validator->params; # array reference

=head2 defaults()

Returns the default settings as a list in list context and as
a hash reference in scalar context.

=head2 delete()

Delete all parameter rules of the object.

=head2 validate($params)

Validate params.

    my %params_to_validate = (
        param1 => "value 1",
        param2 => "value 2",
        param3 => "value 3",
    );

    $validator->validate(\%params_to_validate);

    $validator->validate(
        \%params_to_validate,
        ignore_missing => 1,
        force_defaults => 1,
        stash => { additional => "params" },
    );

The hash that is passed with the key C<stash> is acessable with the C<stash()>
accessor within constraints and the postcheck code.

=head2 stash()

This is a accessor to the stash that is passed by the call of C<validate()>.

An empty stash will be created if no stash is passed.

The stash will be cleared after C<validate()>.

=head2 validate_exists

Checks if the parameter exists and returns a result set.

    $validator->validate_exists(qw/param1 param2 param3/);

=head2 quick($params)

Quick validation of params.

As first you can pass a hash or hash reference with key-value pairs.

As last the rule set must be passed.

    my $result = Bloonix::Validate->quick(@_, {
        param1 => {
            min_size => 1,
            max_size => 10,
        },
        param2 => {
            min_size => 10,
            max_size => 20,
        },
    });

The result will be returned as a hash in list context and as
a hash reference in scalar context.

=head1 PREREQUISITES

No prerequisites.

=head1 EXPORTS

No exports.

=cut

package Bloonix::Validate;

use strict;
use warnings;
use Log::Handler;
use Bloonix::Validate::Regexes;
use Bloonix::Validate::Functions;
use Bloonix::Validate::Constraints;
use Bloonix::Validate::ResultSet;
use base qw(Bloonix::Accessor);

__PACKAGE__->mk_accessors(qw/regex constraint function data/);
__PACKAGE__->mk_accessors(qw/defaults mandatory optional options schema log/);

our $VERSION = "0.2";

sub new {
    my ($class, %opts) = @_;
    my $self = bless \%opts, $class;

    $self->{constraint} = Bloonix::Validate::Constraints->new();
    $self->{regex} = Bloonix::Validate::Regexes->new();
    $self->{function} = Bloonix::Validate::Functions->new();
    $self->{autotrim} //= 1;
    $self->{autodie} //= 0;
    $self->{debug} //= 0;
    $self->{log} //= Log::Handler->get_logger("bloonix");
    $self->delete;

    return $self;
}

sub postcheck {
    my ($self, $code) = @_;

    if ($code) {
        push @{$self->{postcheck}}, $code;
    }

    return $self->{postcheck};
}

sub stash {
    my $self = shift;

    return $self->{opts}->{stash};
}

sub set {
    my $self = shift;

    $self->delete;

    return $self->put(@_);
}

sub put {
    my $self = shift;

    my $rules = @_ == 1 ? shift : {@_};

    if (ref($rules) ne "HASH") {
        die "invalid data structure passed to set()";
    }

    foreach my $param (keys %$rules) {
        my $is_mandatory = 1;

        if (ref($rules->{$param}) ne "HASH") {
            die "invalid data structure for parameter $param";
        }

        foreach my $rule (keys %{$rules->{$param}}) {
            if ($rule =~ /^(?:options|multioptions)\z/) {
                if (ref($rules->{$param}->{$rule}) =~ /HASH|ARRAY/) {
                    $self->{options}->{$param} = $rules->{$param}->{$rule};
                } else {
                    die "rule '$rule' of parameter '$param' must be a hash or array reference";
                }
            } elsif ($rule =~ /^(?:default|optional)\z/) {
                if ($rule eq "default") {
                    $self->{defaults}->{$param} = $rules->{$param}->{$rule};
                }
                $is_mandatory = 0;
            } elsif ($rule eq "alias") {
                $self->{alias}->{$param} = $rules->{$param}->{$rule};
            } elsif ($rule ne "empty_ok" && !$self->function->{$rule}) {
                die "invalid rule '$rule' of param '$param'";
            }
        }

        $self->{params}->{$param} = $rules->{$param};

        if ($is_mandatory) {
            push @{$self->{mandatory}}, $param;
        } else {
            push @{$self->{optional}}, $param;
        }
    }
}

sub params {
    my $self = shift;

    return wantarray ? keys %{$self->{params}} : $self->{params};
}

sub delete {
    my $self  = shift;

    $self->{params}    = { }; # all parameter of a form
    $self->{postcheck} = [ ]; # postcheck routines
    $self->{options}   = { }; # options or multioptions of a form
    $self->{mandatory} = [ ]; # mandatory options
    $self->{optional}  = [ ]; # optional parameters
    $self->{defaults}  = { }; # all defaults of a form
}

sub validate {
    my $self = shift;
    my $data = shift;
    my $opts = @_ == 1 ? shift : {@_};
    $opts->{stash} //= { };
    $self->{opts} = $opts;

    if (exists $opts->{minimal}) {
        if ($opts->{minimal}) {
            $opts->{ignore_missing} = 1;
        } else {
            $opts->{force_defaults} = 1;
        }
    }

    if (!scalar keys %{$self->{params}}) {
        die "no parameter defined that could used for validation";
    }

    my $type = ref($data);

    if ($type eq "HASH") {
        foreach my $param (keys %$data) {
            if (ref($data->{$param}) eq "ARRAY") {
                s/^[\s\n\r]+//  for @{$data->{$param}};
                s/[\s\n\r]+\z// for @{$data->{$param}};
            } elsif (!ref($data->{$param})) {
                $data->{$param} =~ s/^[\s\n\r]+//;
                $data->{$param} =~ s/[\s\n\r]+\z//;
            }
        }
    } else {
        $data = $self->_request_params($data);
    }

    my $result = $self->_validate($data);
    delete $self->{opts};

    if ($self->{autodie}) {
        if ($result->has_failed) {
            die "Validation of the following parameters failed: "
                .join(", ", $result->failed);
        }
    }

    return $result;
}

sub validate_exists {
    my ($self, @keys) = @_;
    my $params = $self->{params};
    my $result = Bloonix::Validate::ResultSet->new();

    foreach my $key (@keys) {
        if (exists $params->{$key}) {
            $result->valid($key => 1);
        } else {
            $result->invalid($key => 1);
        }
    }

    return $result;
}

sub quick {
    my $class = shift;
    my $rules = pop;
    my $param = @_ == 1 ? shift : {@_};

    my $self = $class->new(
        autodie => 1,
        autotrim => 0,
    );

    $self->set($rules);

    my $result = $self->validate(
        $param,
        ignore_missing => 0,
        force_defaults => 1,
    );

    my $data = $result->data;

    return wantarray ? %$data : $data;
}

#
# private stuff
#

sub _request_params {
    my ($self, $request) = @_;
    my $params = $self->{params};
    my %params = ();

    foreach my $param (keys %$params) {
        my $rules = $params->{$param};
        my $value = $request->param($param);

        if (!defined $value) {
            next;
        }

        # How to handle checkboxes: If no checkbox is checked in a form
        # then the browser send nothing, but sometimes we want an empty
        # list instead. For this reason the first element is removed
        # if the element is defined and empty. Example:
        #
        #   foo=""
        #   foo=1
        #   foo=2
        #   foo=3
        #
        # The result is foo=[1,2,3].
        #
        #   foo=""
        #
        # This would be an empty list and the result is foo=[].
        if (exists $rules->{multioptions} || ($rules->{type} && $rules->{type} =~ /^array\z/i)) {
            my @values = $request->param($param);

            if ($values[0] eq "") {
                shift @values;
            }

            $params{$param} = \@values;
        } else {
             $params{$param} = $value;
        }

        if ($self->{autotrim}) {
            if (ref($params{$param}) eq "ARRAY") {
                s/^[\s\n\r]+//  for @{$params{$param}};
                s/[\s\n\r]+\z// for @{$params{$param}};
            } elsif (!ref($params{$param})) {
                $params{$param} =~ s/^[\s\n\r]+//;
                $params{$param} =~ s/[\s\n\r]+\z//;
            }
        }
    }

    return \%params;
}

sub _validate {
    my ($self, $data) = @_;
    my $result = Bloonix::Validate::ResultSet->new();
    my $params = $self->{params};
    my $opts   = $self->{opts};
    my $func   = ();

    $result->{alias} = $self->{alias};
    $result->data($data);

    foreach my $param (keys %$params) {
        my $rules = $params->{$param};

        if (exists $data->{$param}) {
            my $is_invalid;
            my $data_ref = ref $data->{$param};

            if ($data_ref && !exists $rules->{type} && (!exists $rules->{multioptions} || $data_ref ne "ARRAY")) {
                $result->invalid($param => $data->{$param});
                next;
            }

            if (exists $rules->{prepare}) {
                $rules->{prepare}($data->{$param});
            }

            if (!defined $data->{$param}) {
                $data->{$param} = "";
            } elsif (exists $rules->{cut_newlines}) {
                $data->{$param} =~ s/[\r\n]//g;
            }

            if ($rules->{empty_ok} && length $data->{$param} == 0) {
                $result->valid($param => $data->{$param});
                next;
            }

            foreach my $rule (keys %$rules) {
                if ($rule =~ /^(?:cut_newlines|prepare|postprod|default|optional|alias|empty_ok)\z/) {
                    next;
                }

                if (!exists $self->function->{$rule}) {
                    $self->log->die(error => "Bloonix::Validate: rule $rule does not exists");
                }

                my $rule_result = $self->function->{$rule}($data->{$param}, $rules->{$rule});

                if (!$rule_result) {
                    $result->invalid($param => $data->{$param});
                    $is_invalid = 1;
                    last;
                } elsif (exists $rules->{postprod}) {
                    $rules->{postprod}(\$data->{$param});
                }
            }

            if (!$is_invalid) {
                $result->valid($param => $data->{$param});
            }
        } elsif (exists $rules->{default} && $opts->{force_defaults}) {
            $data->{$param} = $rules->{default};
            $result->valid($param => $data->{$param});
        } elsif (!$rules->{optional} && !$opts->{ignore_missing}) {
            $result->missed($param);
        }
    }

    if (@{$self->{postcheck}}) {
        foreach my $code (@{$self->{postcheck}}) {
            my @failed = &$code($data);

            foreach my $param (@failed) {
                $result->remove(valid => $param);
                $result->invalid($param => $data->{$param});
            }
        }
    }

    return $result;
}

1;
