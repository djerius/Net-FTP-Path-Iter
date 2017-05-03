package Net::FTP::Rule;

# ABSTRACT: Iterative, recursive, FTP file finder

use 5.010;

use strict;
use warnings;
use Carp;

our $VERSION = '0.01';

use Net::FTP;
use File::Spec::Functions qw[ splitpath ];

use parent 'Path::Iterator::Rule';

use Net::FTP::Rule::Dir;

use namespace::clean;

=method new

  $ftp = Net::FTP::Rule->new( [$host], %options );

Open up a connection to an FTP host and log in.  The arguments
are the same as for L<Net::FTP/new>, with the addition of two
mandatory options,

=over

=item C<user>

The user name

=item C<password>

The password

=back

=cut


sub new {

    my $class = shift;

    my %attr;
    if (@_ % 2) {
        my $host = shift;
        %attr  = @_;
        $attr{Host} = $host;
    }
    else {
        %attr = @_;
    }

    my $self = $class->SUPER::new();

    defined( my $host = delete $attr{Host} )
      or croak( "missing Host attribute\n" );

    defined( my $user = delete $attr{user} )
      or croak( "missing user attribute\n" );

    defined( my $password = delete $attr{password} )
      or croak( "missing password attribute\n" );

    $self->{server} = Net::FTP->new($host, %attr)
      or croak("unable to connect to server $host\n");

    $self->{server}->login( $user, $password )
      or croak("unable to log in to $host\n");

    return $self;
}

sub _defaults {
    return (
        _stringify      => 0,
        follow_symlinks => 1,
        depthfirst      => 0,
        sorted          => 1,
        loop_safe       => 0,
        error_handler   => sub { die sprintf( "%s: %s", @_ ) },
        visitor         => undef,
    );
}

sub _fast_defaults {

    return (
        _stringify      => 0,
        follow_symlinks => 1,
        depthfirst      => -1,
        sorted          => 0,
        loop_safe       => 0,
        error_handler   => undef,
        visitor         => undef,
    );
}

sub _objectify {

    my ( $self, $path ) = @_;

    my ( $volume, $directories, $name ) = splitpath($path);

    $directories =~ s{(.+)/$}{$1};

    my %attr = (
        parent  => $directories,
        name => $name,
        path => $path,
    );

    return Net::FTP::Rule::Dir->new( server => $self->{server}, %attr );
}

sub _children {

    my ( $self, $path ) = @_;

    return map { [ $_->{name}, $_ ] } $path->_children;
}

sub _iter {

    my $self     = shift;
    my $defaults = shift;

    $defaults->{loop_safe} = 0;

    $self->SUPER::_iter( $defaults, @_ );

}

1;

# COPYRIGHT

__END__

=head1 SYNOPSIS

    use Net::FTP::Rule;

    # connect to the FTP site
    my $ftp = Net::FTP::Rule->new( $ftp_site, $user, $password );

    # define a visitor callback routine. It will recieve a
    # Net::FTP::Rule::Entry object.
    sub visitor { my ($entry) = @_ }

    # use the Path::Iterator::Rule all() method to traverse the
    # site;
    $ftp->all( '/', \&visitor );

=head1 DESCRIPTION

B<Net::FTP::Rule> is a subclass of L<Path::Iterator::Rule> which
iterates over an FTP site rather than a local filesystem.

See the documentation L<Path::Iterator::Rule> for how to filter and
traverse paths.  When B<Net::FTP::Rule> passes a path to a callback or
returns one from an iterator, it will be in the form of a
L<Net::FTP::Rule::Entry> object.

B<Net::FTP::Rule> uses L<Net::FTP> to connect to the FTP site.

=head2 Symbolic Links

At present, B<Net::FTP::Rule> does not handle symbolic links. It will
output an error and skip them.


=head1 ATTRIBUTES

B<Net::FTP::Rule> subclasses L<Path::Iter::Rule>. It is a hash based object
and has the following additional attributes:

=over

=item C<server>

The B<Net::FTP> object representing the connection to the FTP server.

=back

=head1 SEE ALSO

