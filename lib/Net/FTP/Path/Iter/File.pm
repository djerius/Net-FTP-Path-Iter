package Net::FTP::Path::Iter::File;

# ABSTRACT: Class representing a File

use 5.010;
use strict;
use warnings;

our $VERSION = '0.02';

use strict;
use warnings;

use Carp;

use File::Spec::Functions qw[ catfile ];

use namespace::clean;

use parent 'Net::FTP::Path::Iter::Entry';

use constant is_file => 1;
use constant is_dir  => 0;

# if an entity doesn't have attributes, it didn't get loaded
# from a directory listing.  Try to get one.
sub _retrieve_attrs {

    my $self = shift;
    return if $self->_has_attrs;

    my ( $entry ) = my @entries = grep $self->name eq $_->{name},
      $self->get_entries( $self->parent );

    croak( "multiple ftp entries for ", $self->path, "\n" )
      if @entries > 1;

    croak( "unable to find attributes for ", $self->path, "\n" )
      if @entries == 0;

    croak( $self->{path}, ": expected file, got $entry->type\n" )
      unless $entry->{type} eq 'f';

    $self->$_( $entry->{$_} ) for keys %$entry;

    return;
}

# COPYRIGHT

1;

=head1 DESCRIPTION

B<Net::FTP::Path::Iter::File> is a class representing a file entry. It is a subclass
of L<Net::FTP::Path::Iter::Entry>; see it for all available methods.


