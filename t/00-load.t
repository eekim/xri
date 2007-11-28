#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'XRI' );
}

diag( "Testing XRI $XRI::VERSION, Perl $], $^X" );
