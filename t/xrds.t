use strict;
use warnings;
use Data::Dumper;
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
    is( $xrd->canonical_id, '=!1001.1001.1001.1001' );
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
    my $services = $xrd->services;

    is($services->[0]->priority, 10);
    is_deeply($services->[0]->type, { value => 'http://openid.net/signon/1.0' });
    is_deeply($services->[0]->uri, [ 'http://www.myopenid.com/server' ]);
    is($services->[0]->openid_delegate, 'http://smoker.myopenid.com/');

    is($services->[1]->priority, 50);
    is_deeply($services->[1]->type, { value => 'http://openid.net/signon/1.0' });
    is_deeply($services->[1]->uri, [ 'http://www.livejournal.com/openid/server.bml' ]);
    is($services->[1]->openid_delegate, 'http://www.livejournal.com/users/frank/');

    is($services->[2]->priority, 20);
    is_deeply($services->[2]->type, { value => 'http://lid.netmesh.org/sso/2.0' });
    ok(!$services->[2]->uri);
    ok(!$services->[2]->openid_delegate);

    ok(!$services->[3]->priority);
    is_deeply($services->[3]->type, { value => 'http://lid.netmesh.org/sso/1.0' });
    ok(!$services->[3]->uri);
    ok(!$services->[3]->openid_delegate);

}

PRIORITIES_RANDOM: {
    my $xrds = xrds_from_file("t/lib/xrds/priority_random.xrds");
    my $xrd = $xrds->last_xrd;
    my @local_ids_first = $xrd->local_ids_by_priority;
    is( $local_ids_first[3], '!4001.1001.1001.1001' );

    my @sorted_local_ids = sort @local_ids_first;
    is_deeply( \@sorted_local_ids,
	       [ '!1001.1001.1001.1001', '!2001.1001.1001.1001', '!3001.1001.1001.1001', '!4001.1001.1001.1001' ] );

    # The probability of calling $self->local_ids_by_priority for this data
    # set and getting the exact same list every time is (1/6)^n, where n is
    # the number of times you call this method.  Calculating exactly how close
    # this is to zero is left as an exercise to the reader.

    my $joined_ids_first = join('', @local_ids_first);
    my $is_same = 1;
    my $i = 0;
    do {
        my $joined_ids = join('', $xrd->local_ids_by_priority);
        $is_same = 0 if ($joined_ids ne $joined_ids_first);
        $i++;
    } while ($is_same and $i < 1000);
    ok(!$is_same);
}

PRIORITIES_SEPS_RANDOM: {
    my $xrds = xrds_from_file("t/lib/xrds/service_end_points.xrds");
    my $xrd = $xrds->last_xrd;
    my @services_first = $xrd->services_by_priority;

    # See comment in PRIORITIES_RANDOM for the risk assessment of this test
    # failing (assuming the code is correct, which of course, it is).

    my $joined_services_first = join('', map { $_->{type} } @services_first);
    my $is_same = 1;
    my $i = 0;
    do {
        my $joined_services = join('', map { $_->{type} } $xrd->services_by_priority);
        $is_same = 0 if ($joined_services ne $joined_services_first);
        $i++;
    } while ($is_same and $i < 1000);
    ok(!$is_same);
}

PRIORITIES_SEPS_RANDOM: {
    my $xrds = xrds_from_file("t/lib/xrds/random_uris.xrds");
    my $xrd = $xrds->last_xrd;
    my ($service) = $xrd->services_by_priority;

    # See comment in PRIORITIES_RANDOM for the risk assessment of this test
    # failing (assuming the code is correct, which of course, it is).

    my $joined_uris_first = join('', @{$service->{uri}});
    my $is_same = 1;
    my $i = 0;
    do {
        my ($service) = $xrd->services_by_priority;
        my $joined_uris = join '', @{$service->{uri}};
        $is_same = 0 if ($joined_uris ne $joined_uris_first);
        $i++;
    } while ($is_same and $i < 1000);
    ok(!$is_same);
}

SEP_MATCH: {
    my $xrds = xrds_from_file("t/lib/xrds/yadis.xrds");
    my $xrd = $xrds->last_xrd;
    my $sep = $xrd->service_endpoints;
    is_deeply($sep, []);

    $sep = $xrd->service_endpoints(type=>'http://openid.net/signon/1.0');
    isa_ok($sep->[0], 'XRI::SEP');
    is_deeply($sep->[0]->uri,
        [ 'http://www.myopenid.com/server' ]);
    is_deeply($sep->[1]->uri,
        [ 'http://www.livejournal.com/openid/server.bml' ]);

    $xrds = xrds_from_file("t/lib/xrds/drummond.xrds");
    $xrd = $xrds->last_xrd;
    $sep = $xrd->service_endpoints(type=>'http://openid.net/signon/1.0');
    is_deeply($sep->[0]->uri,
        [ 'https://2idi.com/openid/',
          'http://2idi.com/openid/' ]);

    $sep = $xrd->service_endpoints(path=>'(+index)');
    is_deeply($sep->[0]->uri,
        [ 'http://2idi.com/forwarding/' ]);
}


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
