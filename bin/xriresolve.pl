#!/usr/bin/perl
#
# xriresolve.pl
#
# Resolves an XRI.  Works both on the command line and as a CGI.

use strict;
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

    print h2('IDs') . '<table border="0">' if $is_cgi;
    &print_attr("Canonical ID", $xrd->canonical_id) if $xrd->canonical_id;
    foreach my $lid ($xrd->local_ids_by_priority) {
        &print_attr("Local ID", $lid);
    }
    print '</table>' if ($is_cgi);
    print "\n";

    my @services = $xrd->services_by_priority;
    print h2('Services') . '<table border="0">' if (@services and $is_cgi);
    foreach my $service (@services) {
        &print_attr('Path', $service->path->{value}) if $service->path;
        &print_attr('Type', $service->type->{value}) if $service->type;
        &print_attr('MediaType', $service->media_type->{value})
            if $service->media_type;
	print '</table>' if $is_cgi;
        print "<ul>\n" if ($service->uri and $is_cgi);
        foreach my $uri (@{$service->uri}) {
            &print_attr('URI', $uri->{value});
        }
        print "</ul>" if ($service->uri and $is_cgi);
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

sub print_attr {
    my ($type, $val) = @_;

    if ($is_cgi) {
        if ($type eq 'URI') {
  	    print "  <li>$val</li>\n";
        }
        else {
            print "<tr><td><b>$type</b></td><td>$val</td></tr>\n";
	}
    }
    else {
        printf "%12s: %s\n", $type, $val;
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
