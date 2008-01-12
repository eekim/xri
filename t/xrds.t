use strict;
use warnings;
use Test::More qw(no_plan);

use Error qw(:try);
use YAML qw(LoadFile);

use_ok("XRI::XRDS");

CONSTRUCTOR: {
    my $xrds = XRI::XRDS->new( xml => "<xrds/>" );
    isa_ok( $xrds, "XRI::XRDS" );
}

CANONICAL_ID: {
    my $xrds = xrds_from_file("t/lib/xrds/priority_null.xrds");
    my $xrd = $xrds->last_xrd;
    is_deeply( $xrd->canonical_id, { value => '=!1001.1001.1001.1001' } );
}

PRIORITIES_ONLY_ONE: {
    my $xrds = xrds_from_file("t/lib/xrds/priority_one_local_id.xrds");
    my $xrd = $xrds->last_xrd;
    is_deeply( $xrd->local_ids, [ { value => '!1001.1001.1001.1001', priority => 10 } ] );
}

PRIORITIES_NULL: {
    my $xrds = xrds_from_file("t/lib/xrds/priority_null.xrds");
    my $xrd = $xrds->last_xrd;
    is_deeply( $xrd->local_ids,
	       [ { value => '!2001.1001.1001.1001', priority => 20}, { value => '!3001.1001.1001.1001', priority => 30},  { value => '!1001.1001.1001.1001'} ] );
}

PRIORITIES_SEPS: {
    my $xrds = xrds_from_file("t/lib/xrds/yadis.xrds");
    my $xrd = $xrds->last_xrd;
    is_deeply( $xrd->services,
	       [
		{ priority => 10,
          type => 'http://openid.net/signon/1.0', 
		  uri => [ { value => 'http://www.myopenid.com/server' } ],
		  openid_delegate => 'http://smoker.myopenid.com/'
        },
	    { priority => 50,
          type => 'http://openid.net/signon/1.0',
		  uri => [ { value => 'http://www.livejournal.com/openid/server.bml' } ],
		  openid_delegate => 'http://www.livejournal.com/users/frank/'
        },
		{ priority => 20,
          type => 'http://lid.netmesh.org/sso/2.0'
        },
		{ type => 'http://lid.netmesh.org/sso/1.0'
        }
	       ] );
}


exit;

=pod

PRIORITIES_RANDOM: {
    my $xrds = xrds_from_file("t/lib/xrds/priority_random.xrds");
    my $local_ids_first = $xrd->local_ids;
    ok( $local_ids_first->[3], '!4001.1001.1001.1001' );

    my @sorted_local_ids = sort @$local_ids_first;
    is_deeply( \@sorted_local_ids,
	       [ '!1001.1001.1001.1001', '!2001.1001.1001.1001', '!3001.1001.1001.1001', '!4001.1001.1001.1001' ] );

    my $joined_ids_first = join('', @$local_ids_first);
    my $is_same = 1;
    my $i = 0;
    do {
        my $joined_ids = join('', @$xrd->local_ids);
        $is_same = 0 if ($joined_ids ne $joined_ids_first);
        $i++;
    } while ($is_same or $i == 100);
    ok(!$is_same);
}

PRIORITIES_SEPS_RANDOM: {
    my $xrds = xrds_from_file("t/lib/xrds/priority_random.xrds");
    my $services_first = $xrd->services;

    my $joined_services_first = join('', map { $_->{type} } @$services_first);
    my $is_same = 1;
    my $i = 0;
    do {
        my $joined_services = join('', map { $_->{type} } @$xrd->services);
        $is_same = 0 if ($joined_services ne $joined_services_first);
        $i++;
    } while ($is_same or $i == 100);
    ok(!$is_same);
}

=cut

sub xrds_from_file {
    my $file = shift;
    open( my $fh, $file ) or die "Could not open ${file}: $!\n";
    my $xml = join "", <$fh>;
    close($fh);
    return XRI::XRDS->new( xml => $xml );
}

sub throws_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my ($exception, $code) = @_;
    my $got_exception = 0;
    try {
        $code->();
    } catch $exception with {
        $got_exception = 1;
    };
    ok($got_exception, "Caught $exception");
}
