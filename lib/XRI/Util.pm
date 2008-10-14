package XRI::Util;

use strict;
use warnings;

use base 'Exporter';
our @EXPORT_OK = ('sort_by_priority', 'parse_priority_node', 'xpath');

sub sort_by_priority {
    my $unsorted_list_ref = shift;
    my $p_hash;  # keys are priorities

    foreach my $item (@$unsorted_list_ref) {
        push @{$p_hash->{$item->{priority} || 0}}, $item;
    }
    return map &_random_sort($p_hash->{$_}), sort { $a <=> $b } keys %$p_hash;
}

sub _random_sort {
    my $list_ref = shift;
    my @rand_sorted;
    while (@$list_ref) {
        my $i = int(rand(scalar(@$list_ref)));
        push @rand_sorted, splice @$list_ref, $i, 1;
    }
    return @rand_sorted;
}

sub parse_priority_node {
    my $node_dom = shift;
    my $node_hash = {};

    my $priority = $node_dom->findvalue('./@priority');
    $node_hash->{priority} = $priority unless $priority eq '';
    $node_hash->{value} = $node_dom->to_literal;
    return $node_hash;
}

sub xpath {
    my ( $xpath, $node ) = @_;
    my $xpc = XML::LibXML::XPathContext->new;
    $xpc->registerNs( 'xrd',  'xri://$xrd*($v*2.0)' );
    $xpc->registerNs( 'xrds', 'xri://$xrds' );
    $xpc->registerNs( 'openid', 'http://openid.net/xmlns/1.0' );
    return $xpc->findnodes( $xpath, $node );
}


1;

__END__

=head1 NAME

XRI::Util -- Utility functions for XRI

=head1 VERSION

Version 2.0.0

=head1 SYNOPSIS

Utility functions used by several of the XRI::* classes, mostly
related to parsing XML data structures with priority attributes.

All three of the included functions may be exported for convenient
use.

    use XRI::Util qw( sort_by_priority parse_priority_node xpath );

=head1 FUNCTIONS

=head2 sort_by_priority ( $unsorted_list )

Given a list ref:

    [ { value => $v, priority => $p }, ... ]

returns a list of values sorted by priority according to Section 4.3.3
of the XRI 2.0 spec.

=head2 parse_priority_node ( $node_dom, $node_hash )

Given an XML node with a priority attribute ($node_dom), parses it and returns:

    { value => $v, priority => $p }

in $node_hash.

=head2 xpath ( $xpath, $node )

Searches the $xpath expression in the node tree with root $node, and
returns a list of XML::LibXML::Node.

=head1 AUTHORS

Eugene Eric Kim, E<lt>eekim@blueoxen.comE<gt>

Matthew O'Connor, E<lt>matthew@canonical.orgE<gt>

=head1 COPYRIGHT & LICENSE

(C) Copyright 2008 Blue Oxen Associates.  All rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
