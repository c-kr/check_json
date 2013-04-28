check_json
==========

Nagios plugin to check JSON attributes via http(s).

This Plugin is a fork of the existing JSON Plugin from https://github.com/bbuchalter/check_json with the enhancements of using the Nagis::Plugins Perl Module, allowing to use thresholds and performancedata collection from various json attributes.

Usage: check_json [ -v|--verbose ] [-U <URL>] [-t <timeout>] [ -c|--critical <threshold> ] [ -w|--warning <threshold> ] [ -a | --attribute ] <attribute>

 -?, --usage
   Print usage information
 -h, --help
   Print detailed help screen
 -V, --version
   Print version information
 --extra-opts=[section][@file]
   Read options from an ini file. See http://nagiosplugins.org/extra-opts
   for usage and examples.
 -U, --URL http://192.168.5.10:9332/local_stats
 -a, --attribute {shares}->{dead}
 -w, --warning INTEGER:INTEGER .  See http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT for the threshold format. 
 -c, --critical INTEGER:INTEGER .  See http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT for the threshold format. 
 -t, --timeout=INTEGER
   Seconds before plugin times out (default: 15)
 -v, --verbose
   Show details for command-line debugging (can repeat up to 3 times)

Example: 
check_json.pl -U http://192.168.5.10:9332/local_stats -a '{shares}->{dead}' -w :5 -c :10

