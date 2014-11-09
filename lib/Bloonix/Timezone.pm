=head1 NAME

Bloonix::Timezone - Timezones.

=head1 SYNOPSIS

    my $hash = Bloonix::Timezone->tzdata;

=head1 DESCRIPTION

This module parses the zone.tab of tzdata from
C<ftp://elsie.nci.nih.gov/pub/tzdata*.tar.gz>.

=head1 METHODS

=head2 C<new>

The constructor.

=head2 C<zones>

Returns all zones unformatted zones keys.

=head2 C<form>

Returns all zones as a AoH reference in the format

    [
        {
            name => "Europe/Isle of Man",
            value => Europe/Isle_of_Man"
        },
        {
            name => "Europe/San Marino",
            value => "Europe/San_Marino",
        },
        ...
    ]

=head2 C<tzdata>

Returns the zone.tab parsed as a hash reference.

=head2 C<exists>

Check if a timezone exists.

    Bloonix::Timezone->exists("Europe/Berlin");

Returns true or false.

=head1 PREREQUISITES

    zone.tab from ftp://elsie.nci.nih.gov/pub/tzdata*.tar.gz

=head1 REPORT BUGS

Please report all bugs to <support(at)bloonix.de>.

=head1 AUTHOR

Jonny Schulz <support(at)bloonix.de>

=head1 COPYRIGHT

Copyright (C) 2011-2014 by Jonny Schulz. All rights reserved.

=cut

package Bloonix::Timezone;

use strict;
use warnings;

our $VERSION = "0.1";

sub new {
    my $class = shift;
    my $self = bless { tzdata => $class->_tzdata }, $class;
    return $self;
}

sub zones {
    my $self = shift;

    return wantarray ? keys %{$self->{tzdata}} : [ keys %{$self->{tzdata}} ];
}

sub form {
    my $self = shift;
    my @form = ();

    foreach my $tz (sort keys %{$self->{tzdata}}) {
        my $name = $tz;
        $name =~ s/_/ /g;

        push @form, {
            name  => $name,
            value => $tz,
        };
    }

    return \@form;
}

sub exists {
    my ($self, $timezone) = @_;

    my $tzdata = ref $self eq __PACKAGE__
        ? $self->{tzdata}
        : $self->_tzdata;

    return $tzdata->{$timezone};
}

sub tzdata {
    my $self = shift;

    if (ref $self eq __PACKAGE__) {
        return $self->{tzdata};
    }

    return $self->_tzdata;
}

sub _tzdata {
    my %timezone = (
        "Africa/Abidjan" => {
            timezone => "Africa/Abidjan",
            country  => "CI",
            coord    => "+0519-00402",
            comment  => "",
        },
        "Africa/Accra" => {
            timezone => "Africa/Accra",
            country  => "GH",
            coord    => "+0533-00013",
            comment  => "",
        },
        "Africa/Addis_Ababa" => {
            timezone => "Africa/Addis Ababa",
            country  => "ET",
            coord    => "+0902+03842",
            comment  => "",
        },
        "Africa/Algiers" => {
            timezone => "Africa/Algiers",
            country  => "DZ",
            coord    => "+3647+00303",
            comment  => "",
        },
        "Africa/Asmara" => {
            timezone => "Africa/Asmara",
            country  => "ER",
            coord    => "+1520+03853",
            comment  => "",
        },
        "Africa/Bamako" => {
            timezone => "Africa/Bamako",
            country  => "ML",
            coord    => "+1239-00800",
            comment  => "",
        },
        "Africa/Bangui" => {
            timezone => "Africa/Bangui",
            country  => "CF",
            coord    => "+0422+01835",
            comment  => "",
        },
        "Africa/Banjul" => {
            timezone => "Africa/Banjul",
            country  => "GM",
            coord    => "+1328-01639",
            comment  => "",
        },
        "Africa/Bissau" => {
            timezone => "Africa/Bissau",
            country  => "GW",
            coord    => "+1151-01535",
            comment  => "",
        },
        "Africa/Blantyre" => {
            timezone => "Africa/Blantyre",
            country  => "MW",
            coord    => "-1547+03500",
            comment  => "",
        },
        "Africa/Brazzaville" => {
            timezone => "Africa/Brazzaville",
            country  => "CG",
            coord    => "-0416+01517",
            comment  => "",
        },
        "Africa/Bujumbura" => {
            timezone => "Africa/Bujumbura",
            country  => "BI",
            coord    => "-0323+02922",
            comment  => "",
        },
        "Africa/Cairo" => {
            timezone => "Africa/Cairo",
            country  => "EG",
            coord    => "+3003+03115",
            comment  => "",
        },
        "Africa/Casablanca" => {
            timezone => "Africa/Casablanca",
            country  => "MA",
            coord    => "+3339-00735",
            comment  => "",
        },
        "Africa/Ceuta" => {
            timezone => "Africa/Ceuta",
            country  => "ES",
            coord    => "+3553-00519",
            comment  => "Ceuta & Melilla",
        },
        "Africa/Conakry" => {
            timezone => "Africa/Conakry",
            country  => "GN",
            coord    => "+0931-01343",
            comment  => "",
        },
        "Africa/Dakar" => {
            timezone => "Africa/Dakar",
            country  => "SN",
            coord    => "+1440-01726",
            comment  => "",
        },
        "Africa/Dar_es_Salaam" => {
            timezone => "Africa/Dar es Salaam",
            country  => "TZ",
            coord    => "-0648+03917",
            comment  => "",
        },
        "Africa/Djibouti" => {
            timezone => "Africa/Djibouti",
            country  => "DJ",
            coord    => "+1136+04309",
            comment  => "",
        },
        "Africa/Douala" => {
            timezone => "Africa/Douala",
            country  => "CM",
            coord    => "+0403+00942",
            comment  => "",
        },
        "Africa/El_Aaiun" => {
            timezone => "Africa/El Aaiun",
            country  => "EH",
            coord    => "+2709-01312",
            comment  => "",
        },
        "Africa/Freetown" => {
            timezone => "Africa/Freetown",
            country  => "SL",
            coord    => "+0830-01315",
            comment  => "",
        },
        "Africa/Gaborone" => {
            timezone => "Africa/Gaborone",
            country  => "BW",
            coord    => "-2439+02555",
            comment  => "",
        },
        "Africa/Harare" => {
            timezone => "Africa/Harare",
            country  => "ZW",
            coord    => "-1750+03103",
            comment  => "",
        },
        "Africa/Johannesburg" => {
            timezone => "Africa/Johannesburg",
            country  => "ZA",
            coord    => "-2615+02800",
            comment  => "",
        },
        "Africa/Kampala" => {
            timezone => "Africa/Kampala",
            country  => "UG",
            coord    => "+0019+03225",
            comment  => "",
        },
        "Africa/Khartoum" => {
            timezone => "Africa/Khartoum",
            country  => "SD",
            coord    => "+1536+03232",
            comment  => "",
        },
        "Africa/Kigali" => {
            timezone => "Africa/Kigali",
            country  => "RW",
            coord    => "-0157+03004",
            comment  => "",
        },
        "Africa/Kinshasa" => {
            timezone => "Africa/Kinshasa",
            country  => "CD",
            coord    => "-0418+01518",
            comment  => "west Dem. Rep. of Congo",
        },
        "Africa/Lagos" => {
            timezone => "Africa/Lagos",
            country  => "NG",
            coord    => "+0627+00324",
            comment  => "",
        },
        "Africa/Libreville" => {
            timezone => "Africa/Libreville",
            country  => "GA",
            coord    => "+0023+00927",
            comment  => "",
        },
        "Africa/Lome" => {
            timezone => "Africa/Lome",
            country  => "TG",
            coord    => "+0608+00113",
            comment  => "",
        },
        "Africa/Luanda" => {
            timezone => "Africa/Luanda",
            country  => "AO",
            coord    => "-0848+01314",
            comment  => "",
        },
        "Africa/Lubumbashi" => {
            timezone => "Africa/Lubumbashi",
            country  => "CD",
            coord    => "-1140+02728",
            comment  => "east Dem. Rep. of Congo",
        },
        "Africa/Lusaka" => {
            timezone => "Africa/Lusaka",
            country  => "ZM",
            coord    => "-1525+02817",
            comment  => "",
        },
        "Africa/Malabo" => {
            timezone => "Africa/Malabo",
            country  => "GQ",
            coord    => "+0345+00847",
            comment  => "",
        },
        "Africa/Maputo" => {
            timezone => "Africa/Maputo",
            country  => "MZ",
            coord    => "-2558+03235",
            comment  => "",
        },
        "Africa/Maseru" => {
            timezone => "Africa/Maseru",
            country  => "LS",
            coord    => "-2928+02730",
            comment  => "",
        },
        "Africa/Mbabane" => {
            timezone => "Africa/Mbabane",
            country  => "SZ",
            coord    => "-2618+03106",
            comment  => "",
        },
        "Africa/Mogadishu" => {
            timezone => "Africa/Mogadishu",
            country  => "SO",
            coord    => "+0204+04522",
            comment  => "",
        },
        "Africa/Monrovia" => {
            timezone => "Africa/Monrovia",
            country  => "LR",
            coord    => "+0618-01047",
            comment  => "",
        },
        "Africa/Nairobi" => {
            timezone => "Africa/Nairobi",
            country  => "KE",
            coord    => "-0117+03649",
            comment  => "",
        },
        "Africa/Ndjamena" => {
            timezone => "Africa/Ndjamena",
            country  => "TD",
            coord    => "+1207+01503",
            comment  => "",
        },
        "Africa/Niamey" => {
            timezone => "Africa/Niamey",
            country  => "NE",
            coord    => "+1331+00207",
            comment  => "",
        },
        "Africa/Nouakchott" => {
            timezone => "Africa/Nouakchott",
            country  => "MR",
            coord    => "+1806-01557",
            comment  => "",
        },
        "Africa/Ouagadougou" => {
            timezone => "Africa/Ouagadougou",
            country  => "BF",
            coord    => "+1222-00131",
            comment  => "",
        },
        "Africa/Porto-Novo" => {
            timezone => "Africa/Porto-Novo",
            country  => "BJ",
            coord    => "+0629+00237",
            comment  => "",
        },
        "Africa/Sao_Tome" => {
            timezone => "Africa/Sao Tome",
            country  => "ST",
            coord    => "+0020+00644",
            comment  => "",
        },
        "Africa/Tripoli" => {
            timezone => "Africa/Tripoli",
            country  => "LY",
            coord    => "+3254+01311",
            comment  => "",
        },
        "Africa/Tunis" => {
            timezone => "Africa/Tunis",
            country  => "TN",
            coord    => "+3648+01011",
            comment  => "",
        },
        "Africa/Windhoek" => {
            timezone => "Africa/Windhoek",
            country  => "NA",
            coord    => "-2234+01706",
            comment  => "",
        },
        "America/Adak" => {
            timezone => "America/Adak",
            country  => "US",
            coord    => "+515248-1763929",
            comment  => "Aleutian Islands",
        },
        "America/Anchorage" => {
            timezone => "America/Anchorage",
            country  => "US",
            coord    => "+611305-1495401",
            comment  => "Alaska Time",
        },
        "America/Anguilla" => {
            timezone => "America/Anguilla",
            country  => "AI",
            coord    => "+1812-06304",
            comment  => "",
        },
        "America/Antigua" => {
            timezone => "America/Antigua",
            country  => "AG",
            coord    => "+1703-06148",
            comment  => "",
        },
        "America/Araguaina" => {
            timezone => "America/Araguaina",
            country  => "BR",
            coord    => "-0712-04812",
            comment  => "Tocantins",
        },
        "America/Argentina/Buenos_Aires" => {
            timezone => "America/Argentina/Buenos Aires",
            country  => "AR",
            coord    => "-3436-05827",
            comment  => "Buenos Aires (BA, CF)",
        },
        "America/Argentina/Catamarca" => {
            timezone => "America/Argentina/Catamarca",
            country  => "AR",
            coord    => "-2828-06547",
            comment  => "Catamarca (CT), Chubut (CH)",
        },
        "America/Argentina/Cordoba" => {
            timezone => "America/Argentina/Cordoba",
            country  => "AR",
            coord    => "-3124-06411",
            comment  => "most locations (CB, CC, CN, ER, FM, MN, SE, SF)",
        },
        "America/Argentina/Jujuy" => {
            timezone => "America/Argentina/Jujuy",
            country  => "AR",
            coord    => "-2411-06518",
            comment  => "Jujuy (JY)",
        },
        "America/Argentina/La_Rioja" => {
            timezone => "America/Argentina/La Rioja",
            country  => "AR",
            coord    => "-2926-06651",
            comment  => "La Rioja (LR)",
        },
        "America/Argentina/Mendoza" => {
            timezone => "America/Argentina/Mendoza",
            country  => "AR",
            coord    => "-3253-06849",
            comment  => "Mendoza (MZ)",
        },
        "America/Argentina/Rio_Gallegos" => {
            timezone => "America/Argentina/Rio Gallegos",
            country  => "AR",
            coord    => "-5138-06913",
            comment  => "Santa Cruz (SC)",
        },
        "America/Argentina/Salta" => {
            timezone => "America/Argentina/Salta",
            country  => "AR",
            coord    => "-2447-06525",
            comment  => "(SA, LP, NQ, RN)",
        },
        "America/Argentina/San_Juan" => {
            timezone => "America/Argentina/San Juan",
            country  => "AR",
            coord    => "-3132-06831",
            comment  => "San Juan (SJ)",
        },
        "America/Argentina/San_Luis" => {
            timezone => "America/Argentina/San Luis",
            country  => "AR",
            coord    => "-3319-06621",
            comment  => "San Luis (SL)",
        },
        "America/Argentina/Tucuman" => {
            timezone => "America/Argentina/Tucuman",
            country  => "AR",
            coord    => "-2649-06513",
            comment  => "Tucuman (TM)",
        },
        "America/Argentina/Ushuaia" => {
            timezone => "America/Argentina/Ushuaia",
            country  => "AR",
            coord    => "-5448-06818",
            comment  => "Tierra del Fuego (TF)",
        },
        "America/Aruba" => {
            timezone => "America/Aruba",
            country  => "AW",
            coord    => "+1230-06958",
            comment  => "",
        },
        "America/Asuncion" => {
            timezone => "America/Asuncion",
            country  => "PY",
            coord    => "-2516-05740",
            comment  => "",
        },
        "America/Atikokan" => {
            timezone => "America/Atikokan",
            country  => "CA",
            coord    => "+484531-0913718",
            comment  => "Eastern Standard Time - Atikokan, Ontario and Southampton I, Nunavut",
        },
        "America/Bahia" => {
            timezone => "America/Bahia",
            country  => "BR",
            coord    => "-1259-03831",
            comment  => "Bahia",
        },
        "America/Bahia_Banderas" => {
            timezone => "America/Bahia Banderas",
            country  => "MX",
            coord    => "+2048-10515",
            comment  => "Mexican Central Time - Bahia de Banderas",
        },
        "America/Barbados" => {
            timezone => "America/Barbados",
            country  => "BB",
            coord    => "+1306-05937",
            comment  => "",
        },
        "America/Belem" => {
            timezone => "America/Belem",
            country  => "BR",
            coord    => "-0127-04829",
            comment  => "Amapa, E Para",
        },
        "America/Belize" => {
            timezone => "America/Belize",
            country  => "BZ",
            coord    => "+1730-08812",
            comment  => "",
        },
        "America/Blanc-Sablon" => {
            timezone => "America/Blanc-Sablon",
            country  => "CA",
            coord    => "+5125-05707",
            comment  => "Atlantic Standard Time - Quebec - Lower North Shore",
        },
        "America/Boa_Vista" => {
            timezone => "America/Boa Vista",
            country  => "BR",
            coord    => "+0249-06040",
            comment  => "Roraima",
        },
        "America/Bogota" => {
            timezone => "America/Bogota",
            country  => "CO",
            coord    => "+0436-07405",
            comment  => "",
        },
        "America/Boise" => {
            timezone => "America/Boise",
            country  => "US",
            coord    => "+433649-1161209",
            comment  => "Mountain Time - south Idaho & east Oregon",
        },
        "America/Cambridge_Bay" => {
            timezone => "America/Cambridge Bay",
            country  => "CA",
            coord    => "+690650-1050310",
            comment  => "Mountain Time - west Nunavut",
        },
        "America/Campo_Grande" => {
            timezone => "America/Campo Grande",
            country  => "BR",
            coord    => "-2027-05437",
            comment  => "Mato Grosso do Sul",
        },
        "America/Cancun" => {
            timezone => "America/Cancun",
            country  => "MX",
            coord    => "+2105-08646",
            comment  => "Central Time - Quintana Roo",
        },
        "America/Caracas" => {
            timezone => "America/Caracas",
            country  => "VE",
            coord    => "+1030-06656",
            comment  => "",
        },
        "America/Cayenne" => {
            timezone => "America/Cayenne",
            country  => "GF",
            coord    => "+0456-05220",
            comment  => "",
        },
        "America/Cayman" => {
            timezone => "America/Cayman",
            country  => "KY",
            coord    => "+1918-08123",
            comment  => "",
        },
        "America/Chicago" => {
            timezone => "America/Chicago",
            country  => "US",
            coord    => "+415100-0873900",
            comment  => "Central Time",
        },
        "America/Chihuahua" => {
            timezone => "America/Chihuahua",
            country  => "MX",
            coord    => "+2838-10605",
            comment  => "Mexican Mountain Time - Chihuahua away from US border",
        },
        "America/Costa_Rica" => {
            timezone => "America/Costa Rica",
            country  => "CR",
            coord    => "+0956-08405",
            comment  => "",
        },
        "America/Cuiaba" => {
            timezone => "America/Cuiaba",
            country  => "BR",
            coord    => "-1535-05605",
            comment  => "Mato Grosso",
        },
        "America/Curacao" => {
            timezone => "America/Curacao",
            country  => "CW",
            coord    => "+1211-06900",
            comment  => "",
        },
        "America/Danmarkshavn" => {
            timezone => "America/Danmarkshavn",
            country  => "GL",
            coord    => "+7646-01840",
            comment  => "east coast, north of Scoresbysund",
        },
        "America/Dawson" => {
            timezone => "America/Dawson",
            country  => "CA",
            coord    => "+6404-13925",
            comment  => "Pacific Time - north Yukon",
        },
        "America/Dawson_Creek" => {
            timezone => "America/Dawson Creek",
            country  => "CA",
            coord    => "+5946-12014",
            comment  => "Mountain Standard Time - Dawson Creek & Fort Saint John, British Columbia",
        },
        "America/Denver" => {
            timezone => "America/Denver",
            country  => "US",
            coord    => "+394421-1045903",
            comment  => "Mountain Time",
        },
        "America/Detroit" => {
            timezone => "America/Detroit",
            country  => "US",
            coord    => "+421953-0830245",
            comment  => "Eastern Time - Michigan - most locations",
        },
        "America/Dominica" => {
            timezone => "America/Dominica",
            country  => "DM",
            coord    => "+1518-06124",
            comment  => "",
        },
        "America/Edmonton" => {
            timezone => "America/Edmonton",
            country  => "CA",
            coord    => "+5333-11328",
            comment  => "Mountain Time - Alberta, east British Columbia & west Saskatchewan",
        },
        "America/Eirunepe" => {
            timezone => "America/Eirunepe",
            country  => "BR",
            coord    => "-0640-06952",
            comment  => "W Amazonas",
        },
        "America/El_Salvador" => {
            timezone => "America/El Salvador",
            country  => "SV",
            coord    => "+1342-08912",
            comment  => "",
        },
        "America/Fortaleza" => {
            timezone => "America/Fortaleza",
            country  => "BR",
            coord    => "-0343-03830",
            comment  => "NE Brazil (MA, PI, CE, RN, PB)",
        },
        "America/Glace_Bay" => {
            timezone => "America/Glace Bay",
            country  => "CA",
            coord    => "+4612-05957",
            comment  => "Atlantic Time - Nova Scotia - places that did not observe DST 1966-1971",
        },
        "America/Godthab" => {
            timezone => "America/Godthab",
            country  => "GL",
            coord    => "+6411-05144",
            comment  => "most locations",
        },
        "America/Goose_Bay" => {
            timezone => "America/Goose Bay",
            country  => "CA",
            coord    => "+5320-06025",
            comment  => "Atlantic Time - Labrador - most locations",
        },
        "America/Grand_Turk" => {
            timezone => "America/Grand Turk",
            country  => "TC",
            coord    => "+2128-07108",
            comment  => "",
        },
        "America/Grenada" => {
            timezone => "America/Grenada",
            country  => "GD",
            coord    => "+1203-06145",
            comment  => "",
        },
        "America/Guadeloupe" => {
            timezone => "America/Guadeloupe",
            country  => "GP",
            coord    => "+1614-06132",
            comment  => "",
        },
        "America/Guatemala" => {
            timezone => "America/Guatemala",
            country  => "GT",
            coord    => "+1438-09031",
            comment  => "",
        },
        "America/Guayaquil" => {
            timezone => "America/Guayaquil",
            country  => "EC",
            coord    => "-0210-07950",
            comment  => "mainland",
        },
        "America/Guyana" => {
            timezone => "America/Guyana",
            country  => "GY",
            coord    => "+0648-05810",
            comment  => "",
        },
        "America/Halifax" => {
            timezone => "America/Halifax",
            country  => "CA",
            coord    => "+4439-06336",
            comment  => "Atlantic Time - Nova Scotia (most places), PEI",
        },
        "America/Havana" => {
            timezone => "America/Havana",
            country  => "CU",
            coord    => "+2308-08222",
            comment  => "",
        },
        "America/Hermosillo" => {
            timezone => "America/Hermosillo",
            country  => "MX",
            coord    => "+2904-11058",
            comment  => "Mountain Standard Time - Sonora",
        },
        "America/Indiana/Indianapolis" => {
            timezone => "America/Indiana/Indianapolis",
            country  => "US",
            coord    => "+394606-0860929",
            comment  => "Eastern Time - Indiana - most locations",
        },
        "America/Indiana/Knox" => {
            timezone => "America/Indiana/Knox",
            country  => "US",
            coord    => "+411745-0863730",
            comment  => "Central Time - Indiana - Starke County",
        },
        "America/Indiana/Marengo" => {
            timezone => "America/Indiana/Marengo",
            country  => "US",
            coord    => "+382232-0862041",
            comment  => "Eastern Time - Indiana - Crawford County",
        },
        "America/Indiana/Petersburg" => {
            timezone => "America/Indiana/Petersburg",
            country  => "US",
            coord    => "+382931-0871643",
            comment  => "Eastern Time - Indiana - Pike County",
        },
        "America/Indiana/Tell_City" => {
            timezone => "America/Indiana/Tell City",
            country  => "US",
            coord    => "+375711-0864541",
            comment  => "Central Time - Indiana - Perry County",
        },
        "America/Indiana/Vevay" => {
            timezone => "America/Indiana/Vevay",
            country  => "US",
            coord    => "+384452-0850402",
            comment  => "Eastern Time - Indiana - Switzerland County",
        },
        "America/Indiana/Vincennes" => {
            timezone => "America/Indiana/Vincennes",
            country  => "US",
            coord    => "+384038-0873143",
            comment  => "Eastern Time - Indiana - Daviess, Dubois, Knox & Martin Counties",
        },
        "America/Indiana/Winamac" => {
            timezone => "America/Indiana/Winamac",
            country  => "US",
            coord    => "+410305-0863611",
            comment  => "Eastern Time - Indiana - Pulaski County",
        },
        "America/Inuvik" => {
            timezone => "America/Inuvik",
            country  => "CA",
            coord    => "+682059-1334300",
            comment  => "Mountain Time - west Northwest Territories",
        },
        "America/Iqaluit" => {
            timezone => "America/Iqaluit",
            country  => "CA",
            coord    => "+6344-06828",
            comment  => "Eastern Time - east Nunavut - most locations",
        },
        "America/Jamaica" => {
            timezone => "America/Jamaica",
            country  => "JM",
            coord    => "+1800-07648",
            comment  => "",
        },
        "America/Juneau" => {
            timezone => "America/Juneau",
            country  => "US",
            coord    => "+581807-1342511",
            comment  => "Alaska Time - Alaska panhandle",
        },
        "America/Kentucky/Louisville" => {
            timezone => "America/Kentucky/Louisville",
            country  => "US",
            coord    => "+381515-0854534",
            comment  => "Eastern Time - Kentucky - Louisville area",
        },
        "America/Kentucky/Monticello" => {
            timezone => "America/Kentucky/Monticello",
            country  => "US",
            coord    => "+364947-0845057",
            comment  => "Eastern Time - Kentucky - Wayne County",
        },
        "America/Kralendijk" => {
            timezone => "America/Kralendijk",
            country  => "BQ",
            coord    => "+120903-0681636",
            comment  => "",
        },
        "America/La_Paz" => {
            timezone => "America/La Paz",
            country  => "BO",
            coord    => "-1630-06809",
            comment  => "",
        },
        "America/Lima" => {
            timezone => "America/Lima",
            country  => "PE",
            coord    => "-1203-07703",
            comment  => "",
        },
        "America/Los_Angeles" => {
            timezone => "America/Los Angeles",
            country  => "US",
            coord    => "+340308-1181434",
            comment  => "Pacific Time",
        },
        "America/Lower_Princes" => {
            timezone => "America/Lower Princes",
            country  => "SX",
            coord    => "+180305-0630250",
            comment  => "",
        },
        "America/Maceio" => {
            timezone => "America/Maceio",
            country  => "BR",
            coord    => "-0940-03543",
            comment  => "Alagoas, Sergipe",
        },
        "America/Managua" => {
            timezone => "America/Managua",
            country  => "NI",
            coord    => "+1209-08617",
            comment  => "",
        },
        "America/Manaus" => {
            timezone => "America/Manaus",
            country  => "BR",
            coord    => "-0308-06001",
            comment  => "E Amazonas",
        },
        "America/Marigot" => {
            timezone => "America/Marigot",
            country  => "MF",
            coord    => "+1804-06305",
            comment  => "",
        },
        "America/Martinique" => {
            timezone => "America/Martinique",
            country  => "MQ",
            coord    => "+1436-06105",
            comment  => "",
        },
        "America/Matamoros" => {
            timezone => "America/Matamoros",
            country  => "MX",
            coord    => "+2550-09730",
            comment  => "US Central Time - Coahuila, Durango, Nuevo Leon, Tamaulipas near US border",
        },
        "America/Mazatlan" => {
            timezone => "America/Mazatlan",
            country  => "MX",
            coord    => "+2313-10625",
            comment  => "Mountain Time - S Baja, Nayarit, Sinaloa",
        },
        "America/Menominee" => {
            timezone => "America/Menominee",
            country  => "US",
            coord    => "+450628-0873651",
            comment  => "Central Time - Michigan - Dickinson, Gogebic, Iron & Menominee Counties",
        },
        "America/Merida" => {
            timezone => "America/Merida",
            country  => "MX",
            coord    => "+2058-08937",
            comment  => "Central Time - Campeche, Yucatan",
        },
        "America/Metlakatla" => {
            timezone => "America/Metlakatla",
            country  => "US",
            coord    => "+550737-1313435",
            comment  => "Metlakatla Time - Annette Island",
        },
        "America/Mexico_City" => {
            timezone => "America/Mexico City",
            country  => "MX",
            coord    => "+1924-09909",
            comment  => "Central Time - most locations",
        },
        "America/Miquelon" => {
            timezone => "America/Miquelon",
            country  => "PM",
            coord    => "+4703-05620",
            comment  => "",
        },
        "America/Moncton" => {
            timezone => "America/Moncton",
            country  => "CA",
            coord    => "+4606-06447",
            comment  => "Atlantic Time - New Brunswick",
        },
        "America/Monterrey" => {
            timezone => "America/Monterrey",
            country  => "MX",
            coord    => "+2540-10019",
            comment  => "Mexican Central Time - Coahuila, Durango, Nuevo Leon, Tamaulipas away from US border",
        },
        "America/Montevideo" => {
            timezone => "America/Montevideo",
            country  => "UY",
            coord    => "-3453-05611",
            comment  => "",
        },
        "America/Montreal" => {
            timezone => "America/Montreal",
            country  => "CA",
            coord    => "+4531-07334",
            comment  => "Eastern Time - Quebec - most locations",
        },
        "America/Montserrat" => {
            timezone => "America/Montserrat",
            country  => "MS",
            coord    => "+1643-06213",
            comment  => "",
        },
        "America/Nassau" => {
            timezone => "America/Nassau",
            country  => "BS",
            coord    => "+2505-07721",
            comment  => "",
        },
        "America/New_York" => {
            timezone => "America/New York",
            country  => "US",
            coord    => "+404251-0740023",
            comment  => "Eastern Time",
        },
        "America/Nipigon" => {
            timezone => "America/Nipigon",
            country  => "CA",
            coord    => "+4901-08816",
            comment  => "Eastern Time - Ontario & Quebec - places that did not observe DST 1967-1973",
        },
        "America/Nome" => {
            timezone => "America/Nome",
            country  => "US",
            coord    => "+643004-1652423",
            comment  => "Alaska Time - west Alaska",
        },
        "America/Noronha" => {
            timezone => "America/Noronha",
            country  => "BR",
            coord    => "-0351-03225",
            comment  => "Atlantic islands",
        },
        "America/North_Dakota/Beulah" => {
            timezone => "America/North Dakota/Beulah",
            country  => "US",
            coord    => "+471551-1014640",
            comment  => "Central Time - North Dakota - Mercer County",
        },
        "America/North_Dakota/Center" => {
            timezone => "America/North Dakota/Center",
            country  => "US",
            coord    => "+470659-1011757",
            comment  => "Central Time - North Dakota - Oliver County",
        },
        "America/North_Dakota/New_Salem" => {
            timezone => "America/North Dakota/New Salem",
            country  => "US",
            coord    => "+465042-1012439",
            comment  => "Central Time - North Dakota - Morton County (except Mandan area)",
        },
        "America/Ojinaga" => {
            timezone => "America/Ojinaga",
            country  => "MX",
            coord    => "+2934-10425",
            comment  => "US Mountain Time - Chihuahua near US border",
        },
        "America/Panama" => {
            timezone => "America/Panama",
            country  => "PA",
            coord    => "+0858-07932",
            comment  => "",
        },
        "America/Pangnirtung" => {
            timezone => "America/Pangnirtung",
            country  => "CA",
            coord    => "+6608-06544",
            comment  => "Eastern Time - Pangnirtung, Nunavut",
        },
        "America/Paramaribo" => {
            timezone => "America/Paramaribo",
            country  => "SR",
            coord    => "+0550-05510",
            comment  => "",
        },
        "America/Phoenix" => {
            timezone => "America/Phoenix",
            country  => "US",
            coord    => "+332654-1120424",
            comment  => "Mountain Standard Time - Arizona",
        },
        "America/Port-au-Prince" => {
            timezone => "America/Port-au-Prince",
            country  => "HT",
            coord    => "+1832-07220",
            comment  => "",
        },
        "America/Port_of_Spain" => {
            timezone => "America/Port of Spain",
            country  => "TT",
            coord    => "+1039-06131",
            comment  => "",
        },
        "America/Porto_Velho" => {
            timezone => "America/Porto Velho",
            country  => "BR",
            coord    => "-0846-06354",
            comment  => "Rondonia",
        },
        "America/Puerto_Rico" => {
            timezone => "America/Puerto Rico",
            country  => "PR",
            coord    => "+182806-0660622",
            comment  => "",
        },
        "America/Rainy_River" => {
            timezone => "America/Rainy River",
            country  => "CA",
            coord    => "+4843-09434",
            comment  => "Central Time - Rainy River & Fort Frances, Ontario",
        },
        "America/Rankin_Inlet" => {
            timezone => "America/Rankin Inlet",
            country  => "CA",
            coord    => "+624900-0920459",
            comment  => "Central Time - central Nunavut",
        },
        "America/Recife" => {
            timezone => "America/Recife",
            country  => "BR",
            coord    => "-0803-03454",
            comment  => "Pernambuco",
        },
        "America/Regina" => {
            timezone => "America/Regina",
            country  => "CA",
            coord    => "+5024-10439",
            comment  => "Central Standard Time - Saskatchewan - most locations",
        },
        "America/Resolute" => {
            timezone => "America/Resolute",
            country  => "CA",
            coord    => "+744144-0944945",
            comment  => "Eastern Standard Time - Resolute, Nunavut",
        },
        "America/Rio_Branco" => {
            timezone => "America/Rio Branco",
            country  => "BR",
            coord    => "-0958-06748",
            comment  => "Acre",
        },
        "America/Santa_Isabel" => {
            timezone => "America/Santa Isabel",
            country  => "MX",
            coord    => "+3018-11452",
            comment  => "Mexican Pacific Time - Baja California away from US border",
        },
        "America/Santarem" => {
            timezone => "America/Santarem",
            country  => "BR",
            coord    => "-0226-05452",
            comment  => "W Para",
        },
        "America/Santiago" => {
            timezone => "America/Santiago",
            country  => "CL",
            coord    => "-3327-07040",
            comment  => "most locations",
        },
        "America/Santo_Domingo" => {
            timezone => "America/Santo Domingo",
            country  => "DO",
            coord    => "+1828-06954",
            comment  => "",
        },
        "America/Sao_Paulo" => {
            timezone => "America/Sao Paulo",
            country  => "BR",
            coord    => "-2332-04637",
            comment  => "S & SE Brazil (GO, DF, MG, ES, RJ, SP, PR, SC, RS)",
        },
        "America/Scoresbysund" => {
            timezone => "America/Scoresbysund",
            country  => "GL",
            coord    => "+7029-02158",
            comment  => "Scoresbysund / Ittoqqortoormiit",
        },
        "America/Shiprock" => {
            timezone => "America/Shiprock",
            country  => "US",
            coord    => "+364708-1084111",
            comment  => "Mountain Time - Navajo",
        },
        "America/Sitka" => {
            timezone => "America/Sitka",
            country  => "US",
            coord    => "+571035-1351807",
            comment  => "Alaska Time - southeast Alaska panhandle",
        },
        "America/St_Barthelemy" => {
            timezone => "America/St Barthelemy",
            country  => "BL",
            coord    => "+1753-06251",
            comment  => "",
        },
        "America/St_Johns" => {
            timezone => "America/St Johns",
            country  => "CA",
            coord    => "+4734-05243",
            comment  => "Newfoundland Time, including SE Labrador",
        },
        "America/St_Kitts" => {
            timezone => "America/St Kitts",
            country  => "KN",
            coord    => "+1718-06243",
            comment  => "",
        },
        "America/St_Lucia" => {
            timezone => "America/St Lucia",
            country  => "LC",
            coord    => "+1401-06100",
            comment  => "",
        },
        "America/St_Thomas" => {
            timezone => "America/St Thomas",
            country  => "VI",
            coord    => "+1821-06456",
            comment  => "",
        },
        "America/St_Vincent" => {
            timezone => "America/St Vincent",
            country  => "VC",
            coord    => "+1309-06114",
            comment  => "",
        },
        "America/Swift_Current" => {
            timezone => "America/Swift Current",
            country  => "CA",
            coord    => "+5017-10750",
            comment  => "Central Standard Time - Saskatchewan - midwest",
        },
        "America/Tegucigalpa" => {
            timezone => "America/Tegucigalpa",
            country  => "HN",
            coord    => "+1406-08713",
            comment  => "",
        },
        "America/Thule" => {
            timezone => "America/Thule",
            country  => "GL",
            coord    => "+7634-06847",
            comment  => "Thule / Pituffik",
        },
        "America/Thunder_Bay" => {
            timezone => "America/Thunder Bay",
            country  => "CA",
            coord    => "+4823-08915",
            comment  => "Eastern Time - Thunder Bay, Ontario",
        },
        "America/Tijuana" => {
            timezone => "America/Tijuana",
            country  => "MX",
            coord    => "+3232-11701",
            comment  => "US Pacific Time - Baja California near US border",
        },
        "America/Toronto" => {
            timezone => "America/Toronto",
            country  => "CA",
            coord    => "+4339-07923",
            comment  => "Eastern Time - Ontario - most locations",
        },
        "America/Tortola" => {
            timezone => "America/Tortola",
            country  => "VG",
            coord    => "+1827-06437",
            comment  => "",
        },
        "America/Vancouver" => {
            timezone => "America/Vancouver",
            country  => "CA",
            coord    => "+4916-12307",
            comment  => "Pacific Time - west British Columbia",
        },
        "America/Whitehorse" => {
            timezone => "America/Whitehorse",
            country  => "CA",
            coord    => "+6043-13503",
            comment  => "Pacific Time - south Yukon",
        },
        "America/Winnipeg" => {
            timezone => "America/Winnipeg",
            country  => "CA",
            coord    => "+4953-09709",
            comment  => "Central Time - Manitoba & west Ontario",
        },
        "America/Yakutat" => {
            timezone => "America/Yakutat",
            country  => "US",
            coord    => "+593249-1394338",
            comment  => "Alaska Time - Alaska panhandle neck",
        },
        "America/Yellowknife" => {
            timezone => "America/Yellowknife",
            country  => "CA",
            coord    => "+6227-11421",
            comment  => "Mountain Time - central Northwest Territories",
        },
        "Antarctica/Casey" => {
            timezone => "Antarctica/Casey",
            country  => "AQ",
            coord    => "-6617+11031",
            comment  => "Casey Station, Bailey Peninsula",
        },
        "Antarctica/Davis" => {
            timezone => "Antarctica/Davis",
            country  => "AQ",
            coord    => "-6835+07758",
            comment  => "Davis Station, Vestfold Hills",
        },
        "Antarctica/DumontDUrville" => {
            timezone => "Antarctica/DumontDUrville",
            country  => "AQ",
            coord    => "-6640+14001",
            comment  => "Dumont-d'Urville Station, Terre Adelie",
        },
        "Antarctica/Macquarie" => {
            timezone => "Antarctica/Macquarie",
            country  => "AQ",
            coord    => "-5430+15857",
            comment  => "Macquarie Island Station, Macquarie Island",
        },
        "Antarctica/Mawson" => {
            timezone => "Antarctica/Mawson",
            country  => "AQ",
            coord    => "-6736+06253",
            comment  => "Mawson Station, Holme Bay",
        },
        "Antarctica/McMurdo" => {
            timezone => "Antarctica/McMurdo",
            country  => "AQ",
            coord    => "-7750+16636",
            comment  => "McMurdo Station, Ross Island",
        },
        "Antarctica/Palmer" => {
            timezone => "Antarctica/Palmer",
            country  => "AQ",
            coord    => "-6448-06406",
            comment  => "Palmer Station, Anvers Island",
        },
        "Antarctica/Rothera" => {
            timezone => "Antarctica/Rothera",
            country  => "AQ",
            coord    => "-6734-06808",
            comment  => "Rothera Station, Adelaide Island",
        },
        "Antarctica/South_Pole" => {
            timezone => "Antarctica/South Pole",
            country  => "AQ",
            coord    => "-9000+00000",
            comment  => "Amundsen-Scott Station, South Pole",
        },
        "Antarctica/Syowa" => {
            timezone => "Antarctica/Syowa",
            country  => "AQ",
            coord    => "-690022+0393524",
            comment  => "Syowa Station, E Ongul I",
        },
        "Antarctica/Vostok" => {
            timezone => "Antarctica/Vostok",
            country  => "AQ",
            coord    => "-7824+10654",
            comment  => "Vostok Station, Lake Vostok",
        },
        "Arctic/Longyearbyen" => {
            timezone => "Arctic/Longyearbyen",
            country  => "SJ",
            coord    => "+7800+01600",
            comment  => "",
        },
        "Asia/Aden" => {
            timezone => "Asia/Aden",
            country  => "YE",
            coord    => "+1245+04512",
            comment  => "",
        },
        "Asia/Almaty" => {
            timezone => "Asia/Almaty",
            country  => "KZ",
            coord    => "+4315+07657",
            comment  => "most locations",
        },
        "Asia/Amman" => {
            timezone => "Asia/Amman",
            country  => "JO",
            coord    => "+3157+03556",
            comment  => "",
        },
        "Asia/Anadyr" => {
            timezone => "Asia/Anadyr",
            country  => "RU",
            coord    => "+6445+17729",
            comment  => "Moscow+08 - Bering Sea",
        },
        "Asia/Aqtau" => {
            timezone => "Asia/Aqtau",
            country  => "KZ",
            coord    => "+4431+05016",
            comment  => "Atyrau (Atirau, Gur'yev), Mangghystau (Mankistau)",
        },
        "Asia/Aqtobe" => {
            timezone => "Asia/Aqtobe",
            country  => "KZ",
            coord    => "+5017+05710",
            comment  => "Aqtobe (Aktobe)",
        },
        "Asia/Ashgabat" => {
            timezone => "Asia/Ashgabat",
            country  => "TM",
            coord    => "+3757+05823",
            comment  => "",
        },
        "Asia/Baghdad" => {
            timezone => "Asia/Baghdad",
            country  => "IQ",
            coord    => "+3321+04425",
            comment  => "",
        },
        "Asia/Bahrain" => {
            timezone => "Asia/Bahrain",
            country  => "BH",
            coord    => "+2623+05035",
            comment  => "",
        },
        "Asia/Baku" => {
            timezone => "Asia/Baku",
            country  => "AZ",
            coord    => "+4023+04951",
            comment  => "",
        },
        "Asia/Bangkok" => {
            timezone => "Asia/Bangkok",
            country  => "TH",
            coord    => "+1345+10031",
            comment  => "",
        },
        "Asia/Beirut" => {
            timezone => "Asia/Beirut",
            country  => "LB",
            coord    => "+3353+03530",
            comment  => "",
        },
        "Asia/Bishkek" => {
            timezone => "Asia/Bishkek",
            country  => "KG",
            coord    => "+4254+07436",
            comment  => "",
        },
        "Asia/Brunei" => {
            timezone => "Asia/Brunei",
            country  => "BN",
            coord    => "+0456+11455",
            comment  => "",
        },
        "Asia/Choibalsan" => {
            timezone => "Asia/Choibalsan",
            country  => "MN",
            coord    => "+4804+11430",
            comment  => "Dornod, Sukhbaatar",
        },
        "Asia/Chongqing" => {
            timezone => "Asia/Chongqing",
            country  => "CN",
            coord    => "+2934+10635",
            comment  => "central China - Sichuan, Yunnan, Guangxi, Shaanxi, Guizhou, etc.",
        },
        "Asia/Colombo" => {
            timezone => "Asia/Colombo",
            country  => "LK",
            coord    => "+0656+07951",
            comment  => "",
        },
        "Asia/Damascus" => {
            timezone => "Asia/Damascus",
            country  => "SY",
            coord    => "+3330+03618",
            comment  => "",
        },
        "Asia/Dhaka" => {
            timezone => "Asia/Dhaka",
            country  => "BD",
            coord    => "+2343+09025",
            comment  => "",
        },
        "Asia/Dili" => {
            timezone => "Asia/Dili",
            country  => "TL",
            coord    => "-0833+12535",
            comment  => "",
        },
        "Asia/Dubai" => {
            timezone => "Asia/Dubai",
            country  => "AE",
            coord    => "+2518+05518",
            comment  => "",
        },
        "Asia/Dushanbe" => {
            timezone => "Asia/Dushanbe",
            country  => "TJ",
            coord    => "+3835+06848",
            comment  => "",
        },
        "Asia/Gaza" => {
            timezone => "Asia/Gaza",
            country  => "PS",
            coord    => "+3130+03428",
            comment  => "",
        },
        "Asia/Harbin" => {
            timezone => "Asia/Harbin",
            country  => "CN",
            coord    => "+4545+12641",
            comment  => "Heilongjiang (except Mohe), Jilin",
        },
        "Asia/Ho_Chi_Minh" => {
            timezone => "Asia/Ho Chi Minh",
            country  => "VN",
            coord    => "+1045+10640",
            comment  => "",
        },
        "Asia/Hong_Kong" => {
            timezone => "Asia/Hong Kong",
            country  => "HK",
            coord    => "+2217+11409",
            comment  => "",
        },
        "Asia/Hovd" => {
            timezone => "Asia/Hovd",
            country  => "MN",
            coord    => "+4801+09139",
            comment  => "Bayan-Olgiy, Govi-Altai, Hovd, Uvs, Zavkhan",
        },
        "Asia/Irkutsk" => {
            timezone => "Asia/Irkutsk",
            country  => "RU",
            coord    => "+5216+10420",
            comment  => "Moscow+05 - Lake Baikal",
        },
        "Asia/Jakarta" => {
            timezone => "Asia/Jakarta",
            country  => "ID",
            coord    => "-0610+10648",
            comment  => "Java & Sumatra",
        },
        "Asia/Jayapura" => {
            timezone => "Asia/Jayapura",
            country  => "ID",
            coord    => "-0232+14042",
            comment  => "west New Guinea (Irian Jaya) & Malukus (Moluccas)",
        },
        "Asia/Jerusalem" => {
            timezone => "Asia/Jerusalem",
            country  => "IL",
            coord    => "+3146+03514",
            comment  => "",
        },
        "Asia/Kabul" => {
            timezone => "Asia/Kabul",
            country  => "AF",
            coord    => "+3431+06912",
            comment  => "",
        },
        "Asia/Kamchatka" => {
            timezone => "Asia/Kamchatka",
            country  => "RU",
            coord    => "+5301+15839",
            comment  => "Moscow+08 - Kamchatka",
        },
        "Asia/Karachi" => {
            timezone => "Asia/Karachi",
            country  => "PK",
            coord    => "+2452+06703",
            comment  => "",
        },
        "Asia/Kashgar" => {
            timezone => "Asia/Kashgar",
            country  => "CN",
            coord    => "+3929+07559",
            comment  => "west Tibet & Xinjiang",
        },
        "Asia/Kathmandu" => {
            timezone => "Asia/Kathmandu",
            country  => "NP",
            coord    => "+2743+08519",
            comment  => "",
        },
        "Asia/Kolkata" => {
            timezone => "Asia/Kolkata",
            country  => "IN",
            coord    => "+2232+08822",
            comment  => "",
        },
        "Asia/Krasnoyarsk" => {
            timezone => "Asia/Krasnoyarsk",
            country  => "RU",
            coord    => "+5601+09250",
            comment  => "Moscow+04 - Yenisei River",
        },
        "Asia/Kuala_Lumpur" => {
            timezone => "Asia/Kuala Lumpur",
            country  => "MY",
            coord    => "+0310+10142",
            comment  => "peninsular Malaysia",
        },
        "Asia/Kuching" => {
            timezone => "Asia/Kuching",
            country  => "MY",
            coord    => "+0133+11020",
            comment  => "Sabah & Sarawak",
        },
        "Asia/Kuwait" => {
            timezone => "Asia/Kuwait",
            country  => "KW",
            coord    => "+2920+04759",
            comment  => "",
        },
        "Asia/Macau" => {
            timezone => "Asia/Macau",
            country  => "MO",
            coord    => "+2214+11335",
            comment  => "",
        },
        "Asia/Magadan" => {
            timezone => "Asia/Magadan",
            country  => "RU",
            coord    => "+5934+15048",
            comment  => "Moscow+08 - Magadan",
        },
        "Asia/Makassar" => {
            timezone => "Asia/Makassar",
            country  => "ID",
            coord    => "-0507+11924",
            comment  => "east & south Borneo, Sulawesi (Celebes), Bali, Nusa Tengarra, west Timor",
        },
        "Asia/Manila" => {
            timezone => "Asia/Manila",
            country  => "PH",
            coord    => "+1435+12100",
            comment  => "",
        },
        "Asia/Muscat" => {
            timezone => "Asia/Muscat",
            country  => "OM",
            coord    => "+2336+05835",
            comment  => "",
        },
        "Asia/Nicosia" => {
            timezone => "Asia/Nicosia",
            country  => "CY",
            coord    => "+3510+03322",
            comment  => "",
        },
        "Asia/Novokuznetsk" => {
            timezone => "Asia/Novokuznetsk",
            country  => "RU",
            coord    => "+5345+08707",
            comment  => "Moscow+03 - Novokuznetsk",
        },
        "Asia/Novosibirsk" => {
            timezone => "Asia/Novosibirsk",
            country  => "RU",
            coord    => "+5502+08255",
            comment  => "Moscow+03 - Novosibirsk",
        },
        "Asia/Omsk" => {
            timezone => "Asia/Omsk",
            country  => "RU",
            coord    => "+5500+07324",
            comment  => "Moscow+03 - west Siberia",
        },
        "Asia/Oral" => {
            timezone => "Asia/Oral",
            country  => "KZ",
            coord    => "+5113+05121",
            comment  => "West Kazakhstan",
        },
        "Asia/Phnom_Penh" => {
            timezone => "Asia/Phnom Penh",
            country  => "KH",
            coord    => "+1133+10455",
            comment  => "",
        },
        "Asia/Pontianak" => {
            timezone => "Asia/Pontianak",
            country  => "ID",
            coord    => "-0002+10920",
            comment  => "west & central Borneo",
        },
        "Asia/Pyongyang" => {
            timezone => "Asia/Pyongyang",
            country  => "KP",
            coord    => "+3901+12545",
            comment  => "",
        },
        "Asia/Qatar" => {
            timezone => "Asia/Qatar",
            country  => "QA",
            coord    => "+2517+05132",
            comment  => "",
        },
        "Asia/Qyzylorda" => {
            timezone => "Asia/Qyzylorda",
            country  => "KZ",
            coord    => "+4448+06528",
            comment  => "Qyzylorda (Kyzylorda, Kzyl-Orda)",
        },
        "Asia/Rangoon" => {
            timezone => "Asia/Rangoon",
            country  => "MM",
            coord    => "+1647+09610",
            comment  => "",
        },
        "Asia/Riyadh" => {
            timezone => "Asia/Riyadh",
            country  => "SA",
            coord    => "+2438+04643",
            comment  => "",
        },
        "Asia/Sakhalin" => {
            timezone => "Asia/Sakhalin",
            country  => "RU",
            coord    => "+4658+14242",
            comment  => "Moscow+07 - Sakhalin Island",
        },
        "Asia/Samarkand" => {
            timezone => "Asia/Samarkand",
            country  => "UZ",
            coord    => "+3940+06648",
            comment  => "west Uzbekistan",
        },
        "Asia/Seoul" => {
            timezone => "Asia/Seoul",
            country  => "KR",
            coord    => "+3733+12658",
            comment  => "",
        },
        "Asia/Shanghai" => {
            timezone => "Asia/Shanghai",
            country  => "CN",
            coord    => "+3114+12128",
            comment  => "east China - Beijing, Guangdong, Shanghai, etc.",
        },
        "Asia/Singapore" => {
            timezone => "Asia/Singapore",
            country  => "SG",
            coord    => "+0117+10351",
            comment  => "",
        },
        "Asia/Taipei" => {
            timezone => "Asia/Taipei",
            country  => "TW",
            coord    => "+2503+12130",
            comment  => "",
        },
        "Asia/Tashkent" => {
            timezone => "Asia/Tashkent",
            country  => "UZ",
            coord    => "+4120+06918",
            comment  => "east Uzbekistan",
        },
        "Asia/Tbilisi" => {
            timezone => "Asia/Tbilisi",
            country  => "GE",
            coord    => "+4143+04449",
            comment  => "",
        },
        "Asia/Tehran" => {
            timezone => "Asia/Tehran",
            country  => "IR",
            coord    => "+3540+05126",
            comment  => "",
        },
        "Asia/Thimphu" => {
            timezone => "Asia/Thimphu",
            country  => "BT",
            coord    => "+2728+08939",
            comment  => "",
        },
        "Asia/Tokyo" => {
            timezone => "Asia/Tokyo",
            country  => "JP",
            coord    => "+353916+1394441",
            comment  => "",
        },
        "Asia/Ulaanbaatar" => {
            timezone => "Asia/Ulaanbaatar",
            country  => "MN",
            coord    => "+4755+10653",
            comment  => "most locations",
        },
        "Asia/Urumqi" => {
            timezone => "Asia/Urumqi",
            country  => "CN",
            coord    => "+4348+08735",
            comment  => "most of Tibet & Xinjiang",
        },
        "Asia/Vientiane" => {
            timezone => "Asia/Vientiane",
            country  => "LA",
            coord    => "+1758+10236",
            comment  => "",
        },
        "Asia/Vladivostok" => {
            timezone => "Asia/Vladivostok",
            country  => "RU",
            coord    => "+4310+13156",
            comment  => "Moscow+07 - Amur River",
        },
        "Asia/Yakutsk" => {
            timezone => "Asia/Yakutsk",
            country  => "RU",
            coord    => "+6200+12940",
            comment  => "Moscow+06 - Lena River",
        },
        "Asia/Yekaterinburg" => {
            timezone => "Asia/Yekaterinburg",
            country  => "RU",
            coord    => "+5651+06036",
            comment  => "Moscow+02 - Urals",
        },
        "Asia/Yerevan" => {
            timezone => "Asia/Yerevan",
            country  => "AM",
            coord    => "+4011+04430",
            comment  => "",
        },
        "Atlantic/Azores" => {
            timezone => "Atlantic/Azores",
            country  => "PT",
            coord    => "+3744-02540",
            comment  => "Azores",
        },
        "Atlantic/Bermuda" => {
            timezone => "Atlantic/Bermuda",
            country  => "BM",
            coord    => "+3217-06446",
            comment  => "",
        },
        "Atlantic/Canary" => {
            timezone => "Atlantic/Canary",
            country  => "ES",
            coord    => "+2806-01524",
            comment  => "Canary Islands",
        },
        "Atlantic/Cape_Verde" => {
            timezone => "Atlantic/Cape Verde",
            country  => "CV",
            coord    => "+1455-02331",
            comment  => "",
        },
        "Atlantic/Faroe" => {
            timezone => "Atlantic/Faroe",
            country  => "FO",
            coord    => "+6201-00646",
            comment  => "",
        },
        "Atlantic/Madeira" => {
            timezone => "Atlantic/Madeira",
            country  => "PT",
            coord    => "+3238-01654",
            comment  => "Madeira Islands",
        },
        "Atlantic/Reykjavik" => {
            timezone => "Atlantic/Reykjavik",
            country  => "IS",
            coord    => "+6409-02151",
            comment  => "",
        },
        "Atlantic/South_Georgia" => {
            timezone => "Atlantic/South Georgia",
            country  => "GS",
            coord    => "-5416-03632",
            comment  => "",
        },
        "Atlantic/St_Helena" => {
            timezone => "Atlantic/St Helena",
            country  => "SH",
            coord    => "-1555-00542",
            comment  => "",
        },
        "Atlantic/Stanley" => {
            timezone => "Atlantic/Stanley",
            country  => "FK",
            coord    => "-5142-05751",
            comment  => "",
        },
        "Australia/Adelaide" => {
            timezone => "Australia/Adelaide",
            country  => "AU",
            coord    => "-3455+13835",
            comment  => "South Australia",
        },
        "Australia/Brisbane" => {
            timezone => "Australia/Brisbane",
            country  => "AU",
            coord    => "-2728+15302",
            comment  => "Queensland - most locations",
        },
        "Australia/Broken_Hill" => {
            timezone => "Australia/Broken Hill",
            country  => "AU",
            coord    => "-3157+14127",
            comment  => "New South Wales - Yancowinna",
        },
        "Australia/Currie" => {
            timezone => "Australia/Currie",
            country  => "AU",
            coord    => "-3956+14352",
            comment  => "Tasmania - King Island",
        },
        "Australia/Darwin" => {
            timezone => "Australia/Darwin",
            country  => "AU",
            coord    => "-1228+13050",
            comment  => "Northern Territory",
        },
        "Australia/Eucla" => {
            timezone => "Australia/Eucla",
            country  => "AU",
            coord    => "-3143+12852",
            comment  => "Western Australia - Eucla area",
        },
        "Australia/Hobart" => {
            timezone => "Australia/Hobart",
            country  => "AU",
            coord    => "-4253+14719",
            comment  => "Tasmania - most locations",
        },
        "Australia/Lindeman" => {
            timezone => "Australia/Lindeman",
            country  => "AU",
            coord    => "-2016+14900",
            comment  => "Queensland - Holiday Islands",
        },
        "Australia/Lord_Howe" => {
            timezone => "Australia/Lord Howe",
            country  => "AU",
            coord    => "-3133+15905",
            comment  => "Lord Howe Island",
        },
        "Australia/Melbourne" => {
            timezone => "Australia/Melbourne",
            country  => "AU",
            coord    => "-3749+14458",
            comment  => "Victoria",
        },
        "Australia/Perth" => {
            timezone => "Australia/Perth",
            country  => "AU",
            coord    => "-3157+11551",
            comment  => "Western Australia - most locations",
        },
        "Australia/Sydney" => {
            timezone => "Australia/Sydney",
            country  => "AU",
            coord    => "-3352+15113",
            comment  => "New South Wales - most locations",
        },
        "Europe/Amsterdam" => {
            timezone => "Europe/Amsterdam",
            country  => "NL",
            coord    => "+5222+00454",
            comment  => "",
        },
        "Europe/Andorra" => {
            timezone => "Europe/Andorra",
            country  => "AD",
            coord    => "+4230+00131",
            comment  => "",
        },
        "Europe/Athens" => {
            timezone => "Europe/Athens",
            country  => "GR",
            coord    => "+3758+02343",
            comment  => "",
        },
        "Europe/Belgrade" => {
            timezone => "Europe/Belgrade",
            country  => "RS",
            coord    => "+4450+02030",
            comment  => "",
        },
        "Europe/Berlin" => {
            timezone => "Europe/Berlin",
            country  => "DE",
            coord    => "+5230+01322",
            comment  => "",
        },
        "Europe/Bratislava" => {
            timezone => "Europe/Bratislava",
            country  => "SK",
            coord    => "+4809+01707",
            comment  => "",
        },
        "Europe/Brussels" => {
            timezone => "Europe/Brussels",
            country  => "BE",
            coord    => "+5050+00420",
            comment  => "",
        },
        "Europe/Bucharest" => {
            timezone => "Europe/Bucharest",
            country  => "RO",
            coord    => "+4426+02606",
            comment  => "",
        },
        "Europe/Budapest" => {
            timezone => "Europe/Budapest",
            country  => "HU",
            coord    => "+4730+01905",
            comment  => "",
        },
        "Europe/Chisinau" => {
            timezone => "Europe/Chisinau",
            country  => "MD",
            coord    => "+4700+02850",
            comment  => "",
        },
        "Europe/Copenhagen" => {
            timezone => "Europe/Copenhagen",
            country  => "DK",
            coord    => "+5540+01235",
            comment  => "",
        },
        "Europe/Dublin" => {
            timezone => "Europe/Dublin",
            country  => "IE",
            coord    => "+5320-00615",
            comment  => "",
        },
        "Europe/Gibraltar" => {
            timezone => "Europe/Gibraltar",
            country  => "GI",
            coord    => "+3608-00521",
            comment  => "",
        },
        "Europe/Guernsey" => {
            timezone => "Europe/Guernsey",
            country  => "GG",
            coord    => "+4927-00232",
            comment  => "",
        },
        "Europe/Helsinki" => {
            timezone => "Europe/Helsinki",
            country  => "FI",
            coord    => "+6010+02458",
            comment  => "",
        },
        "Europe/Isle_of_Man" => {
            timezone => "Europe/Isle of Man",
            country  => "IM",
            coord    => "+5409-00428",
            comment  => "",
        },
        "Europe/Istanbul" => {
            timezone => "Europe/Istanbul",
            country  => "TR",
            coord    => "+4101+02858",
            comment  => "",
        },
        "Europe/Jersey" => {
            timezone => "Europe/Jersey",
            country  => "JE",
            coord    => "+4912-00207",
            comment  => "",
        },
        "Europe/Kaliningrad" => {
            timezone => "Europe/Kaliningrad",
            country  => "RU",
            coord    => "+5443+02030",
            comment  => "Moscow-01 - Kaliningrad",
        },
        "Europe/Kiev" => {
            timezone => "Europe/Kiev",
            country  => "UA",
            coord    => "+5026+03031",
            comment  => "most locations",
        },
        "Europe/Lisbon" => {
            timezone => "Europe/Lisbon",
            country  => "PT",
            coord    => "+3843-00908",
            comment  => "mainland",
        },
        "Europe/Ljubljana" => {
            timezone => "Europe/Ljubljana",
            country  => "SI",
            coord    => "+4603+01431",
            comment  => "",
        },
        "Europe/London" => {
            timezone => "Europe/London",
            country  => "GB",
            coord    => "+513030-0000731",
            comment  => "",
        },
        "Europe/Luxembourg" => {
            timezone => "Europe/Luxembourg",
            country  => "LU",
            coord    => "+4936+00609",
            comment  => "",
        },
        "Europe/Madrid" => {
            timezone => "Europe/Madrid",
            country  => "ES",
            coord    => "+4024-00341",
            comment  => "mainland",
        },
        "Europe/Malta" => {
            timezone => "Europe/Malta",
            country  => "MT",
            coord    => "+3554+01431",
            comment  => "",
        },
        "Europe/Mariehamn" => {
            timezone => "Europe/Mariehamn",
            country  => "AX",
            coord    => "+6006+01957",
            comment  => "",
        },
        "Europe/Minsk" => {
            timezone => "Europe/Minsk",
            country  => "BY",
            coord    => "+5354+02734",
            comment  => "",
        },
        "Europe/Monaco" => {
            timezone => "Europe/Monaco",
            country  => "MC",
            coord    => "+4342+00723",
            comment  => "",
        },
        "Europe/Moscow" => {
            timezone => "Europe/Moscow",
            country  => "RU",
            coord    => "+5545+03735",
            comment  => "Moscow+00 - west Russia",
        },
        "Europe/Oslo" => {
            timezone => "Europe/Oslo",
            country  => "NO",
            coord    => "+5955+01045",
            comment  => "",
        },
        "Europe/Paris" => {
            timezone => "Europe/Paris",
            country  => "FR",
            coord    => "+4852+00220",
            comment  => "",
        },
        "Europe/Podgorica" => {
            timezone => "Europe/Podgorica",
            country  => "ME",
            coord    => "+4226+01916",
            comment  => "",
        },
        "Europe/Prague" => {
            timezone => "Europe/Prague",
            country  => "CZ",
            coord    => "+5005+01426",
            comment  => "",
        },
        "Europe/Riga" => {
            timezone => "Europe/Riga",
            country  => "LV",
            coord    => "+5657+02406",
            comment  => "",
        },
        "Europe/Rome" => {
            timezone => "Europe/Rome",
            country  => "IT",
            coord    => "+4154+01229",
            comment  => "",
        },
        "Europe/Samara" => {
            timezone => "Europe/Samara",
            country  => "RU",
            coord    => "+5312+05009",
            comment  => "Moscow - Samara, Udmurtia",
        },
        "Europe/San_Marino" => {
            timezone => "Europe/San Marino",
            country  => "SM",
            coord    => "+4355+01228",
            comment  => "",
        },
        "Europe/Sarajevo" => {
            timezone => "Europe/Sarajevo",
            country  => "BA",
            coord    => "+4352+01825",
            comment  => "",
        },
        "Europe/Simferopol" => {
            timezone => "Europe/Simferopol",
            country  => "UA",
            coord    => "+4457+03406",
            comment  => "central Crimea",
        },
        "Europe/Skopje" => {
            timezone => "Europe/Skopje",
            country  => "MK",
            coord    => "+4159+02126",
            comment  => "",
        },
        "Europe/Sofia" => {
            timezone => "Europe/Sofia",
            country  => "BG",
            coord    => "+4241+02319",
            comment  => "",
        },
        "Europe/Stockholm" => {
            timezone => "Europe/Stockholm",
            country  => "SE",
            coord    => "+5920+01803",
            comment  => "",
        },
        "Europe/Tallinn" => {
            timezone => "Europe/Tallinn",
            country  => "EE",
            coord    => "+5925+02445",
            comment  => "",
        },
        "Europe/Tirane" => {
            timezone => "Europe/Tirane",
            country  => "AL",
            coord    => "+4120+01950",
            comment  => "",
        },
        "Europe/Uzhgorod" => {
            timezone => "Europe/Uzhgorod",
            country  => "UA",
            coord    => "+4837+02218",
            comment  => "Ruthenia",
        },
        "Europe/Vaduz" => {
            timezone => "Europe/Vaduz",
            country  => "LI",
            coord    => "+4709+00931",
            comment  => "",
        },
        "Europe/Vatican" => {
            timezone => "Europe/Vatican",
            country  => "VA",
            coord    => "+415408+0122711",
            comment  => "",
        },
        "Europe/Vienna" => {
            timezone => "Europe/Vienna",
            country  => "AT",
            coord    => "+4813+01620",
            comment  => "",
        },
        "Europe/Vilnius" => {
            timezone => "Europe/Vilnius",
            country  => "LT",
            coord    => "+5441+02519",
            comment  => "",
        },
        "Europe/Volgograd" => {
            timezone => "Europe/Volgograd",
            country  => "RU",
            coord    => "+4844+04425",
            comment  => "Moscow+00 - Caspian Sea",
        },
        "Europe/Warsaw" => {
            timezone => "Europe/Warsaw",
            country  => "PL",
            coord    => "+5215+02100",
            comment  => "",
        },
        "Europe/Zagreb" => {
            timezone => "Europe/Zagreb",
            country  => "HR",
            coord    => "+4548+01558",
            comment  => "",
        },
        "Europe/Zaporozhye" => {
            timezone => "Europe/Zaporozhye",
            country  => "UA",
            coord    => "+4750+03510",
            comment  => "Zaporozh'ye, E Lugansk / Zaporizhia, E Luhansk",
        },
        "Europe/Zurich" => {
            timezone => "Europe/Zurich",
            country  => "CH",
            coord    => "+4723+00832",
            comment  => "",
        },
        "Indian/Antananarivo" => {
            timezone => "Indian/Antananarivo",
            country  => "MG",
            coord    => "-1855+04731",
            comment  => "",
        },
        "Indian/Chagos" => {
            timezone => "Indian/Chagos",
            country  => "IO",
            coord    => "-0720+07225",
            comment  => "",
        },
        "Indian/Christmas" => {
            timezone => "Indian/Christmas",
            country  => "CX",
            coord    => "-1025+10543",
            comment  => "",
        },
        "Indian/Cocos" => {
            timezone => "Indian/Cocos",
            country  => "CC",
            coord    => "-1210+09655",
            comment  => "",
        },
        "Indian/Comoro" => {
            timezone => "Indian/Comoro",
            country  => "KM",
            coord    => "-1141+04316",
            comment  => "",
        },
        "Indian/Kerguelen" => {
            timezone => "Indian/Kerguelen",
            country  => "TF",
            coord    => "-492110+0701303",
            comment  => "",
        },
        "Indian/Mahe" => {
            timezone => "Indian/Mahe",
            country  => "SC",
            coord    => "-0440+05528",
            comment  => "",
        },
        "Indian/Maldives" => {
            timezone => "Indian/Maldives",
            country  => "MV",
            coord    => "+0410+07330",
            comment  => "",
        },
        "Indian/Mauritius" => {
            timezone => "Indian/Mauritius",
            country  => "MU",
            coord    => "-2010+05730",
            comment  => "",
        },
        "Indian/Mayotte" => {
            timezone => "Indian/Mayotte",
            country  => "YT",
            coord    => "-1247+04514",
            comment  => "",
        },
        "Indian/Reunion" => {
            timezone => "Indian/Reunion",
            country  => "RE",
            coord    => "-2052+05528",
            comment  => "",
        },
        "Pacific/Apia" => {
            timezone => "Pacific/Apia",
            country  => "WS",
            coord    => "-1350-17144",
            comment  => "",
        },
        "Pacific/Auckland" => {
            timezone => "Pacific/Auckland",
            country  => "NZ",
            coord    => "-3652+17446",
            comment  => "most locations",
        },
        "Pacific/Chatham" => {
            timezone => "Pacific/Chatham",
            country  => "NZ",
            coord    => "-4357-17633",
            comment  => "Chatham Islands",
        },
        "Pacific/Chuuk" => {
            timezone => "Pacific/Chuuk",
            country  => "FM",
            coord    => "+0725+15147",
            comment  => "Chuuk (Truk) and Yap",
        },
        "Pacific/Easter" => {
            timezone => "Pacific/Easter",
            country  => "CL",
            coord    => "-2709-10926",
            comment  => "Easter Island & Sala y Gomez",
        },
        "Pacific/Efate" => {
            timezone => "Pacific/Efate",
            country  => "VU",
            coord    => "-1740+16825",
            comment  => "",
        },
        "Pacific/Enderbury" => {
            timezone => "Pacific/Enderbury",
            country  => "KI",
            coord    => "-0308-17105",
            comment  => "Phoenix Islands",
        },
        "Pacific/Fakaofo" => {
            timezone => "Pacific/Fakaofo",
            country  => "TK",
            coord    => "-0922-17114",
            comment  => "",
        },
        "Pacific/Fiji" => {
            timezone => "Pacific/Fiji",
            country  => "FJ",
            coord    => "-1808+17825",
            comment  => "",
        },
        "Pacific/Funafuti" => {
            timezone => "Pacific/Funafuti",
            country  => "TV",
            coord    => "-0831+17913",
            comment  => "",
        },
        "Pacific/Galapagos" => {
            timezone => "Pacific/Galapagos",
            country  => "EC",
            coord    => "-0054-08936",
            comment  => "Galapagos Islands",
        },
        "Pacific/Gambier" => {
            timezone => "Pacific/Gambier",
            country  => "PF",
            coord    => "-2308-13457",
            comment  => "Gambier Islands",
        },
        "Pacific/Guadalcanal" => {
            timezone => "Pacific/Guadalcanal",
            country  => "SB",
            coord    => "-0932+16012",
            comment  => "",
        },
        "Pacific/Guam" => {
            timezone => "Pacific/Guam",
            country  => "GU",
            coord    => "+1328+14445",
            comment  => "",
        },
        "Pacific/Honolulu" => {
            timezone => "Pacific/Honolulu",
            country  => "US",
            coord    => "+211825-1575130",
            comment  => "Hawaii",
        },
        "Pacific/Johnston" => {
            timezone => "Pacific/Johnston",
            country  => "UM",
            coord    => "+1645-16931",
            comment  => "Johnston Atoll",
        },
        "Pacific/Kiritimati" => {
            timezone => "Pacific/Kiritimati",
            country  => "KI",
            coord    => "+0152-15720",
            comment  => "Line Islands",
        },
        "Pacific/Kosrae" => {
            timezone => "Pacific/Kosrae",
            country  => "FM",
            coord    => "+0519+16259",
            comment  => "Kosrae",
        },
        "Pacific/Kwajalein" => {
            timezone => "Pacific/Kwajalein",
            country  => "MH",
            coord    => "+0905+16720",
            comment  => "Kwajalein",
        },
        "Pacific/Majuro" => {
            timezone => "Pacific/Majuro",
            country  => "MH",
            coord    => "+0709+17112",
            comment  => "most locations",
        },
        "Pacific/Marquesas" => {
            timezone => "Pacific/Marquesas",
            country  => "PF",
            coord    => "-0900-13930",
            comment  => "Marquesas Islands",
        },
        "Pacific/Midway" => {
            timezone => "Pacific/Midway",
            country  => "UM",
            coord    => "+2813-17722",
            comment  => "Midway Islands",
        },
        "Pacific/Nauru" => {
            timezone => "Pacific/Nauru",
            country  => "NR",
            coord    => "-0031+16655",
            comment  => "",
        },
        "Pacific/Niue" => {
            timezone => "Pacific/Niue",
            country  => "NU",
            coord    => "-1901-16955",
            comment  => "",
        },
        "Pacific/Norfolk" => {
            timezone => "Pacific/Norfolk",
            country  => "NF",
            coord    => "-2903+16758",
            comment  => "",
        },
        "Pacific/Noumea" => {
            timezone => "Pacific/Noumea",
            country  => "NC",
            coord    => "-2216+16627",
            comment  => "",
        },
        "Pacific/Pago_Pago" => {
            timezone => "Pacific/Pago Pago",
            country  => "AS",
            coord    => "-1416-17042",
            comment  => "",
        },
        "Pacific/Palau" => {
            timezone => "Pacific/Palau",
            country  => "PW",
            coord    => "+0720+13429",
            comment  => "",
        },
        "Pacific/Pitcairn" => {
            timezone => "Pacific/Pitcairn",
            country  => "PN",
            coord    => "-2504-13005",
            comment  => "",
        },
        "Pacific/Pohnpei" => {
            timezone => "Pacific/Pohnpei",
            country  => "FM",
            coord    => "+0658+15813",
            comment  => "Pohnpei (Ponape)",
        },
        "Pacific/Port_Moresby" => {
            timezone => "Pacific/Port Moresby",
            country  => "PG",
            coord    => "-0930+14710",
            comment  => "",
        },
        "Pacific/Rarotonga" => {
            timezone => "Pacific/Rarotonga",
            country  => "CK",
            coord    => "-2114-15946",
            comment  => "",
        },
        "Pacific/Saipan" => {
            timezone => "Pacific/Saipan",
            country  => "MP",
            coord    => "+1512+14545",
            comment  => "",
        },
        "Pacific/Tahiti" => {
            timezone => "Pacific/Tahiti",
            country  => "PF",
            coord    => "-1732-14934",
            comment  => "Society Islands",
        },
        "Pacific/Tarawa" => {
            timezone => "Pacific/Tarawa",
            country  => "KI",
            coord    => "+0125+17300",
            comment  => "Gilbert Islands",
        },
        "Pacific/Tongatapu" => {
            timezone => "Pacific/Tongatapu",
            country  => "TO",
            coord    => "-2110-17510",
            comment  => "",
        },
        "Pacific/Wake" => {
            timezone => "Pacific/Wake",
            country  => "UM",
            coord    => "+1917+16637",
            comment  => "Wake Island",
        },
        "Pacific/Wallis" => {
            timezone => "Pacific/Wallis",
            country  => "WF",
            coord    => "-1318-17610",
            comment  => "",
        },
    );

    return \%timezone;
}

1;
