check_json
==========

Nagios plugin to check JSON attributes via http(s).

This Plugin is a fork of the existing JSON Plugin from https://github.com/bbuchalter/check_json with the enhancements of using the Nagios::Plugin Perl Module, allowing to use thresholds and performancedata collection from various json attributes.

Usage: `check_json -U <URL> -a <attribute> [ -v|--verbose ] [-t <timeout>] [ -c|--critical <threshold> ] [ -w|--warning <threshold> ]`

Example: 

`check_json.pl -U http://192.168.5.10:9332/local_stats -a '{shares}->{dead}' -w :5 -c :10`

JSON OK - 2 | value=2;;
