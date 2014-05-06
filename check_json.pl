#!/usr/bin/env perl

use warnings;
use strict;
use LWP::UserAgent;
use JSON;
use Nagios::Plugin;
use Data::Dumper;

my $np = Nagios::Plugin->new(
    usage => "Usage: %s -u|--url <URL> -a|--attribute <attribute> "
    . "[ -c|--critical <threshold> ] [ -w|--warning <threshold> ] "
    . "[ -p|--perfvars <fields> ] "
    . "[ -t|--timeout <timeout> ] "
    . "[ -d|--divisor <divisor> ] "
    . "[ -T|--contenttype <content-type> ] "
    . "[ --ignoressl ] "
    . "[ -h|--help ] ",
    version => '0.3',
    blurb   => 'Nagios plugin to check JSON attributes via http(s)',
    extra   => "\nExample: \n"
    . "check_json.pl --url http://192.168.5.10:9332/local_stats --attribute '{shares}->{dead}' "
    . "--warning :5 --critical :10 --perfvars '{shares}->{dead},{shares}->{live}'",
    url     => 'https://github.com/c-kr/check_json',
    plugin  => 'check_json',
    timeout => 15,
    shortname => "Check JSON status API",
);

 # add valid command line options and build them into your usage/help documentation.
$np->add_arg(
    spec => 'url|u=s',
    help => '-u, --url http://192.168.5.10:9332/local_stats',
    required => 1,
);
$np->add_arg(
    spec => 'attribute|a=s',
    help => '-a, --attribute {shares}->{dead}',
    required => 1,
);
$np->add_arg(
    spec => 'divisor|d=i',
    help => '-d, --divisor 1000000',
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
    help => "-p, --perfvars eg. '{shares}->{dead},{shares}->{live}'\n   "
    . "CSV list of fields from JSON response to include in perfdata "
);

$np->add_arg(
    spec => 'contenttype|T=s',
    default => 'application/json',
    help => "-T, --contenttype application/json \n   "
    . "Content-type accepted if different from application/json ",
);
$np->add_arg(
    spec => 'ignoressl',
    help => "--ignoressl\n   Ignore bad ssl certificates",
);


## Parse @ARGV and process standard arguments (e.g. usage, help, version)
$np->getopts;
if ($np->opts->verbose) { (print Dumper ($np))};

## GET URL
my $ua = LWP::UserAgent->new;

$ua->agent('check_json/0.3');
$ua->default_header('Accept' => 'application/json');
$ua->protocols_allowed( [ 'http', 'https'] );
$ua->parse_head(0);
$ua->timeout($np->opts->timeout);

if ($np->opts->ignoressl) {
    $ua->ssl_opts(verify_hostname => 0, SSL_verify_mode => 0x00);
}

if ($np->opts->verbose) { (print Dumper ($ua))};

my $response = ($ua->get($np->opts->url));

if ($response->is_success) {
    if (!($response->header("content-type") =~ $np->opts->contenttype)) {
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

if ($np->opts->verbose) { (print Dumper ($check_value_str))};
eval $check_value_str;

if (!defined $check_value) {
    $np->nagios_exit(UNKNOWN, "No value received");
}

if (defined $np->opts->divisor) {
    $check_value = $check_value/$np->opts->divisor;
}

my $result = $np->check_threshold($check_value);

my @statusmsg;

# routine to add perfdata from JSON response based on a loop of keys given in perfvals (csv)
if ($np->opts->perfvars) {
    foreach my $key (split(',', $np->opts->perfvars)) {
        # use last element of key as label
        my $label = (split('->', $key))[-1];
        # make label ascii compatible
        $label =~ s/[^a-zA-Z0-9_-]//g  ;
        my $perf_value;
        $perf_value = eval '$json_response->'.$key;
        if ($np->opts->verbose) { print Dumper ("JSON key: ".$label.", JSON val: " . $perf_value) };
        if ( defined($perf_value) ) {
            # add threshold if attribute option matches key
            if ($key eq $np->opts->attribute) {
                push(@statusmsg, "$label: $check_value");
                $np->add_perfdata(
                    label => lc $label,
                    value => $check_value,
                    threshold => $np->threshold(),
                );
            } else {
                push(@statusmsg, "$label: $perf_value");
                $np->add_perfdata(
                    label => lc $label,
                    value => $perf_value,
                );            
            }
        }
    }
}

$np->nagios_exit(
    return_code => $result,
    message     => join(', ', @statusmsg),
);

