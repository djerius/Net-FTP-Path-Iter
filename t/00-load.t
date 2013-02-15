#!perl -T

use Test::More tests => 1;

BEGIN {
  use_ok('Net::FTP::Rule');
}

diag( "Testing Net::FTP::Rule $Net::FTP::Rule::VERSION, Perl $], $^X" );
