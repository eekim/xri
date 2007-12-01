use strict;
use warnings;
use Test::More qw(no_plan);

use Error qw(:try);
use YAML qw(LoadFile);

use_ok("XRI");

CONSTRUCTOR: {
    throws_ok(
        "XRI::Exception::ExpectedXRI",
        sub { XRI->new() },
    );
}

PARSE_FAILURE: {
    # Must start w/ GCS
    throws_ok(
        "XRI::Exception::InvalidXRI",
        sub {
            XRI->new( "i_do_not_start_with_a_gcs" );
        },
    );
}

TEST_GOOD_XRIS: {
    my $tests = LoadFile( "t/lib/good_xris.yaml" );
    for my $xri (sort keys %$tests) {
        xri_parse_ok(
            $xri, 
            $tests->{$xri},
        );
    }
}

TEST_BAD_XRIS: {
    my $tests = LoadFile( "t/lib/bad_xris.yaml" );
    for my $xri (@$tests) {
        pass("Testing that $xri does not parse");
        throws_ok(
            "XRI::Exception::InvalidXRI",
            sub { XRI->new($xri) },
        );
    }
}

sub xri_parse_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my ($xri, $test) = @_;

    my $root = $test->{root};
    my $segments = $test->{segments};
    my $path = $test->{path};
    my $query = $test->{query};
    my $fragment = $test->{fragment};

    my $obj = XRI->new($xri);
    pass("TESTING: $xri");
    isa_ok($obj, "XRI");
    is($obj->root, $root, "Testing XRI root is \"$root\"");

    SKIP: {
        skip("path/query/fragment parsing not implemented yet.", 3);
        is($obj->path, $path, "Check XRI path is \"$path\"");
        is($obj->query, $query, "Testing XRI query is \"$query\"");
        is($obj->fragment, $fragment, "Check XRI fragment is \"$fragment\"");
    }

    is(
        scalar(@{$obj->segments}), 
        scalar(@$segments), 
        "Check we got same number of segments",
    );

    my $n = @$segments;
    for my $i (1 .. $n) {
        is(
            $obj->segments->[$i-1],
            $segments->[$i-1],
            "Testing for segment " . $segments->[$i-1] . " at position $i",
        );
    }
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
