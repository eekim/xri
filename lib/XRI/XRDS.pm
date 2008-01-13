package XRI::XRDS;
use strict;
use warnings;
use XRI::XRD;
use XML::LibXML;
use Class::Field qw(field);
use Error qw(:try);

field 'xrd';
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
