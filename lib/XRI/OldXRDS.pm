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
    $self->_get_xrd;
    return $self;
}

sub get_by_priority {
    my ( $self, $tag ) = @_;
    $self->_get_highest_priority($tag);
}

sub _get_highest_priority {
    my ( $self, $tag ) = @_;
    my $nodes = $self->_get_node_with_priority($tag);
    return [ map { $_->{node}->to_literal } @$nodes ];
}

sub _parse {
    my $self   = shift;
    my $parser = XML::LibXML->new;
    $self->dom( $parser->parse_string( $self->xml ) );
    $self->root( $self->dom->documentElement );
}

sub _get_xrd {
    my $self = shift;
    my ($xrd) = $self->_xpath( "xrd:XRD", $self->root );
    $self->xrd($xrd);
}

sub _get_node_with_priority {
    my ( $self, $tag ) = @_;
    my @id_nodes = $self->_xpath( "xrd:$tag", $self->xrd );
    my @id_info;

    for my $id_node (@id_nodes) {
        my $priority = $id_node->findvalue('./@priority') || 0;
        push @id_info, {
            priority => $priority,
            node     => $id_node,
        };
    }

    return \@id_info;
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
