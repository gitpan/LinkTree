#-*-perl-*-
BEGIN { $| = 1; $tx=1; print "1..1\n"; }

sub ok { print "ok $tx\n"; $tx++; }
sub not_ok { print "not ok $tx\n"; $tx++; }

unlink("t/out.new", "t/err.new");
system("rm -r t/u 2>/dev/null");

my $redir = '1>>t/out.new 2>>/dev/null';
system("$^X -Mblib -w linktree --verbose t/1 t/u $redir")==0 or die 1;
system("$^X -Mblib -w linktree --verbose t/2 t/u $redir")==0 or die 2;
system("$^X -Mblib -w linktree --verbose --unlink t/1 t/u $redir")==0 or die 3;
system("$^X -Mblib -w prunetree --verbose t/u $redir")==0 or die 4;

system($^X, '-pi', '-e', 's, \S*/t/, T/,g;', glob('t/*.new'))==0 or die 'fixup';

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
