use strict;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => "AnonFM::Record",
    VERSION_FROM => "lib/AnonFM/Util/Audio.pm",
    AUTHOR       => 'Ononos',

    #    EXE_FILES => [ 'csswatcher' ],

    PREREQ_PM => {
        'String::ShellQuote' => '0',
        'IPC::Cmd'           => '0',
        'Path::Tiny'         => 0,
    },
);
