# This code was written in 1996 by Aaron Sherman and contributed to
# the public domain. Please leave the documentation intact as a curtesy
# to the author.

package File::Recurse;

require Exporter;
use Carp;

@ISA=qw(Exporter);
@EXPORT=qw(recurse);

$File::Recurse::MAX_DEPTH = 100;
$File::Recurse::FOLLOW_SYMLINKS = 0;

$File::Recurse::VERSION = '1.0';

sub VERSION {
    return $File::Recurse::VERSION;
}

sub recurse (&$;$$) {
    my $exe = shift;
    my $dir = shift;
    my $context = shift;
    my $level = shift;
    my $file;
    my $ret = 0;
    local *D;
    local $_;

    $level = 0 unless defined $level;
    return undef if (!-d $dir);
    croak("Recursion ran too deep on $dir")
      if $level > $File::Recurse::MAX_DEPTH;
    opendir(D,$dir) || return horf($dir);
    while(defined($file = readdir D)) {
	next if ($file eq '.' || $file eq '..');
	my $path = "$dir/$file";
	my $is_dir = -d $path;
	$_ = $path;
	$ret = &$exe($path,$context);
	next if ($ret == -1);
	last if ($ret == -2);

	if ($is_dir) {
	    next if (-l $path && !$File::Recurse::FOLLOW_SYMLINKS);
	    $ret = recurse($exe,$path,$context,$level+1);
	    last if ($ret == -2);
	}
    }
    closedir D;

    return $ret;
}

sub horf ($) {
    my $dir = shift;
    carp("Cannot open directory: $dir") if $File::Recurse::WARNINGS;
    return 0;
}

1;

__END__

=head1 NAME

File::Recurse - Recurse over files, performing some function.

=head1 SYNOPSIS

	use File::Recurse;
	use File::Copy;

	recurse { print } "/tmp";
	recurse {copy($_,"elsewhere") if -f $_} "dir";
	recurse(\&func, "/");

=head1 DESCRIPTION

The C<File::Recurse> module is designed for performing an operation
on a tree of directories and files. The basic usage is simmilar
to the F<find.pl> library. Once one uses the File::Recurse module,
you need only call the C<recurse> function in order to perform
recursive directory operations.

The function takes two parameters a function reference and a
directory. The function referenced by the first parameter
should expect to take one
parameter: the full path to the file currently being operated on. This
function is called once for every file and directory under the
directory named by the second parameter.

For example:

	recurse(\&func, "/");

would start at the top level of the filesystem and call "func"
for every file and directory found (not including "/").

Perl allows a second form of calling this function which can be
useful for situations where you want to do something simple in
the function. In these cases, you can define an anonymous function
by using braces like so:

	recurse {print $_[0]} "/";

This would print every file and directory in the filesystem. However,
as an added convenience you can access the pathname in the variable
C<$_>. So the above could be rewritten as:

	recurse { print } "/";

=head2 Context

There is an optional third parameter which can be any scalar value
(including a reference). This value is ignored by recurse, but will be
passed as the second parameter to the user-defined function. This can
be useful for building library routines that use recurse, so that
they do not have to pass state to the function as global variables.

=head2 Controling Recursion

If you want to control how recursion happens, you have several
options. First, there are some global variables that affect the overall
operation of the recurse routine:

=over 5

=item C<$MAX_DEPTH>

This variable controls how far down a tree of directories recurse
will go before it assumes that something bad has happened. Default:
100.

=item C<$FOLLOW_SYMLINKS>

This variable tells recurse if it should descend into directories that are
symbolic links. Default: 0.

=back

Normally, the return value of the function called is not used, but
if it is -1 or -2, there is a special action taken.

If the function returns -1 and the current filename refers to a
directory, recurse will B<not> descend into that directory. This
can be used to prune searches and focus only on those directories
which should be followed.

If the function returns -2, the search is terminated, and recurse
will return. This can be used to bail when a problem occurs, and you
don't want to exit the program, or to end the search for some
file once it is found.

=head1 SEE ALSO

L<File::Tools>

=head1 AUTHOR

Written in 1996 by Aaron Sherman, ajs@ajs.com
