package XRI::SEP;

use strict;
use warnings;
use Class::Field qw(field);
use Error qw(:try);
use XRI::Util qw(sort_by_priority parse_priority_node xpath);

field 'priority';
field 'openid_delegate';

# SEL. { value => $value, match => $match, select => $select }
field 'path';
field 'type';
field 'media_type';

field 'uri';   # list ref or URIs

sub new {
    my ( $class, %args ) = @_;
    my $self = bless( \%args, $class );
    $self->_parse_services($args{dom}) if $args{dom};
    return $self;
}

sub _parse_services {
    my ($self, $s_dom) = @_;
    my $s_hash = {};

    # FIXME: We're not parsing for Ref and Redirect yet.

    my $priority = $s_dom->findvalue('./@priority');
    $self->priority($priority) unless $priority eq '';

    my %SEL = ( 'xrd:Type' => sub { $self->type(@_) },
                'xrd:Path' => sub { $self->path(@_) },
                'xrd:MediaType' => sub { $self->media_type(@_) } );
    foreach my $sel (keys %SEL) {
        my @doms = &xpath($sel, $s_dom);
        my ($value, $match, $select);
        foreach my $dom (@doms) {
            $value = $dom->to_literal if $dom->to_literal;
            $match = $dom->findvalue('./@match') if !$match;
            $select = $dom->findvalue('./@select') if !$select;
        }
        if ($value or $match or $select) {
            my $s = {};
            $s->{value} = $value if $value;
            $s->{match} = $match if $match;
            $s->{select} = $select if $select;
            $SEL{$sel}->($s);
        }
    }

    # FIXME: We're hard-coding a search for openid:Delegate, because
    # we know it's a commonly used SEP extension.  However, what we
    # should actually be returning is a list of all elements that don't
    # fall in the xrd namespace.
    my ($od_dom) = &xpath('openid:Delegate', $s_dom);
    $self->openid_delegate($od_dom->to_literal) if $od_dom;

    my @u_doms = &xpath('xrd:URI', $s_dom);
    if (@u_doms) {
        my $u_list = [ map { &parse_priority_node($_) } @u_doms ];
        my @uri_h = &sort_by_priority($u_list);
        my @uris = map { $_->{value} } @uri_h;
        $self->uri(\@uris);
#        $self->uri([ &sort_by_priority($u_list) ]);
    }
#    my @uris = map { $_->{value} } map { @{$_->{uri}} } @selected;
#    return \@uris;

}


package XRI::Exception::SEP;
use base qw(Error::Simple);

1;

__END__

=head1 NAME

XRI::SEP -- Parses and represents XRD SEPs (Service Endpoints)

=head1 VERSION

Version 2.0.0

=head1 SYNOPSIS

Parses and represents Service Endpoints (SEPs).  These will almost
always be generated by XRI::XRD; users of this library should not need
to use its constructor.

    use XRI::SEP;

    my $xrd = XRI->resolve( '=eekim' );
    my @services = $xrd->services;

    foreach my $sep (@services) {
        my $priority = $sep->priority;
        my $type = $sep->type->{value};
        my $uri_list = $sep->uri;
    }

=head1 METHODS

=head2 new( dom => $xml_dom )

Constructor.  If given a DOM representing an XRD tree, populates the
appropriate data fields.  Otherwise, creates an empty SEP.

=head2 priority ( )

Returns the SEP's priority.

=head2 Selection Elements (SELs)

There are three types of SELs:

=over

=item path ( )

=item type ( )

=item media_type ( )

=back

These are accessors/mutators for a hash ref:

    { value => $value,
      match => $match,
      select => $select }

=head2 openid_delegate ( )

Returns the openid:Delegate.

=head2 uri ( )

Returns a list reference of hash references:

    [ { value => $uri, priority => $priority }, ... ]

=head1 AUTHORS

Eugene Eric Kim, E<lt>eekim@blueoxen.comE<gt>

Matthew O'Connor, E<lt>matthew@canonical.orgE<gt>

=head1 COPYRIGHT & LICENSE

(C) Copyright 2008 Blue Oxen Associates.  All rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
