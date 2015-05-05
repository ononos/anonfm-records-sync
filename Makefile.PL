use strict;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => "AnonFM::Record",
    VERSION_FROM => "lib/AnonFM/Util/Audio.pm",
    AUTHOR       => 'Ononos',

    EXE_FILES => [ 'anonfm-fl-update.pl' ],

    PREREQ_PM => {
        'String::ShellQuote' => '0',
        'IPC::Cmd'           => '0',
        'Path::Tiny'         => 0,
        'Mojolicious'        => '5.54',
        'MongoDB'            => "0.702.2",
        'Config::Any::YAML'  => 0,
        'PID::File'          => '0.32'
      },

);
