package File::LinkTree;
use strict;
use vars qw($VERSION @ISA @EXPORT);
use Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw(&symlink_tree &prune_tree);
use Symbol;
use File::Recurse;
use Cwd;
use Carp;

$VERSION = '1.02';

# src => 'dir', dest => 'dir',
# verbose => 1, nop => 0, mode => 0777, ignore => [], unlink => $yes
sub symlink_tree {
    my %opt = @_;

    $opt{verbose} = 1 if $opt{nop};

    $opt{mode} ||= '777';
    if ($opt{mode} =~ /^(\d+)$/) { $opt{mode} = oct($1); }
    else { die "Bad mode $opt{mode}"; }

    $opt{ignore} ||= [];
    my $str = 'sub {my $f=shift; 0; ';
    my @re;
    for my $re (@{$opt{ignore}}) {
	if ($re =~ /^(.*)$/) { push(@re, $1); }
    }
    $str .= join(' or ', map { '$f =~ m|'.$_.'|' } @re);
    $str .= '}';
    my $is_ignored = eval $str;
    die if $@;

    # get args
    confess 'no src or no dest' if (!$opt{src} or !$opt{dest});
    my ($Src,$Dest);
    if ($opt{src} =~ /^(.*)$/) { $Src = $1; }
    if ($opt{dest} =~ /^(.*)$/) { $Dest = $1; }
    mkdir($Dest, $opt{mode}) if !-d $Dest;
    die "$Src or $Dest does not exist" if (!-d $Src or !-d $Dest);

    # get full pathnames
    my $cwd = getcwd;
    chdir($Dest) or die "chdir $Dest: $!";
    $Dest=getcwd;
    chdir($cwd) or die "chdir $cwd: $!";
    chdir($Src) or die "chdir $Src: $!";
    $Src=getcwd;

    if (!$opt{'unlink'}) {
	recurse(sub {
	    my $f = substr($_, 2);
	    my ($s,$d) = ("$Src/$f", "$Dest/$f");
	    if (-d $s) {
		if (!-e $d) {
		    if (!$opt{nop}) { mkdir($d, $opt{mode}) or die "mkdir $d: $!"; }
		} elsif (!-d $d) {
		    die "$d is not a directory while $s is a directory";
		}
	    } else { #!-d $s
		return 0 if $is_ignored->($f);
		if (-l $d) {
		    print "rm -f $d\n" if $opt{verbose};
		    if (!$opt{nop}) { (unlink($d)==1) or die "unlink $d: $!";}
		} elsif (-e $d) {
		    die "$d exists and is not a symlink";
		}
		if (-l $s) {
		    my $link = readlink($s) or die "readlink($s): $!";
		    if (!$opt{nop}) {symlink($link, $d) or die "symlink($link,$d): $!"}
		    print "ln -s $link $d\n" if $opt{verbose};
		} else {
		    if (!$opt{nop}) {symlink($s, $d) or die "symlink($s,$d): $!"}
		    print "ln -s $s $d\n" if $opt{verbose};
		}
	    }
	    0;
	}, '.');

    } else {
	recurse(sub {
	    my $f = substr($_, 2);
	    my ($s,$d) = ("$Src/$f", "$Dest/$f");
	    return 0 if (-d $s or $is_ignored->($f));
	    if (-e $d) {
		if (-l $d) {
		    my $ptr = readlink $d;
		    die "readlink $d: $!" if !$ptr;
		    if ($ptr eq $s) {
			if (!$opt{nop}) { (unlink($d)==1) or die "unlink $d: $!";}
			print "rm -f $d\n" if $opt{verbose};
		    }
		} else {
		    warn "$d is not a symlink";
		}
	    }
	    0;
	}, '.');
    }
}

sub prune_tree {
    my %opt = @_;
    confess "prune_tree(dir=>'path')" if !$opt{dir};
    chdir($opt{dir}) or die "chdir $opt{dir}: $!";
    recurse(sub {
	my $f = substr($_, 2);
	if (-l $f and !-e $f) {
	    print "rm -f $f\n" if $opt{verbose};
	    if (!$opt{nop}) { (unlink($f)==1) or die "unlink $f: $!"; }
	} elsif (-d $f) {
	    if (!$opt{nop}) {
		if (rmdir($f)) {
		    print "rmdir $f\n" if $opt{verbose};
		    return -1;
		}
	    }
	}
	0;
    }, '.');
}

1;
