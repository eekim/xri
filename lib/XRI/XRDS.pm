package XRI::XRDS;

use strict;
use warnings;
use Class::Field qw(field);
use Error qw(:try);
use XML::LibXML;
use XRI::XRD;

field 'xml';
field 'dom';
field 'root';

sub new {
    my ( $class, %args ) = @_;
    throw XRI::Exception::XRDS(
        "No xml parameter to $class\::new()"
    ) unless defined $args{xml};
    my $self = bless( \%args, $class );
    $self->_parse;
    return $self;
}

sub _parse {
    my $self   = shift;
    my $parser = XML::LibXML->new;
    $self->dom( $parser->parse_string( $self->xml ) );
    $self->root( $self->dom->documentElement );
}

sub last_xrd {
    my $self = shift;
    my @xrd_doms = $self->_xpath( "xrd:XRD|xrds:XRD", $self->root );
    return XRI::XRD->new(dom => pop @xrd_doms);
}

sub _xpath {
    my ( $self, $xpath, $node ) = @_;
    my $xpc = XML::LibXML::XPathContext->new;
    $xpc->registerNs( 'xrd',  'xri://$xrd*($v*2.0)' );
    $xpc->registerNs( 'xrds', 'xri://$xrds' );
    return $xpc->findnodes( $xpath, $node );
}


package XRI::Exception::XRDS;
use base qw(Error::Simple);

1;

__END__

=head1 NAME

XRI::XRDS -- Parses and represents XRDS (XRI Descriptors) data

=head1 VERSION

Version 2.0.0

=head1 SYNOPSIS

Parses and represents the XRDS XML format, which consists of multiple
L<XRI::XRD> elements, the last of which is usually the only one that
is relevant.  Most users of this library will never use this class.

    use XRI::XRDS;

    my $xrds = XRI::XRDS->new( xml => $xrds_xml );
    my $xrd  = $xrds->last_xrd;  # gets the last XRD

=head1 METHODS

=head2 new( xml => $xml )

Constructor.  Parses $xml, which is an XRDS XML string.

=head2 last_xrd( )

Returns the last XRD element, which is usually the only one you'll
care about, as an L<XRI::XRD> object.

=head1 ACCESSORS / MUTATORS

These are essentially private methods, although they may be useful for
debugging.

=head2 xml( )

Returns the XML data that instantiated this object.

=head2 dom( )

Returns the DOM representation of the XML data that instantiated this
class.

=head2 root( )

Returns the root node of the DOM representation of the XML data that
instantiated this class.

=head1 AUTHORS

Eugene Eric Kim, E<lt>eekim@blueoxen.comE<gt>

Matthew O'Connor, E<lt>matthew@canonical.orgE<gt>

=head1 COPYRIGHT & LICENSE

(C) Copyright 2008 Blue Oxen Associates.  All rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
