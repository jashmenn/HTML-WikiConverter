use 5.008;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'HTML::WikiConverter',
    'VERSION_FROM'	=> 'WikiConverter.pm', # finds $VERSION
    'PREREQ_PM'		=> {
       HTML::Entities      => 1.27,
       HTML::PrettyPrinter => 0.03,
       HTML::TreeBuilder   => 3.13,
       Image::Grab	   => 1.4,
       Image::Size	   => 2.992,
       URI		   => 1.23
    }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'WikiConverter.pm', # retrieve abstract from module
       AUTHOR     => 'diberri@yahoo.com') : ()),
     dist => { COMPRESS => 'gzip -9f', SUFFIX => 'gz' }
);
