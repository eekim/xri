package XRI;
use strict;
use warnings;
use Class::Field qw(field);
use Error qw(try);
use Text::Balanced qw(extract_bracketed);
use LWP::UserAgent;
use XRI::XRDS;

our $VERSION = '2.0';

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

    # FIXME: do we need this?  are there other ok values?
    my $service_type = 'xri://$res*auth*($v*2.0)'; 

    unless (defined $xri) {
        throw XRI::Exception::ExpectedXRI(
            "XRI->resolve() expects an XRI (or URI) as an argument"
        );
    }

    if ($xri =~ m{^https?://}) {
      # TODO: resolve the URL and parse the XRDS document on the other end.
      # This will need refactoring.
    }
    else {
      $self = $class->new($xri);
    }

    my $authorities = $ROOT_AUTHORITIES{$self->root};
    my $xrd;
    my @segments = @{$self->{segments}};
    while (my $segment = shift @segments) {
      $xrd = _resolve_segment($authorities, $segment);
      if (@segments) {
        $authorities = _get_service_endpoints($xrd, $service_type);
      }
    }
    return $xrd;
    # return XRI::XRD;
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

  die;  # none of the authorites worked.
}

sub _get_xrds_from_authority {
   my ($authority, $segment) = @_;
   my $ua = LWP::UserAgent->new;
   $ua->default_header( "Accept" => "application/xrds+xml" );
   my $join = ($authority =~ m{/$}) ? "" : "/";
   $| = 1;
   print "GETTING: $authority$join$segment\n";
   my $response = $ua->get($authority . $join . $segment);
   print $response->content if $response->is_success;
   print "\n=================================================\n";
   return $response->content if $response->is_success;
   die "could not get xrds from $authority for $segment"; # could not get XRDS
}

sub _get_service_endpoints {
   my ($xrd, $service_type) = @_;
   my @all_services =  $xrd->services_by_priority;
   my @wanted_services = grep { $_->{type} eq $service_type } @all_services;
   my @uris = map { $_->{value} } map { @{$_->{uri}} } @wanted_services;
   return \@uris;
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
        throw XRI::Exception::InvalidXRI("Root not found in $xri");
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
