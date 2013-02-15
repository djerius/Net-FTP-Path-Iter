# --8<--8<--8<--8<--
#
# Copyright (C) 2013 Smithsonian Astrophysical Observatory
# This file is part of Net::FTP::Rule
#
# Net::FTP::Rule is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at
# your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# -->8-->8-->8-->8--

package Net::FTP::Rule;

use 5.12.0;

use strict;
use warnings;
use Carp;

our $VERSION = '0.01';

use parent 'Path::Iterator::Rule';
use Net::FTP;
use Net::FTP::File;
use File::Spec::Functions qw[ catfile catdir splitpath];

{

    package Net::FTP::Rule::Entity;

    use 5.12.0;
    use Carp;

    use File::Listing qw[ parse_dir ];
    use Fcntl ':mode';

    sub new {

        my $class = shift;

        my %attr = 'HASH' eq ref $_[0] ? %{ $_[0] } : @_;

        return bless \%attr, $class

    }

    use overload
      '-X'   => 'statit',
      'bool' => sub { 1 },
      '""'   => sub { $_[0]->path },
      ;

    sub statit {

        my $self = shift;
        my $op   = shift;

        for ($op) {

            when ('d') { return $self->is_dir }

            when ('f') { return $self->is_file }

            when ('s') { return $self->{size} }

            when ('z') { return $self->{size} != 0 }

            when ('r') { return S_IROTH & $self->{mode} }

            when ('R') { return S_IROTH & $self->{mode} }

            default { croak("unsupported file test: -$op\n") }

        }

    }

    sub get_attr {

        my ( $self, $path, my %attr ) = @_;

        my $listing = $self->{server}->dir($path)
          or die("error listing $path");

        my @entries;
        for my $entry ( parse_dir($listing) ) {

            my %lattr = %attr;

            @lattr{qw[ name type size mtime mode]} = @$entry;

            push @entries, \%lattr;

        }

        return \@entries;

    }

}

{

    package Net::FTP::Rule::File;
    use strict;
    use warnings;

    use Carp;

    use parent -norequire, 'Net::FTP::Rule::Entity';

    use constant is_file => 1;
    use constant is_dir  => 0;

    use File::Spec::Functions qw[ catfile ];

    sub path {

        my $self = shift;

        $self->{path} //= catfile( $self->{dir}->path, $self->{name} );

        return $self->{path};
    }

    # if an entity doesn't have attributes, it didn't get loaded
    # from a directory listing.  Try to get one.
    sub attrs {

        my $self   = shift;
        my $server = $self->{server};

        my $entries = $self->get_attr( $self->path );
        croak( "multiple records for ", $self->path, "\n" )
          if @$entries > 1;

        my $entry = grep { $self->{name} eq $_->[0] } @$entries;

        croak( "unable to find attributes for ", $self->path, "\n" )
          if !$entry;

        croak( $self->path, ": expected file, got $entry->{type}\n" )
          unless $entry->{type} eq 'f';

        %$self = ( %$entry, %$self );

        return;
    }

}

{

    package Net::FTP::Rule::Dir;
    use strict;
    use warnings;

    use Carp;

    use parent -norequire, 'Net::FTP::Rule::Entity';

    use constant is_file => 0;
    use constant is_dir  => 1;

    use Fcntl ':mode';

    use File::Spec::Functions qw[ catdir splitdir ];

    sub path {

        my $self = shift;

        $self->{path} //= catdir( $self->{dir}->path, $self->{name} );

        return $self->{path};
    }

    sub children {

        my ($self) = @_;

        my $entries = $self->get_attr(
            $self->path,
            dir    => $self,
            server => $self->{server}
        );

        my @children;

        for my $entry (@$entries) {

            my $obj;

            for ( $entry->{type} ) {

                when ('d') {

                    $obj = Net::FTP::Rule::Dir->new($entry);
                }

                when ('f') {

                    $obj = Net::FTP::Rule::File->new($entry);

                }

                default {

                    warn("ignoring $entry->{name}; unknown type $_\n");

                }

            }

            push @children, $obj;
        }

        return @children;

    }

    # if an entity doesn't have attributes, it didn't get loaded
    # from a directory listing.  Try to get one.  This should
    # happen rarely, so do this slowly but correctly.
    sub attrs {

        my $self   = shift;
        my $server = $self->{server};

        my $pwd = $server->pwd;

        my $entry = {};

        $server->cwd( $self->path )
          or croak( "unable to chdir to ", $self->path, "\n" );

        # File::Listing doesn't return . or .. (and some FTP servers
        # don't return that info anyway), so try to go up a dir and
        # look for the name
        eval {

            # cdup sometimes returns ok even if it didn't work
            $server->cdup;

            if ( $pwd ne $server->pwd ) {

                my $entries = $self->get_attr('.');

                ($entry) = grep { $self->{name} eq $_->{name} } @$entries;

                croak( "unable to find attributes for ", $self->path, "\n" )
                  if !$entry;

                croak( $self->path,
                    ": expected directory, got $entry->{type}\n" )
                  unless $entry->{type} eq 'd';

            }

            # couldn't go up a directory; at the top?
            else {

                # fake it.

                $entry = {
                    size  => 0,
                    mtime => 0,
                    mode  => S_IRUSR | S_IXUSR | S_IRGRP | S_IXGRP | S_IROTH |
                      S_IXOTH
                };

            }

        };

        my $err = $@;

        $server->cwd($pwd)
          or croak("unable to return to directory: $pwd\n");

        croak($err) if $err;

        %$self = ( %$entry, %$self );

        return;
    }

}

sub new {

    my $class = shift;

    my ( $server, $user, $password ) = @_;

    my $self = $class->SUPER::new();

    $self->{server} = Net::FTP->new($server)
      or die("unable to connect to server $server\n");

    $self->{server}->login( $user, $password )
      or die("unable to log in to $server\n");

    return $self;
}

sub _objectify {

    my ( $self, $path ) = @_;

    my ( $volume, $directories, $file ) = splitpath($path);

    $directories =~ s{(.+)/$}{$1};

    my %attr = (
        dir  => $directories,
        name => $file,
        path => $path,
    );

    my $object =
      $self->{server}->isdir($path)
      ? Net::FTP::Rule::Dir->new( server => $self->{server}, %attr )
      : Net::FTP::Rule::File->new( server => $self->{server}, %attr );

    $object->attrs;

    return $object;

}

sub _children {

    my ( $self, $path ) = @_;

    return map { [ $_->{name}, $_ ] } $path->children;

}

sub _iter {

    my $self     = shift;
    my $defaults = shift;

    $defaults->{loop_safe} = 0;

    $self->SUPER::_iter( $defaults, @_ );

}

1;

__END__

=head1 NAME

Net::FTP::Rule - [One line description of module's purpose here]


=head1 SYNOPSIS

    use Net::FTP::Rule;

=for author to fill in:
    Brief code example(s) here showing commonest usage(s).
    This section will be as far as many users bother reading
    so make it as educational and exeplary as possible.


=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=head1 INTERFACE

=for author to fill in:
    Write a separate section listing the public components of the modules
    interface. These normally consist of either subroutines that may be
    exported, or methods that may be called on objects belonging to the
    classes provided by the module.


=head1 DIAGNOSTICS

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.

Net::FTP::Rule requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.


=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-net-ftp-rule@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/Public/Dist/Display.html?Name=Net-FTP-Rule>.

=head1 SEE ALSO

=for author to fill in:
    Any other resources (e.g., modules or files) that are related.


=head1 VERSION

Version 0.01

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2013 The Smithsonian Astrophysical Observatory

Net::FTP::Rule is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or (at
your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=head1 AUTHOR

Diab Jerius  E<lt>djerius@cpan.orgE<gt>
