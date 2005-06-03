use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'HTML::WikiConverter',
    'VERSION_FROM'	=> 'WikiConverter.pm', # finds $VERSION
    'PREREQ_PM'		=> {
      'HTML::Tree'     => 3.18,
      'URI'            => 1.35,
      'HTML::Entities' => 1.27,
    }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'WikiConverter.pm', # retrieve abstract from module
       AUTHOR     => 'David Iberri <diberri@yahoo.com>') : ()),
);
