use strict;
use warnings;
use inc::Module::Install;

name 'Net-FTP-Rule';
license 'gpl3';
auto_license( holder => 'Smithsonian Astrophysical Observatory' );
all_from 'lib/Net/FTP/Rule.pm';

requires 'Net::FTP';
requires 'File::Listing';
requires 'Path::Iterator::Rule';

author_tests( 'xt' );
author_requires 'Test::NoBreakpoints';
author_requires 'Test::Pod';
author_requires 'Test::Pod::Coverage';
author_requires 'Test::Perl::Critic';

tests_recursive;

build_requires 'Test::More';

auto_install;

WriteAll;
