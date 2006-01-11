use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'HTML::WikiConverter',
    AUTHOR              => 'David J. Iberri <diberri@cpan.org>',
    VERSION_FROM        => 'lib/HTML/WikiConverter.pm',
    ABSTRACT_FROM       => 'lib/HTML/WikiConverter.pm',
    PL_FILES            => {},
    EXE_FILES           => [ 'bin/html2wiki' ],
    PREREQ_PM => {
        'Test::More'     => 0,
        'HTML::Tree'     => 3.18,
        'URI'            => 1.35,
        'HTML::Entities' => 1.27,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'HTML-WikiConverter-*' },
);
