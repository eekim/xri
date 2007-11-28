use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'XRI',
    AUTHOR              => 'Eugene Eric Kim <eekim@blueoxen.com>',
    VERSION_FROM        => 'lib/XRI.pm',
    ABSTRACT_FROM       => 'lib/XRI.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'XRI-*' },
);
