#!perl 

use Test::More tests => 1;

BEGIN {
	use_ok( 'SOFT' );
}

diag( "Testing SOFT $SOFT::VERSION, Perl $], $^X" );
