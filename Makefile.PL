use 5.012000;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Diffbot::Client',
    VERSION_FROM      => 'lib/Diffbot/Client.pm', # finds $VERSION
    PREREQ_PM         => { # e.g., Module::Name => 1.1
        'Carp'              => 0,
        'Data::Dump'        => 0,
        'JSON'              => 0,
        'LWP::UserAgent'    => 0,
    },
    BUILD_REQUIRES    => {
        'Getopt::Long'      => 0,
        'Test::Deep'        => 0,
        'Test::Fake::HTTPD' => 0,
        'Test::More'        => 0,
        'Test::Exception'   => 0,
    },
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Diffbot/Client.pm', # retrieve abstract from module
       AUTHOR         => 'Kyle Zeeuwen <kyle.zeeuwen@gmail.com>') : ()
    ),
);
