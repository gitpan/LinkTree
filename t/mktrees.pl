#./perl -w

use strict;
use Cwd;
use IO::File;

-d 't' or die "Can't find t/ directory";
chdir 't' or die "Can't enter t/ directory";

my $junk = {
	    base => [qw(cond.t if.t lex.t pat.t	term.t)],
	    cmd => [qw(elsif.t for.t mod.t subval.t switch.t while.t)],
	    comp => [qw(cmdopt.t colon.t cpp.aux cpp.t decl.t multiline.t
			package.t proto.t redef.t script.t term.t use.t)],
	    io => [qw(argv.t dup.t fs.t inplace.t pipe.t
		      print.t read.t tell.t)],
	   };
		   
for my $x (1..3) {
  system("rm -rf $x");
  mkdir $x, 0777 or die "mkdir $x: $!";
  for my $s (qw(base cmd comp io)) {
    mkdir "$x/$s", 0777 or die "mkdir $x/$s: $!";
  }
}

sub toucher {
  my $fh = new IO::File;
  for my $f (@_) {
    $fh->open(">$f") or die "open $f $!";
    $fh->close;
    my $z = $f;
    $z =~ s,^.*/,,;
    symlink($z,$f.".ln") or die "symlink $!";
  }
}

for my $s (qw(base cmd)) { toucher(map { "1/$s/$_" } @{$junk->{$s}}); }
for my $s (qw(cmd comp)) { toucher(map { "2/$s/$_" } @{$junk->{$s}}); }

mkdir "3/io/io", 0777 or die "mkdir $!";
mkdir "3/io/io/io", 0777 or die "mkdir $!";
toucher(map { "3/io/io/io/$_" } @{$junk->{io}});
