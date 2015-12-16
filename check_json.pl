#!/usr/bin/env perl

use warnings;
use strict;
use HTTP::Request::Common;
use LWP::UserAgent;
use JSON;
use Nagios::Plugin;
use Data::Dumper;

my $np = Nagios::Plugin->new(
    usage => "Usage: %s -u|--url <http://user:pass\@host:port/url> -a|--attributes <attributes> "
    . "[ -c|--critical <thresholds> ] [ -w|--warning <thresholds> ] "
    . "[ -p|--perfvars <fields> ] "
    . "[ -o|--outputvars <fields> ] "
    . "[ -t|--timeout <timeout> ] "
    . "[ -d|--divisor <divisor> ] "
    . "[ -m|--metadata <content> ] "
    . "[ -T|--contenttype <content-type> ] "
    . "[ --ignoressl ] "
    . "[ -h|--help ] ",
    version => '0.5',
    blurb   => 'Nagios plugin to check JSON attributes via http(s)',
    extra   => "\nExample: \n"
    . "check_json.pl --url http://192.168.5.10:9332/local_stats --attributes '{shares}->{dead}' "
    . "--warning :5 --critical :10 --perfvars '{shares}->{dead},{shares}->{live}' "
    . "--outputvars '{status_message}'",
    url     => 'https://github.com/c-kr/check_json',
    plugin  => 'check_json',
    timeout => 15,
    shortname => "Check JSON status API",
);

 # add valid command line options and build them into your usage/help documentation.
$np->add_arg(
    spec => 'url|u=s',
    help => '-u, --url http://user:pass@192.168.5.10:9332/local_stats',
    required => 1,
);

$np->add_arg(
    spec => 'attributes|a=s',
    help => '-a, --attributes {shares}->{dead},{shares}->{uptime}',
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
    help => "-p, --perfvars eg. '* or {shares}->{dead},{shares}->{live}'\n   "
    . "CSV list of fields from JSON response to include in perfdata "
);

$np->add_arg(
    spec => 'outputvars|o=s',
    help => "-o, --outputvars eg. '* or {status_message}'\n   "    
    . "CSV list of fields output in status message, same syntax as perfvars"
);

$np->add_arg(
    spec => 'metadata|m=s',
    help => "-m|--metadata \'{\"name\":\"value\"}\'\n   "
    . "RESTful request metadata in JSON format"
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

$ua->env_proxy;
$ua->agent('check_json/0.5');
$ua->default_header('Accept' => 'application/json');
$ua->protocols_allowed( [ 'http', 'https'] );
$ua->parse_head(0);
$ua->timeout($np->opts->timeout);

if ($np->opts->ignoressl) {
    $ua->ssl_opts(verify_hostname => 0, SSL_verify_mode => 0x00);
}

if ($np->opts->verbose) { (print Dumper ($ua))};

my $response;
if ($np->opts->metadata) {
    $response = $ua->request(GET $np->opts->url, 'Content-type' => 'application/json', 'Content' => $np->opts->metadata );
} else {
    $response = $ua->request(GET $np->opts->url);
}

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

my @attributes = split(',', $np->opts->attributes);
my @warning = split(',', $np->opts->warning);
my @critical = split(',', $np->opts->critical);
my @divisor = $np->opts->divisor ? split(',',$np->opts->divisor) : () ;
my %attributes = map { $attributes[$_] => { warning => $warning[$_] , critical => $critical[$_], divisor => ($divisor[$_] or 0) } } 0..$#attributes;

my %check_value;
my $check_value;
my $result = -1;
my $resultTmp;

foreach my $attribute (sort keys %attributes){
    my $check_value;
    my $check_value_str = '$check_value = $json_response->'.$attribute;
    
    if ($np->opts->verbose) { (print Dumper ($check_value_str))};
    eval $check_value_str;

    if (!defined $check_value) {
        $np->nagios_exit(UNKNOWN, "No value received");
    }

    if ($attributes{$attribute}{'divisor'}) {
        $check_value = $check_value/$attributes{$attribute}{'divisor'};
    }

    if ( $check_value eq "true" or $check_value eq "false" ) {
       if ( $check_value eq "true") {
          $resultTmp = 0;
          if ($attributes{$attribute}{'critical'} eq 1 or $attributes{$attribute}{'critical'} eq "true") {
             $resultTmp = 2;
          }
          else
          {
             if ($attributes{$attribute}{'warning'} eq 1 or $attributes{$attribute}{'warning'} eq "true") {
                $resultTmp = 1;
             }
          }
       }
       if ( $check_value eq "false") {
          $resultTmp = 0;
          if ($attributes{$attribute}{'critical'} eq 0 or $attributes{$attribute}{'critical'} eq "false") {
             $resultTmp = 2;
           }
           else
           {
              if ($attributes{$attribute}{'warning'} eq 0 or $attributes{$attribute}{'warning'} eq "false") {
                 $resultTmp = 1;
              }
           }
       }
    }
    else
    {
       $resultTmp = $np->check_threshold(
           check => $check_value,
           warning => $attributes{$attribute}{'warning'},
           critical => $attributes{$attribute}{'critical'}
       );
     }
    $result = $resultTmp if $result < $resultTmp;

    $attributes{$attribute}{'check_value'}=$check_value;
}

my @statusmsg;


# routine to add perfdata from JSON response based on a loop of keys given in perfvals (csv)
if ($np->opts->perfvars) {
    foreach my $key ($np->opts->perfvars eq '*' ? map { "{$_}"} sort keys %$json_response : split(',', $np->opts->perfvars)) {
        # use last element of key as label
        my $label = (split('->', $key))[-1];
        # make label ascii compatible
        $label =~ s/[^a-zA-Z0-9_-]//g  ;
        my $perf_value;
        $perf_value = eval '$json_response->'.$key;
        if ($np->opts->verbose) { print Dumper ("JSON key: ".$label.", JSON val: " . $perf_value) };
        if ( defined($perf_value) ) {
            # add threshold if attribute option matches key
            if ($attributes{$key}) {
                push(@statusmsg, "$label: $attributes{$key}{'check_value'}");
                $np->add_perfdata(
                    label => lc $label,
                    value => $attributes{$key}{'check_value'},
                    threshold => $np->set_thresholds( warning => $attributes{$key}{'warning'}, critical => $attributes{$key}{'critical'}),
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

# output some vars in message
if ($np->opts->outputvars) {
    foreach my $key ($np->opts->outputvars eq '*' ? map { "{$_}"} sort keys %$json_response : split(',', $np->opts->outputvars)) {
        # use last element of key as label
        my $label = (split('->', $key))[-1];
        # make label ascii compatible
        $label =~ s/[^a-zA-Z0-9_-]//g;
        my $perf_value;
        $perf_value = eval '$json_response->'.$key;
	   push(@statusmsg, "$label: $perf_value");
    }
}

$np->nagios_exit(
    return_code => $result,
    message     => join(', ', @statusmsg),
);
