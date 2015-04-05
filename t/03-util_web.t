#!/usr/bin/perl -Iblib/lib -Iblib/arch -I../blib/lib -I../blib/arch
#
use utf8;
use Test::More tests => 5;
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

subtest "Google Drive parse page" => sub {
    my $gd_page = path("t/fixture/nikita_gd.html")->slurp_utf8();

    my $data = AnonFM::Util::parseGoogleDrivePage($gd_page);

    is ( @{$data->{folders}}, 30, "Number of folders in sample google drive page");
    is ( $data->{folders}[0]{filename}, '2012-10', "First folder name");
    is ( $data->{folders}[0]{id}, '0B6HMhe4i6iXGVWdlck83eHBmVjQ', "Google Id of first folder");

    is ( @{$data->{files}}, 293, "Number of files in sample google drive page");
    is ( $data->{files}[0]{filename}, '1346082313.mp3', "First file name");
    is ( $data->{files}[0]{id}, '0B6HMhe4i6iXGRjhqenE3X1RNdFk', "Google Id of first file");

}
