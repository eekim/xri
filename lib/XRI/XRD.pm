package XRI::XRD;

use strict;
use warnings;
use Class::Field qw(field);
use Error qw(:try);
use XRI::SEP;
use XRI::Util qw(sort_by_priority parse_priority_node xpath);

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
    return &xpath('xrd:CanonicalID|xrds:CanonicalID', $self->dom)->to_literal;
}

sub local_ids {
    my $self = shift;
    return [ map { &parse_priority_node($_) }
             &xpath('xrd:LocalID|xrds:LocalID', $self->dom) ];
}

sub local_ids_by_priority {
    my $self = shift;
    return map { $_->{value} } &sort_by_priority($self->local_ids);
}

sub services {
    my $self = shift;
    return [ map { XRI::SEP->new(dom => $_) }
             &xpath('xrd:Service', $self->dom) ];
}

sub services_by_priority {
    my $self = shift;
    return &sort_by_priority($self->services);
}

sub service_endpoints {
    my ($self, %service_match) = @_; # (path => p, type => t, media_type => m)

    my $sel_state = {};
    my @all_services =  $self->services_by_priority;
    my @selected;
    my @default;
    $service_match{path} =~ s/^\/// if $service_match{path};

    SEP: foreach my $sep (@all_services) {
        my $ss = {
            path => { positive => 0, default => 0 },
            type => { positive => 0, default => 0 },
            media_type => { positive => 0, default => 0 }
        };
        my %sep_sel = (
            path => sub { $sep->path(@_) },
            type => sub { $sep->type(@_) },
            media_type => sub { $sep->media_type(@_) },
        );
        foreach my $sel ('path', 'type', 'media_type') {
            my $sel_h = $sep_sel{$sel}->();
            my $regexp = quotemeta($service_match{$sel}) if $service_match{$sel};

            if ($sel_h) {
                if ($sel eq 'type' or $sel eq 'media_type') {   # 13.3.6|8
                    if ( $sel_h->{value} and $service_match{$sel} and
                         ($sel_h->{value} eq $service_match{$sel}) ) {
                        if ($sel_h->{select} and $sel_h->{select} eq 'true') {   # 13.4.2
                            push @selected, $sep;
                            next SEP;
                        }
                        else {
                            $ss->{$sel}->{positive} = 1;
                        }
                    }
                }
                elsif ($sel eq 'path') {   # 13.3.7
                    if ( $sel_h->{value} and $service_match{$sel} and
                         ($sel_h->{value} =~ /^$regexp/) ) {
                        if ($sel_h->{select} and $sel_h->{select} eq 'true') {   # 13.4.2
                            push @selected, $sep;
                            next SEP;
                        }
                        else {
                            $ss->{$sel}->{positive} = 1;
                        }
                    }
                }
                if ( ( $sel_h->{match} and
                       ( ($sel_h->{match} eq 'any') or
                         ($sel_h->{match} eq 'non-null' and $sel_h->{value}) or
                         ($sel_h->{match} eq 'null' and !$service_match{$sel}) ) )
                     or (!$sel_h->{match} and !$sel_h->{value})   # 13.3.4
                   ) {   # 13.3.2
                    $ss->{$sel}->{positive} = 1;
                }
                elsif ($sel_h->{match} and $sel_h->{match} eq 'default') {   # 13.3.1
                    $ss->{$sel}->{default} = 1;
                }
            }
            else {   # 13.3.3
                $ss->{$sel}->{default} = 1;
            }
        } # endfor SEL

        if ( $ss->{path}->{positive} and $ss->{type}->{positive}
             and $ss->{media_type}->{positive} ) {   # 13.4.3
            push @selected, $sep;
        }
        elsif ( ( $ss->{path}->{positive} or $ss->{path}->{default} ) and
               ( $ss->{type}->{positive} or $ss->{type}->{default} ) and
               ( $ss->{media_type}->{positive} or
                 $ss->{media_type}->{default} ) ) {   # 13.4.4
            push @default, $sep;
        }
        $sel_state->{$sep} = $ss;
    } # endfor SEP

    if (!@selected) {   # 13.5.2
        foreach my $sep (@default) {
            my $ss = $sel_state->{$sep};
            if ( ($ss->{path}->{positive} and $ss->{type}->{positive}) or
                 ($ss->{type}->{positive} and $ss->{media_type}->{positive}) or
                 ($ss->{path}->{positive} and $ss->{media_type}->{positive}) ) {
                push @selected, $sep;
            }
        }
        if (!@selected) {
            foreach my $sep (@default) {
                my $ss = $sel_state->{$sep};
                if ( $ss->{path}->{positive} or $ss->{type}->{positive} or
                     $ss->{media_type}->{positive} ) {
                    push @selected, $sep;
                }
            }
        }
        push @selected, @default if !@selected;
    }

    return @selected;
}


package XRI::Exception::XRD;
use base qw(Error::Simple);

1;

__END__

=head1 NAME

XRI::XRD -- Parses and represents XRD (XRI Descriptor) data

=head1 VERSION

Version 2.0.0

=head1 SYNOPSIS

Parses and represents XRI descriptors.  These will almost always be
generated by XRI::XRDS; users of this library should not need to use
its constructor.

    use XRI::XRD;

    my $xrd = XRI->resolve( '=eekim' );
    my $canonical_id = $xrd->canonical_id;
    my @local_ids   = $xrd->local_ids_by_priority;
    my @services    = $xrd->services_by_priority;

=head1 METHODS

=head2 new( dom => $xml_dom )

Constructor.  Given a DOM representing an XRD tree, populates the
appropriate data fields.

=head2 canonical_id ( )

Returns the XRI's CanonicalID.

=head2 local_ids ( )

Returns the XRI's LocalIDs in the order listed in the XRD.  We should
probably make this and services() private methods, as you should
almost always use local_ids_by_priority() instead.

Returns a list reference of hash references:

    [ { value => $value, priority => $priority }, ... ]

=head2 local_ids_by_priority( )

Returns a list of LocalIDs in order of priority.  This will not
necessarily return the same list each time it's called, because items
of equal priority are randomly sorted.

=head2 services( )

Returns a list of XRI::SEP objects in the order listed in the XRD.  We
should probably make this a private method, as you should almost
always use either services_by_priority() or service_endpoints().

=head2 services_by_priority( )

Returns a list of XRI::SEP objects in order of priority.  This will
not necessarily return the same list each time it's called, because
items of equal priority are randomly sorted.

=head2 service_endpoints ( path => $p, type => $t, media_type => $m )

Returns a list of XRD::SEP objects corresponding to the parameters
passed.

=head1 ACCESSORS / MUTATORS

These are essentially private methods, although they may be useful for
debugging.

=head2 dom( )

Returns the DOM representation of the XRD data that instantiated this
class.

=head1 NOTES

We aren't parsing and representing all fields in an XRD yet.  We chose
to focus on the fields we need for resolution (with the exception of
Ref and Redirect).

The services hash is a good candidate for being refactored into its
own class.

=head1 AUTHORS

Eugene Eric Kim, E<lt>eekim@blueoxen.comE<gt>

Matthew O'Connor, E<lt>matthew@canonical.orgE<gt>

=head1 COPYRIGHT & LICENSE

(C) Copyright 2008 Blue Oxen Associates.  All rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
