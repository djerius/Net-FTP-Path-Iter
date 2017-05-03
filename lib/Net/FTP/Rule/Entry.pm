package Net::FTP::Rule::Entry;

use 5.010;

# ABSTRACT: Class representing a Filesystem Entry

use strict;
use warnings;
use experimental 'switch';

our $VERSION = '0.01';

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

sub _statit {

    my $self = shift;
    my $op   = shift;

    $self->_retrieve_attrs
      unless $self->_has_attrs;

    for ( $op ) {

        when ( 'd' ) { return $self->is_dir }

        when ( 'f' ) { return $self->is_file }

        when ( 's' ) { return $self->size }

        when ( 'z' ) { return $self->size != 0 }

        when ( 'r' ) { return S_IROTH & $self->mode }

        when ( 'R' ) { return S_IROTH & $self->mode }

        when ( 'l' ) { return 0 }

        default { croak( "unsupported file test: -$op\n" ) }

    }

}

sub _get_entries {

    my ( $self, $path ) = @_;

    my $listing = $self->server->dir( $path )
      or croak( "error listing $path" );

    my @entries;
    for my $entry ( parse_dir( $listing ) ) {

        my %attr;
        @attr{qw[ name type size mtime mode]} = @$entry;
        $attr{parent}                         = $path;
        $attr{_has_attrs}                      = 1;

        push @entries, \%attr;

    }

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

symbolic link. See however L<Net::FTP::Rule/Symbolic Links>

=item ?

unknown


=back

=cut


=head1 DESCRIPTION

A B<Net::FTP::Rule::Entry> object represents an entry in the remote
FTP filesystem.  It is rarely seen in the wild. Rather,
L<Net::FTP::Rule> uses the subclasses B<Net::FTP::Rule::Entry::File>
and B<Net::FTP::Rule::Entry::Dir> when passing paths to callbacks or
returning paths to iterators.  These subclasses have no unique methods
or attributes of their own; they only have those of this, their parent
class.

