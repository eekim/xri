package XRI;

use strict;
use warnings;
use Class::Field qw(field);
use Error qw(try);
use Text::Balanced qw(extract_bracketed);
use LWP::UserAgent;
use XRI::XRDS;

our $VERSION = '2.0.0';

field 'root', -init => "''";
field 'segments', -init => "[]";
field 'path', -init => "''";
field 'query', -init => "''";
field 'fragment', -init => "''";

our @GCS = qw(= @ + $ !);  
our @SEG_SEP = qw(* !);      # Segment delims (e.g. foo*bar, foo!bar)
our @SEC_DELIM = ('/', '#', '?');  # Section delims (i.e. path, query, fragments)
our @DELIMS = (@GCS, @SEG_SEP, @SEC_DELIM);
our $delim_rx = "[" . join("", map quotemeta, @DELIMS) . "]";
our $not_delim_rx = "[^" . join("", map quotemeta, @DELIMS) . "]";

our %ROOT_AUTHORITIES = (
    '@' => [ 'https://at.xri.net/', 'http://at.xri.net/' ],
    '=' => [ 'https://equal.xri.net/', 'http://equal.xri.net/' ]
);

sub new {
    my ($class, $xri) = @_;

    unless (defined $xri) {
        throw XRI::Exception::ExpectedXRI(
            "XRI->new() expects an XRI as an argument"
        );
    }

    my $self = bless({xri => $xri}, $class);
    $self->_parse;
    return $self;
}

sub resolve {
    my ($class, $xri) = @_;
    my $self;
    my $xrd;

    # FIXME: Support non-2.0 authorities?
    my $service_type = 'xri://$res*auth*($v*2.0)'; 

    unless (defined $xri) {
        throw XRI::Exception::ExpectedXRI(
            "XRI->resolve() expects an XRI (or URI) as an argument"
        );
    }

    if ($xri =~ m{^https?://}) {
      return _resolve_segment([ $xri ], '');
    }
    else {
      $self = $class->new($xri);
    }

    my $authorities = $ROOT_AUTHORITIES{$self->root};
    my @segments = @{$self->{segments}};
    while (my $segment = shift @segments) {
        $xrd = _resolve_segment($authorities, $segment);
        if (@segments) {
            $authorities = $xrd->service_endpoints($service_type);
        }
    }
    return $xrd;
}

sub _resolve_segment {
    my ($authorities, $segment) = @_;
    my $xrd;

    for my $authority (@$authorities) {
        eval {
            my $xrds_xml = _get_xrds_from_authority($authority, $segment);
            my $xrds     = XRI::XRDS->new( xml => $xrds_xml );
            $xrd         = $xrds->last_xrd;
        };
        return $xrd if $xrd;
    }

    # FIXME: Again, use Error for this.
    die;  # none of the authorities worked.
}

sub _get_xrds_from_authority {
    my ($authority, $segment) = @_;
    my $ua = LWP::UserAgent->new;
    $ua->default_header( "Accept" => "application/xrds+xml" );
    my $join = ($authority =~ m{/$} || !$segment) ? "" : "/";
    $| = 1;
#   print "GETTING: $authority$join$segment\n";
    my $response = $ua->get($authority . $join . $segment);
#   print $response->content if $response->is_success;
#   print "\n=================================================\n";
    return $response->content if $response->is_success;
    # FIXME: Use Error for this, so we have consistent exception handling
    die "could not get xrds from $authority for $segment"; # could not get XRDS
}

sub _parse {
    my $self = shift;
    my $xri = $self->{xri};

    # Strip the scheme
    $xri =~ s{^xri:(//)?}{};

    # Pop the first char
    my $root = substr($xri, 0, 1);
    substr($xri, 0, 1) = "";

    # Ensure the root is a valid GCS character
    unless (is_member($root, @GCS)) {
        throw XRI::Exception::InvalidXRI("Root not found in $root$xri");
    }

    # Assert that XRIs that start w/ "!" have a subsequent "!"
    my $char = substr($xri, 0, 1);
    if ($root eq '!' and $char ne '!') {
        throw XRI::Exception::InvalidXRI(
            "URIs with root GCS of ! must have ! as next char."
        );
    }

    # Ensure we add delim char.  Compressed root syntax does not call for it,
    # but the parser below expects it.  E.g. "=eekim" is really "=*eekim".
    $xri = "*" . $xri unless $xri =~ /^$delim_rx/;

    my $segments = [];
    while (length $xri) {
        if ($xri =~ /^$delim_rx\(/) {
            my $delim  = remove_first_char($xri);
            my $xref = extract_bracketed($xri, "()");
            unless (defined $xref) {
                throw XRI::Exception::InvalidXRI(
                    "Unbalanced parentheses in XRI at \"$xri\" in " . $self->{xri}
                );
            }
            push @$segments, $delim . $xref;
        } elsif ($xri =~ m{^(?:/|\?|\#)}) { # FIXME: delims are repeated here and elsewhere
            last;  # Reached the end of the authority
        } elsif ($xri =~ s/^($delim_rx$not_delim_rx+)//) {
            my $segment = $1;
            $self->assert_segment_ok($segment);
            push @$segments, $segment;
        } else {
            throw XRI::Exception::InvalidXRI(
                "Parse error \"$xri\" in " . $self->{xri}
            );
        }
    }

    my ($path, $query) = split /\?/, $xri, 2;
    ($query, my $fragment) = split /#/, $xri, 2;
    $self->segments($segments);
    $self->root($root) if defined $root;
    $self->path($path) if defined $path;
    $self->query($query) if defined $query;
    $self->fragment($fragment) if defined $fragment;
}

sub assert_segment_ok {
    my ($self, $segment) = @_;

    # FIXME: Check for other kinds of badness too.  E.g. more unescaped chars.
    # FIXME: delims are repeated here and elsewhere
    return unless $segment =~ m{\(|\)|/|\?|#/};

    throw XRI::Exception::InvalidXRI(
        "Segment appears malformed: $segment"
    );
}

sub remove_first_char {
    my $c = substr($_[0], 0, 1);
    substr($_[0], 0, 1) = "";
    return $c;
}

sub is_member {
    my ($char, @list) = @_;
    return grep { $_ eq $char } @list;
}

1; # End of XRI

package XRI::Exception::ExpectedXRI;
use base qw(Error::Simple);

package XRI::Exception::InvalidXRI;
use base qw(Error::Simple);

__END__

=head1 NAME

XRI -- Resolves XRI 2.0 identifiers (including URIs)

=head1 VERSION

Version 2.0.0

=head1 SYNOPSIS

Library for resolving XRIs.

    use XRI;

    my $xrd = XRI->resolve('=eekim');
    print $xrd->dom->toString(2);  # print the resulting XRI descriptor

=head1 METHODS

=head2 new( $xri )

Parses the value of $xri into its root, segments, path, query, and
fragment, all of which can be accessed via the appropriate
accessors/mutators.

=head2 resolve ( $xri )

Resolves the $xri, returning the resulting XRI descriptor as an
L<XRI::XRD> object.

You can pass a URI to this function, provided that it points to an
XRDS file.  You can use this to do discovery on OpenID 2.0 URIs,
although this library will not handle OpenID delegation since it's not
part of the XRI spec.

=head1 ACCESSORS / MUTATORS

=head2 root( )

Returns the root of the XRI.  This is typically a Global Context
Symbol (GCS), usually an equals ("="), which represents individuals,
an at ("@"), which represents groups, or a bang ("!"), which
represents i-numbers.

=head2 segments( )

Returns the segments of the XRI, not including the root.  Each segment
is preceded by either the delegation character ("*") or a bang ("!")
for i-numbers.

=head2 path( )

Returns the path of an XRI, which is largely equivalent to a path in
URIs.

=head2 query( )

Returns the query string of an XRI, which is equivalent to a query
string in a URI.

=head2 fragment( )

Returns the fragment of an XRI, which is equivalent to a fragment in a
URI.

=head1 NOTES

This is not yet fully compliant with the XRI 2.0 spec.  L<XRI::XRDS>
and L<XRI::XRD> don't represent all of the fields found in an XRDS
yet, and we don't currently handling resolution when Refs or Redirects
are specified.

=head1 REFERENCES

XRI spec

=over

L<http://www.oasis-open.org/committees/tc_home.php?wg_abbrev=xri>

=back

i-names

=over

L<http://www.inames.net/>

=back

Yadis

=over

L<http://yadis.org/>

=back

barx

=over

L<http://xrisoft.org/>

=back

OpenXRI

=over

http://openxri.org/

=back

=head1 ACKNOWLEDGEMENTS

Much love and credit go to Fen Labalme, whose original XRI Perl
library was the very first implementation of the XRI specification,
and who has been passionately committed to building user-centric
identity systems for over two decades.

Thanks also to Victor Grey and Kermit Snelson, whose Ruby XRI resolver
(barx) helped us navigate the complexities of the spec and provided
some of our test cases.  Many thanks to Drummond Reed and Gabe Wachob,
the co-chairs of the XRI Technical Committee, as well as John Bradley
and Andy Dale for patiently answering our many questions about the
spec.

Finally, thanks to Scott Kveton, Chris Messina, and David Recordon for
organizing OpenIDDevCamp, which provided the critical resources
(i.e. food, beer, and wireless) necessary to finish this library.

=head1 AUTHORS

Eugene Eric Kim, E<lt>eekim@blueoxen.comE<gt>

Matthew O'Connor, E<lt>matthew@canonical.orgE<gt>

=head1 COPYRIGHT & LICENSE

(C) Copyright 2008 Blue Oxen Associates.  All rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
