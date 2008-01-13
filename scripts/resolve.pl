#!/usr/bin/perl

use strict;
use Getopt::Std;
use XRI;

our $opt_x;

getopts('x');
my $xri = $ARGV[0];
if (!$xri) {
    print "Usage:\n";
    print "    $0 [-x] xri\n\n";
    print "Options:\n";
    print "    -x    print XRI Descriptor (XRD)\n";
    exit;
}

my $xrd = XRI->resolve($xri);
if ($xrd) {
    if ($opt_x) {
        print $xrd->dom->toString(2);
    }
    else {
        print "Canonical ID: " . $xrd->canonical_id . "\n"
            if $xrd->canonical_id;
        foreach my $lid ($xrd->local_ids_by_priority) {
            print "    Local ID: $lid\n";
        }
        print "\n";
        foreach my $service ($xrd->services_by_priority) {
            print "     Service: " . $service->{type} . "\n";
            foreach my $uri (@{$service->{uri}}) {
                print "       - " . $uri->{value} . "\n";
            }
            print "\n";
        }
    }
}
else {
    print "ERROR: Could not resolve $xri\n";
}
