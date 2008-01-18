use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'XRI',
    AUTHOR              => 'Eugene Eric Kim <eekim@blueoxen.com>',
    VERSION_FROM        => 'lib/XRI.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Class::Field' => 0,
        'Error' => 0,
        'LWP::UserAgent' => 0,
        'Test::More' => 0,
        'Text::Balanced' => 0,
        'XML::LibXML' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'XRI-*' },
);
