use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'SOFT',
    AUTHOR              => 'Alex Sorokine <SorokinA@ornl.gov>',
    VERSION_FROM        => 'lib/SOFT.pm',
    ABSTRACT_FROM       => 'lib/SOFT.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES    => {},
    EXE_FILES	=> [ 'bin/soft2gv.pl', 'bin/softmatch.pl', 'bin/soft2list.pl' ],
    PREREQ_PM => {
        'Test::More' => 0,
        'Text::CSV' => 0,
        'Text::Wrap' => 0,
        'Convert::Color' => 0,
        'Tie::RegexpHash' => 0.15,
	'HTML::Entities' => 0,
	'Text::Soundex' => 0
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'SOFT-*' },
);
