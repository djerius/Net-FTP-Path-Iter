package Net::FTP::Path::Iter::Entry;

use 5.010;

# ABSTRACT: Class representing a Filesystem Entry

use strict;
use warnings;

our $VERSION = '0.07';

use Carp;
use Fcntl qw[ :mode ];

use File::Listing qw[ parse_dir ];

use namespace::clean;

use overload
  '-X'   => '_statit',
  'bool' => sub { 1 },
  '""'   => sub { $_[0]->{path} },
  ;

use Class::Tiny qw[
  name type size mtime mode parent server path
], { _has_attrs => 0 };

=begin pod_coverage

=head3 BUILD

=end pod_coverage

=cut


sub BUILD {

    my $self = shift;
    $self->_retrieve_attrs
      unless $self->_has_attrs;
}

sub _statit {

    my $self = shift;
    my $op   = shift;

    $self->_retrieve_attrs
      unless $self->_has_attrs;

    if    ( $op eq 'd' ) { return $self->is_dir }

    elsif ( $op eq 'f' ) { return $self->is_file }

    elsif ( $op eq 's' ) { return $self->size }

    elsif ( $op eq 'z' ) { return $self->size != 0 }

    elsif ( $op eq 'r' ) { return S_IROTH & $self->mode }

    elsif ( $op eq 'R' ) { return S_IROTH & $self->mode }

    elsif ( $op eq 'l' ) { return 0 }

    else { croak( "unsupported file test: -$op\n" ) }

}

sub _get_entries {

    my ( $self, $path ) = @_;

    my $server = $self->server;

    my $pwd = $server->pwd;

    # on some ftp servers, if $path is a symbolic link, dir($path)
    # willl return a listing of $path's own entry, not of its
    # contents.  as a work around, explicitly cwd($path),
    # get the listing, then restore the working directory

    my @entries;
    eval {
        $server->cwd( $path )
          or croak( "unable to chdir to ", $path, "\n" );

        my $listing = $server->dir( '.' )
          or croak( "error listing $path" );

        for my $entry ( parse_dir( $listing ) ) {

            my %attr;
            @attr{qw[ name type size mtime mode]} = @$entry;
            $attr{parent}                         = $path;
            $attr{_has_attrs}                     = 1;

            push @entries, \%attr;

        }
    };

    my $err = $@;

    $server->cwd( $pwd )
      or croak( "unable to return to directory: $pwd\n" );

    croak( $err ) if $err;


    return \@entries;

}

# COPYRIGHT

1;

__END__

=pod

=method is_dir

  $bool = $entry->is_dir;

returns true if the entry is a directory.

=method is_file

  $bool = $entry->is_file;

returns true if the entry is a file.

=attr mode

The entry mode as returned by L<stat>.

=attr mtime

The entry modification time.

=attr name

The entry name.

=attr path

The complete path to the entry

=attr parent

The parent directory of the entry

=attr server

The L<Net::FTP> server object

=attr size

The size of the entry

=attr type

The type of the entry, one of

=over

=item f

file

=item d

directory

=item l

symbolic link. See however L<Net::FTP::Path::Iter/Symbolic Links>

=item ?

unknown


=back

=cut


=head1 DESCRIPTION

A B<Net::FTP::Path::Iter::Entry> object represents an entry in the remote
FTP filesystem.  It is rarely seen in the wild. Rather,
L<Net::FTP::Path::Iter> uses the subclasses B<Net::FTP::Path::Iter::Entry::File>
and B<Net::FTP::Path::Iter::Entry::Dir> when passing paths to callbacks or
returning paths to iterators.  These subclasses have no unique methods
or attributes of their own; they only have those of this, their parent
class.

