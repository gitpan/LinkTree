=head1 NAME

File::LinkTree - Manage Symlink Trees (Shadow Directories)

=head1 SYNOPSIS

   symlink_tree($opt);
   prune_tree($opt);

=head1 DESCRIPTION

Hopefully, you can just use the command line program:

  usage: linktree [-n] [-v] [-m 0777] [-u] (<src>|-f LINKTREES) <dest>
           -f <trees>    link all the directories listed in <trees>
           -m <mode>     create directories with <mode>
           -u            unlink
           If $LINKTREE_BASE is set, <dest> may be omitted.
 
         linktree -p [-n] [-v] [-f LINKTREES] <dir>
           -p            prune bad links under <dir> (or $LINKTREE_BASE)
           -f <trees>    sends the results to <trees>
 
           -n            no operation mode
           -v            verbose (print all commands)

=cut

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

$VERSION = '1.05';

=head2 symlink_tree($opt)

Symlinks are made with absolute paths.  Absolute paths take a little
more disk space, but they should be faster and they are more easily
analyzed (see prune_tree).

C<$opt> is a hash ref.  Required parameters are:

  src => 'dir',
  dest => 'dir',
  unlink => $yes

Optional parameters are:

  verbose => 1,
  nop => 0,
  silent => 1,
  mode => 0777,
  cwd => 'dir',

=cut

sub symlink_tree {
    my ($o) = @_;

    $o->{'cwd'} ||= getcwd;
    chdir($o->{'cwd'}) or die "chdir $o->{'cwd'}: $!";

    $o->{nop} ||= 0;
    $o->{dec_mode} ||= oct($o->{mode} || '777');

    # get args
    my ($Src,$Dest) = ($o->{src}, $o->{dest});
    die "Directory $Src does not exist" if !-d $Src;
    if (!-d $Dest) {
      my $d;
      for my $d1 (split(m'/+', $Dest)) {
	$d .= "$d1/";
	if (!-d $d) { mkdir($d, $o->{dec_mode}) or die "mkdir $Dest: $!"; }
      }
    }
    
    # get full pathnames
    chdir($Dest) or die "chdir $Dest: $!";
    $Dest=getcwd;

    chdir($o->{'cwd'}) or die "chdir $o->{'cwd'}: $!";
    chdir($Src) or die "chdir $Src: $!";
    $Src=getcwd;

    print "symlink_tree $Src $Dest\n" if $o->{verbose};

    if (!$o->{'unlink'}) {
	recurse(sub {
	    my $f = substr($_, 2);
	    my ($s,$d) = ("$Src/$f", "$Dest/$f");
	    if (-d $s) {
		if (!-e $d) {
		    if (!$o->{nop}) { mkdir($d, $o->{dec_mode}) or die "mkdir $d: $!"; }
		} elsif (!-d $d) {
		    die "Tree conflict: $s is a directory, but $d is not";
		}
	    } else { #!-d $s
		if (-l $d) {
		    warn "Stomping symlink: $d\n" if !$o->{silent};
		    print "rm -f $d\n" if $o->{verbose};
		    if (!$o->{nop}) { (unlink($d)==1) or die "unlink $d: $!";}
		} elsif (-e $d) {
		    if ($o->{force}) {
			if (!$o->{nop}) { (unlink($d)==1) or die "unlink $d: $!";}
		    } else {
			warn "$d exists and is not a symlink\n";
			return 0;
		    }
		}
		if (-l $s) {
		    my $link = readlink($s) or die "readlink($s): $!";
		    if (!$o->{nop}) {symlink($link, $d) or die "symlink($link,$d): $!"}
		    print "ln -s $link $d\n" if $o->{verbose};
		} else {
		    if (!$o->{nop}) {symlink($s, $d) or die "symlink($s,$d): $!"}
		    print "ln -s $s $d\n" if $o->{verbose};
		}
	    }
	    0;
	}, '.');

    } else {
	recurse(sub {
	    my $f = substr($_, 2);
	    my ($s,$d) = ("$Src/$f", "$Dest/$f");
	    return 0 if -d $s;
	    if (-e $d) {
		if (-l $d) {
		    my $ptr = readlink $d;
		    die "readlink $d: $!" if !$ptr;
		    if ($ptr eq $s) {
			if (!$o->{nop}) { (unlink($d)==1) or die "unlink $d: $!";}
			print "rm -f $d\n" if $o->{verbose};
		    }
		} else {
		    warn "Not a symlink: $d\n" if !$o->{silent};
		}
	    }
	    0;
	}, '.');
    }
}

=head2 prune_tree($opt)

C<$opt> is a hash ref.  Required parameters are:

  dir => 'dir'

Optional parameters are:

  trees => "dir/LINKTREES",
  verbose => 1,
  nop => 0,
  silent => 1,

=cut

sub prune_tree {
  my ($o) = @_;
  
  $o->{trees} ||= "$o->{dir}/LINKTREES";
  
  my $fh = new IO::File;
  $fh->open(">$o->{trees}") or die "open >$o->{trees}: $!";
  my %trees;
  
  chdir $o->{dir} or die "chdir $o->{dir}: $!";
  
  print "prune_tree $o->{dir}\n" if $o->{verbose};
  
  recurse(sub {
	    my $f = substr($_, 2);
	    if (-l $f) {
	      if (!-e $f) {
		print "rm -f $f\n" if $o->{verbose};
		if (!$o->{nop}) { (unlink($f)==1) or die "unlink $f: $!"; }
	      } else {
		my $path = readlink($f);
		my $plen = length($path) - length($f) ;
		if ($plen > 0 and substr($path, $plen) eq $f) {
		  -- $plen;
		  my $base = substr($path, 0, $plen);
		  my $sub = substr($path, $plen);
		  $sub =~ s,^(.*)/.*?$,$1,;
		  $trees{ $base } = $sub if !exists $trees{ $base };
#		  warn join(' ', $base, $trees{ $base }, $sub)."\n";
		  while (length $trees{ $base }) {
		    last if $trees{ $base } eq $sub;
		    $sub =~ s,^(.*)/.*?$,$1,;
		    $trees{ $base } =~ s,^(.*)/.*?$,$1,;
		  }
		}
	      }
	    } elsif (-f $f) {
	      if ("$o->{dir}/$f" ne $o->{trees}) {
		warn "Not a symlink: $f\n" if !$o->{silent};
	      }
	    } elsif (-d $f) {
	      if (!$o->{nop}) {
		if (rmdir($f)) {
		  print "rmdir $f\n" if $o->{verbose};
		  return -1;
		}
	      }
	    }
	    0;
	  }, '.');
  
  if (!$o->{nop}) {
    for my $k (sort keys %trees) {
      my $v = $trees{$k};
#      warn "$k $v";
      $fh->print($k.($v? " $v":'')."\n");
    }
  }
}

1;
__END__;

=head1 BUGS

Needs more complex regression tests.

=head1 AUTHOR

Copyright (c) 1997 Joshua Nathaniel Pritikin.  All rights reserved.
This package is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

