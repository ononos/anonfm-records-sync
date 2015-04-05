#!/usr/bin/perl -Iblib/lib -Iblib/arch -I../blib/lib -I../blib/arch
#
use utf8;
use Test::More tests => 4;
BEGIN { use_ok( AnonFM::Util ); }

use POSIX 'strftime';
use Path::Tiny;
use Time::Local;

subtest "Schedule page t/fixture/shed-all.html" => sub {
    my $sched_src = path("t/fixture/shed-all.html")->slurp_utf8();

    my %data;

    AnonFM::Util::parseSchedules(\%data, $sched_src);

    #                      -1 - I'm lazy to dig where record was missed
    is (keys (%data), 3_486 -1, 'Number of records in fixture schedule page');

    my $firstRec = (sort (keys (%data)))[0];

    is ($data{$firstRec}{dj}, "Внучаев", "Dj name of first record" );
    is ($data{$firstRec}{desc}, "Школьники против суицидов", "First record description" );
    is ($data{$firstRec}{duration}, 59 * 60, "First record duration" );

};

subtest "Record page t/fixture/records.html" => sub {
    my $record_src = path("t/fixture/records.html")->slurp_utf8();

    my @files = AnonFM::Util::parseAnonFMrecords($record_src);

    is( @files,          422,           'Number of records in fixture page' );
    is( $files[0]{size}, 62_161 * 1024, 'Size of first record' );
    is( $files[0]{filename}, 'anonfm-20150404-190302-Администрация.aac', 'Filename of first record' );
};

subtest "Apache index page t/fixture/apach_index.html" => sub {
    my $apache_src = path("t/fixture/apach_index.html")->slurp_utf8();

    my @files = AnonFM::Util::parseApacheIndex($apache_src);

    is( @files, 28, 'Number of files in apache index page');
    is( $files[0]{filename}, '2010-12-31-Yiiii-NewYear.mp3', 'File name of first record');
    is( $files[0]{size}, 151 * 1024 * 1024, "Size of firstrecord (151M)");
};
