#-*-perl-*-

use ExtUtils::MakeMaker;
WriteMakefile(NAME => 'File::LinkTree',
	      PREREQ_PM => { File::Recurse => 0 },
	      EXE_FILES => ['linktree'],
	      VERSION_FROM => 'LinkTree.pm',
              'dist' => {COMPRESS=>'gzip -9f', SUFFIX => 'gz'},
	      );
