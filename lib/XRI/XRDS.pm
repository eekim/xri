package XRI::XRDS;
use strict;
use warnings;
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
    my $xrd_dom = $self->_xpath( "xrd:XRD", $self->root );
    return XRI::XRD->new(dom => $xrd_dom->pop);
}

sub _xpath {
    my ( $self, $xpath, $node ) = @_;
    my $xpc = XML::LibXML::XPathContext->new;
    $xpc->registerNs( 'xrd',  'xri://$xrd*($v*2.0)' );
    $xpc->registerNs( 'xrds', 'xri://$xrds' );
    return $xpc->findnodes( $xpath, $node );
}

package XRI::XRD;

use strict;
use warnings;
use XML::LibXML;
use Class::Field qw(field);
use Error qw(:try);

field 'dom';

sub new {
    my ( $class, %args ) = @_;
    throw XRI::Exception::XRD(
        "No dom parameter to $class\::new()"
    ) unless defined $args{dom};
    my $self = bless( \%args, $class );
    $self->dom($args{dom});
    return $self;
}

sub canonical_id {
  my $self = shift;
  return _parse_priority_node($self->_xpath('xrd:CanonicalID', $self->dom));
}

sub local_ids {
  my $self = shift;
  return [ map { _parse_priority_node($_) } $self->_xpath('xrd:LocalID', $self->dom) ];
}

sub services {
  my $self = shift;
  return [ map { $self->_parse_services($_) } $self->_xpath('xrd:Service', $self->dom) ];
}

sub _parse_services {
  my ($self, $s_dom) = @_;
  my $s_hash = {};

  # FIXME: We're only parsing for Type, URI, and openid:Delegate.
  # There are a bunch of other possible elements that we're ignoring
  # because they're not important for our immediate needs. We're also
  # ignoring some attributes.

  my $priority = $s_dom->findvalue('./@priority');
  $s_hash->{priority} = $priority unless $priority eq '';

  my ($t_dom) = $self->_xpath('xrd:Type', $s_dom);
  $s_hash->{type} = $t_dom->to_literal if $t_dom;

  # FIXME: We're hard-coding a search for openid:Delegate, because
  # we know it's a commonly used SEP extension.  However, what we
  # should actually be returning is a list of all elements that don't
  # fall in the xrd namespace.
  my ($od_dom) = $self->_xpath('openid:Delegate', $s_dom);
  $s_hash->{openid_delegate} = $od_dom->to_literal if $od_dom;

  my @u_doms = $self->_xpath('xrd:URI', $s_dom);
  $s_hash->{uri} = [ map { _parse_priority_node($_) } @u_doms ] if @u_doms;

  return $s_hash;
}

sub _parse_priority_node {
  my $node_dom = shift;
  my $node_hash = {};

  my $priority = $node_dom->findvalue('./@priority');
  $node_hash->{priority} = $priority unless $priority eq '';
  $node_hash->{value} = $node_dom->to_literal;
  return $node_hash;

}

sub _xpath {
    my ( $self, $xpath, $node ) = @_;
    my $xpc = XML::LibXML::XPathContext->new;
    $xpc->registerNs( 'xrd',  'xri://$xrd*($v*2.0)' );
    $xpc->registerNs( 'xrds', 'xri://$xrds' );
    $xpc->registerNs( 'openid', 'http://openid.net/xmlns/1.0' );
    return $xpc->findnodes( $xpath, $node );
}


package XRI::Exception::XRDS;
use base qw(Error::Simple);

package XRI::Exception::XRD;
use base qw(Error::Simple);

1;
