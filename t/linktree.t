#-*-perl-*-
BEGIN { $| = 1; $tx=1; print "1..1\n"; }

sub ok { print "ok $tx\n"; $tx++; }
sub not_ok { print "not ok $tx\n"; $tx++; }

delete $ENV{LINKTREE_BASE};
use IO::File;
use File::Recurse;

system("rm -r t/u 2>/dev/null");

my $step=1;
my $out = new IO::File;
$out->open(">t/out.new") or die "open t/out.new";

sub inspect {
    print $out "$step\n";
    ++ $step;
    my @l;
    recurse(sub {
	my $f = $_;
	if (-l $f) {
	    my $to = readlink($f);
	    $to =~ s,^\S*/t/,t/,;
	    push(@l, "$f -> $to\n");
	} else {
	    push(@l, "$f\n");
	}
    }, 't/u');
    print $out sort(@l);
}

my $redir = '2>>/dev/null';
system("$^X -Mblib -w linktree t/1 t/u $redir")==0 or die $step;
&inspect;
system("$^X -Mblib -w linktree t/2 t/u $redir")==0 or die $step;
&inspect;
system("$^X -Mblib -w linktree -u t/1 t/u $redir")==0 or die $step;
&inspect;
system("$^X -Mblib -w linktree -p t/u $redir")==0 or die $step;
&inspect;

$out->close;

# Also see module 'Test::Output'
sub check {
    my ($new,$old) = @_;
    if (-e $old) {
	if (system("diff $old $new")==0) {
	    unlink $new;
	    ok;
	} else {
	    not_ok;
	}
    } else {
	system("mv $new $old")==0? ok:not_ok;
    }
}

check("t/out.new", "t/out.good");
#check("t/err.new", "t/err.good");
