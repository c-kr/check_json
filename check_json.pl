#!/usr/bin/env perl

use warnings;
use strict;
use LWP::UserAgent;
use JSON;
use Nagios::Plugin;
use Data::Dumper;

my $np = Nagios::Plugin->new(
    usage => "Usage: %s -U <URL> -a|--attribute <attribute> [-t|--timeout <timeout>] "
    . "[ -c|--critical <threshold> ] [ -w|--warning <threshold> ] "
    . "[ -a|--attribute <attribute> ] "
    . "[ -D|--divisor <divisor> ] "
    . "[ -p|--perfvars <fields> ]",
    version => '0.2',
    blurb   => 'Nagios plugin to check JSON attributes via http(s)',
    extra   => "\nExample: \n"
    . "check_json.pl -U http://192.168.5.10:9332/local_stats -a '{shares}->{dead}' -w :5 -c :10",
    url     => 'https://github.com/c-kr/check_json',
    plugin  => 'check_json',
    timeout => 15,
    shortname => "Check JSON status API",
);

 # add valid command line options and build them into your usage/help documentation.
$np->add_arg(
    spec => 'URL|U=s',
    help => '-U, --URL http://192.168.5.10:9332/local_stats',
    required => 1,
);
$np->add_arg(
    spec => 'attribute|a=s',
    help => '-a, --attribute {shares}->{dead}',
    required => 1,
);
$np->add_arg(
    spec => 'divisor|D=i',
    help => '-D, --divisor 1000000',
);
$np->add_arg(
    spec => 'warning|w=s',
    help => '-w, --warning INTEGER:INTEGER . See '
    . 'http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT '
    . 'for the threshold format. ',
);
$np->add_arg(
    spec => 'critical|c=s',
    help => '-c, --critical INTEGER:INTEGER . See '
    . 'http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT '
    . 'for the threshold format. ',
);
$np->add_arg(
    spec => 'perfvars|p=s',
    help => '-p, --perfvars INTEGER:INTEGER . CSV list of fields from JSON response to include in perfdata ',
);

## Parse @ARGV and process standard arguments (e.g. usage, help, version)
$np->getopts;
if ($np->opts->verbose) { (print Dumper ($np))};

## GET URL
my $ua = LWP::UserAgent->new;

$ua->agent('check_json/0.2');
$ua->default_header('Accept' => 'application/json');
$ua->protocols_allowed( [ 'http', 'https'] );
$ua->parse_head(0);
$ua->timeout($np->opts->timeout);
if ($np->opts->verbose) { (print Dumper ($ua))};

my $response = ($ua->get($np->opts->URL));

if ($response->is_success) {
    if (!($response->header("content-type") =~ 'application/json')) {
        $np->nagios_exit(UNKNOWN,"Content type is not JSON: ".$response->header("content-type"));
    }
} else {
    $np->nagios_exit(CRITICAL, "Connection failed: ".$response->status_line);
}

## Parse JSON
my $json_response = decode_json($response->content);
if ($np->opts->verbose) { (print Dumper ($json_response))};

my $check_value;
my $check_value_str = '$check_value = $json_response->'.$np->opts->attribute;

# if ($np->opts->verbose) { (print Dumper ($exec))};
eval $check_value_str;

#$attribute_value = $json_response->{eval $np->opts->attribute};

if (!defined $check_value) {
    $np->nagios_exit(UNKNOWN, "No value received");
}

if (defined $np->opts->divisor) {
    $check_value = $check_value/$np->opts->divisor;
}

my $result = $np->check_threshold($check_value);

my @perfdata;

# routine to add perfdata from JSON response based on a loop of keys given in perfvals (csv)
if ($np->opts->perfvars) {
    foreach my $key (split(',', $np->opts->perfvars)) {
        # use last element of key as label
        my $label = (split('->', $key))[-1];
        $label =~ s/[^a-zA-Z0-9_-]//g  ;
        my $perf_val;
        $perf_val = eval '$json_response->'.$key;
        print Dumper ("JSON key: ".$label.", JSON val: " . eval $perf_val);
        if ($np->opts->verbose) { print Dumper ("JSON key: ".$label.", JSON val: " . eval $perf_val) };
        if ( defined($perf_val) ) {
            push(@perfdata, {label => lc $label, value => $perf_val});
            $np->add_perfdata(
                label => lc $label,
                value => $perf_val,
                #threshold => $np->threshold(),
            );
        }
    }
}

sub pp {
  my $h = shift();
  qq[{${\(join',',map"$_=>$h->{$_}",keys%$h)}}]
}

print Dumper (@perfdata);

$np->nagios_exit(
    return_code => $result,
    message     => pp @perfdata,
);

