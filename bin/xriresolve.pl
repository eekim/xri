#!/usr/bin/perl
#
# xriresolve.pl
#
# Resolves an XRI.  Works both on the command line and as a CGI.

use strict;
use lib '/Users/eekim/devel/XRI/lib';
use CGI qw/:standard -nosticky/;
use Error qw/:try/;
use Getopt::Std;
use XRI;

### globals

our $opt_x;
our $is_cgi = (request_method) ? 1 : 0;
my $xri;
my $xrd;

### main

if ($is_cgi) {   # CGI
    if ( $xri = param('xri') ) {
        # pretty print the URI so we're using PATH_INFO instead of
        # query parameters
        print redirect(script_name . "/$xri");
    }
    elsif ( $xri = path_info ) {
        $xri =~ s/^\///;
        param('xri', $xri);
        &print_form;
        print hr;
        &resolve($xri);
        print end_html;
    }
    else {
        &print_form;
        print end_html;
    }
}
else {   # command-line
    getopts('x');
    $xri = $ARGV[0];
    if (!$xri) {
        print "Usage:\n";
        print "    $0 [-x] xri\n\n";
        print "Options:\n";
        print "    -x    print XRI Descriptor (XRD)\n";
        exit;
    }
    &resolve($xri);
}

### functions

sub resolve {
    my $xri = shift;
    my $xrd;
    my $got_exception = 0;

    try {
        $xrd = XRI->resolve($xri);
    }
    catch XRI::Exception::InvalidXRI with {
        &print_error($xri, shift);
    };
    &print_xrd($xrd) if $xrd;
}

sub print_xrd {
    my $xrd = shift;

    print h2('IDs') . '<table border="0">' if ($is_cgi);
    &print_id("Canonical ID", $xrd->canonical_id) if $xrd->canonical_id;
    foreach my $lid ($xrd->local_ids_by_priority) {
        &print_id("    Local ID", $lid);
    }
    print '</table>' if ($is_cgi);
    print "\n";

    my @services = $xrd->services_by_priority;
    print h2('Services') if (@services and $is_cgi);
    foreach my $service (@services) {
        &print_service_type($service->{type});
        print "<ul>\n" if ($service->{uri} and $is_cgi);
        foreach my $uri (@{$service->{uri}}) {
            &print_service_uri($uri->{value});
        }
        print "</ul>" if ($service->{uri} and $is_cgi);
        print "\n";
    }

    if ($is_cgi) {
        print h2('XRI Descriptor') .
            '<pre>' .
            escapeHTML( $xrd->dom->toString(2) ) .
            "</pre>\n";
    }
    else {
        print "XRI Descriptor:\n" . $xrd->dom->toString(2) if ($opt_x);
    }
}

sub print_id {
    my ($id_type, $id) = @_;

    if ($is_cgi) {
        print "<tr><td><b>$id_type</b></td><td>$id</td></tr>\n";
    }
    else {
        print "$id_type: $id\n";
    }
}

sub print_service_type {
    my $type = shift;
    if ($is_cgi) {
        print "<p><i>$type</i></p>\n";
    }
    else {
        print "     Service: $type\n";
    }
}

sub print_service_uri {
    my $uri = shift;
    if ($is_cgi) {
        print "  <li>$uri</li>\n";
    }
    else {
        print "       - $uri\n";
    }
}

sub print_form {
    print header .
        start_html(-title => 'XRI Resolver') .
        h1('XRI Resolver') .
        start_form(-method => 'GET') .
        '<p>XRI (or URI that points to an XRDS): ' .
        textfield(-name => 'xri', -size => 20) .
        submit(-value => 'Resolve') .
        "</p>\n" .
        end_form;
}

sub print_error {
    my ($xri, $error) = @_;
    if ($is_cgi) {
        print <<EOT;
<p style="color: red;">Sorry, I could not resolve <tt>$xri</tt>.  $error</p>
EOT
    }
    else {
        print "ERROR: Could not resolve $xri.\n$error";
    }
}

__END__

=head1 NAME

xriresolve.pl - Resolve an XRI (or URI)

=head1 SYNOPSIS

Command-line:

  xriresolve.pl [-x] xri

CGI:

  http://foo.com/cgi/xriresolve.pl/xri

=head1 DESCRIPTION

Resolves and XRI (or a URI pointing to an XRDS) and returns the
information from the corresponding XRI Descriptor.

When called from the command-line, the -x option displays the XRI
Descriptor as XML; otherwise, it just returns the IDs and the
Services.

=head1 AUTHORS

Eugene Eric Kim, E<lt>eekim@blueoxen.comE<gt>

Matthew O'Connor E<lt>matthew@canonical.orgE<gt>

=head1 COPYRIGHT & LICENSE

(C) Copyright 2008 Blue Oxen Associates.  All rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
