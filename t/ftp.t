#! perl


use Test2::Bundle::Extended;

use Net::FTP::Rule;
use Test::Mock::Net::FTP;

use File::Temp 'tempdir';
use File::Path 'make_path';
use File::Spec::Functions qw[ catfile catdir ];

# work around bug in Test::Mock::Net::FTP v 0.02
# https://rt.cpan.org/Ticket/Display.html?id=121532
{
    use File::Spec::Functions qw[ splitdir rootdir ];

    no warnings 'redefine';
    sub Test::Mock::Net::FTP::mock_default_cwd {
        my ( $self, $dirs ) = @_;

        if ( !defined $dirs ) {
            $self->{mock_cwd} = rootdir();
            $dirs = "";
        }
        elsif ( $dirs =~ m|^/| ) {
            $self->{mock_cwd} = rootdir();
        }

        my $backup_cwd = $self->_mock_cwd;
        for my $dir ( splitdir( $dirs ) ) {
            $self->_mock_cwd_each( $dir );
        }
        $self->{mock_cwd} =~ s/^$self->{mock_server_root}//;  #for absolute path
        return $self->_mock_check_pwd( $backup_cwd );
    }
}

# create a fake FTP site with the following layout:
# p
# |-- a
# |   |-- 1
# |   |-- 2
# |   `-- 3
# |-- b
# |   |-- 4
# |   |-- 5
# |   `-- 6
# `-- c
#     |-- 7
#     |-- 8
#     `-- 9

sub mk_ftpdir {

    chdir( my $dir = tempdir );

    my $f = 0;

    for my $td ( qw[ a b c ] ) {
        my $tdd = catdir( 'p', $td );
        make_path( $tdd );
        open( my $fh, '>', catfile( $tdd, ++$f ) ) for 0, 1, 2;
    }

    return $dir;

}

my $ftpdir = mk_ftpdir;

Test::Mock::Net::FTP::mock_prepare(
    'net.ftp.rule' => {
        anonymous => {

            password => 'secret',
            dir      => [ $ftpdir, '/' ],
        } }

);

my $mock = mock 'Net::FTP' => (

    override => [
        new => sub {
            my $class = shift;
            return Test::Mock::Net::FTP->new( @_ );
        },
    ],

);


my $ftp = Net::FTP::Rule->new(
    'net.ftp.rule',
    user     => 'anonymous',
    password => 'secret'
);

my $expected = bag {
    item "$_ d" for qw[ . p p/a p/b p/c ];

    item "$_ f" for qw[
      p/a/1
      p/a/2
      p/a/3
      p/b/4
      p/b/5
      p/b/6
      p/c/7
      p/c/8
      p/c/9
    ];
    end();
};


my @got;

ok(
    lives {
        $ftp->all(
            '.',
            {
                visitor => sub {
                    push @got, $_ . ' ' . $_->{type};
                },
            }
          ),
    },
    'traverse',
) or die $@;


is( \@got, $expected, "listing" );

done_testing;
