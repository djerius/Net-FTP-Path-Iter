# NAME

Net::FTP::Path::Iter - Iterative, recursive, FTP file finder

# VERSION

version 0.05

# SYNOPSIS

    use Net::FTP::Path::Iter;

    # connect to the FTP site
    my $ftp = Net::FTP::Path::Iter->new( $ftp_site, $user, $password );

    # define a visitor callback routine. It will recieve a
    # Net::FTP::Path::Iter::Entry object.
    sub visitor { my ($entry) = @_ }

    # use the Path::Iterator::Rule all() method to traverse the
    # site;
    $ftp->all( '/', \&visitor );

# DESCRIPTION

**Net::FTP::Path::Iter** is a subclass of [Path::Iterator::Rule](https://metacpan.org/pod/Path%3A%3AIterator%3A%3ARule) which
iterates over an FTP site rather than a local filesystem.

See the documentation [Path::Iterator::Rule](https://metacpan.org/pod/Path%3A%3AIterator%3A%3ARule) for how to filter and
traverse paths.  When **Net::FTP::Path::Iter** passes a path to a callback or
returns one from an iterator, it will be in the form of a
[Net::FTP::Path::Iter::Entry](https://metacpan.org/pod/Net%3A%3AFTP%3A%3APath%3A%3AIter%3A%3AEntry) object.

**Net::FTP::Path::Iter** uses [Net::FTP](https://metacpan.org/pod/Net%3A%3AFTP) to connect to the FTP site.

## Symbolic Links

At present, **Net::FTP::Path::Iter** does not handle symbolic links. It will
output an error and skip them.

# METHODS

## new

    $ftp = Net::FTP::Path::Iter->new( [$host], %options );

Open up a connection to an FTP host and log in.  The arguments
are the same as for ["new" in Net::FTP](https://metacpan.org/pod/Net%3A%3AFTP#new), with the addition of two
mandatory options,

- `user`

    The user name

- `password`

    The password

# INTERNALS

# ATTRIBUTES

**Net::FTP::Path::Iter** subclasses [Path::Iter::Rule](https://metacpan.org/pod/Path%3A%3AIter%3A%3ARule). It is a hash based object
and has the following additional attributes:

- `server`

    The **Net::FTP** object representing the connection to the FTP server.

# SUPPORT

## Bugs

Please report any bugs or feature requests to bug-{{ lc $dist->name }}@rt.cpan.org  or through the web interface at: https://rt.cpan.org/Public/Dist/Display.html?Name={{ $dist->name }}

## Source

Source is available at

    https://gitlab.com/djerius/{{ lc $dist->name }}

and may be cloned from

    https://gitlab.com/djerius/{{ lc $dist->name }}.git

# AUTHOR

Diab Jerius <djerius@cpan.org>

# COPYRIGHT AND LICENSE

This software is Copyright (c) 2017 by Smithsonian Astrophysical Observatory.

This is free software, licensed under:

    The GNU General Public License, Version 3, June 2007
