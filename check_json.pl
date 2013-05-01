#!/usr/bin/env perl

use warnings;
use strict;
use LWP::UserAgent;
use JSON 'decode_json';
use Nagios::Plugin;
use Data::Dumper;

my $np = Nagios::Plugin->new(  
    usage => "Usage: %s [ -v|--verbose ] [-U <URL>] [-t <timeout>] "
    . "[ -c|--critical <threshold> ] [ -w|--warning <threshold> ] "
    . "[ -a | --attribute ] <attribute>",
    version => '0.1',
    blurb   => 'Nagios plugin to check JSON attributes via http(s)',
    extra   => "\nExample: \n"
    . "check_json.pl -U http://192.168.5.10:9332/local_stats -a '{shares}->{dead}' -w :5 -c :10",
    url     => 'https://github.com/c-kr/check_json',
    plugin  => 'check_json',
    timeout => 15,
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
    help => '-w, --warning INTEGER:INTEGER .  See '
    . 'http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT '
    . 'for the threshold format. ',
);
$np->add_arg(
    spec => 'critical|c=s',
    help => '-c, --critical INTEGER:INTEGER .  See '
    . 'http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT '
    . 'for the threshold format. ',
);

# Parse @ARGV and process standard arguments (e.g. usage, help, version)
$np->getopts;


## GET URL
my $ua = LWP::UserAgent->new;

$ua->agent('check_json/0.1');
$ua->protocols_allowed( [ 'http', 'https'] );
$ua->parse_head(0);
$ua->timeout($np->opts->timeout);

my $response = ($ua->get($np->opts->URL));

if ($response->is_success) {
    if (!($response->header("content-type") =~ 'application/json')) {
        $np->nagios_exit(UNKNOWN,"Content type is not JSON: ".$response->header("content-type"));
    }
} else {
    $np->nagios_exit(CRITICAL, "Connection failed: ".$response->status_line);
}

my $json_response = decode_json($response->content);
if ($np->opts->verbose) { (print Dumper ($json_response))};

my $value;
my $exec = '$value = $json_response->'.$np->opts->attribute;
if ($np->opts->verbose) {print "EXEC is: $exec \n"};
eval $exec;

if (!defined $value) {
    $np->nagios_exit(UNKNOWN, "No value received");
}

if (defined $np->opts->divisor) {
    $value = $value/$np->opts->divisor;
}

my $result = $np->check_threshold($value);

$np->add_perfdata( 
    label => 'value',
    value => $value,
    threshold => $np->threshold(),
);

$np->nagios_exit(
    return_code => $result,
    message     => $value,
);

