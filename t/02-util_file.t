#!/usr/bin/perl -Iblib/lib -Iblib/arch -I../blib/lib -I../blib/arch

use Test::More tests => 9;
use Time::Local;


BEGIN { use_ok( AnonFM::Util ); }

subtest "anonfm-20121230-002201-TrollStation.mp3" => sub {
    my ( $dj, $timestamp ) = AnonFM::Util::parseFilename('anonfm-20121230-002201-TrollStation.mp3');
    is( $timestamp, timelocal( 1, 22, 0, 30, 11, 2012 ), 'Time' );
    is( $dj, 'TrollStation', "Dj name");
};

subtest "anonfm-bomjway-20120810-130145.aac" => sub {
    my ( $dj, $timestamp ) = AnonFM::Util::parseFilename('anonfm-bomjway-20120810-130145.aac');
    is( $timestamp, timelocal( 45, 1, 13, 10, 7, 2012 ), 'Time' );
    is( $dj, 'bomjway', "Dj name");
};

subtest "anonfm-20140610-anonfm-1402408800.mp3-ХуиТа.mp3" => sub {
    my ( $dj, $timestamp ) = AnonFM::Util::parseFilename('anonfm-20140610-anonfm-1402408800.mp3-ХуиТа.mp3');
    is( $timestamp, 1402408800, 'Time' );
    is( $dj, 'ХуиТа', "Dj name");
};


subtest "stream.2013-11-30.200123.mp3" => sub {
    my ( $dj, $timestamp ) = AnonFM::Util::parseFilename('stream.2013-11-30.200123.mp3');
    is( $timestamp, timelocal( 23, 1, 20, 30, 10, 2013 ), 'Time' );
    is( $dj, 'unkown', "Dj name");
};

subtest "stream.2013-05-12.2202270-Искусственный интеллект.mp3" => sub {
    my ( $dj, $timestamp ) = AnonFM::Util::parseFilename('stream.2013-05-12.2202270-Искусственный интеллект.mp3');
    is( $timestamp, timelocal( 27, 2, 22, 12, 4, 2013 ), 'Time' );
    is( $dj, 'Искусственный интеллект', "Dj name");
};

subtest "ANONFM-20121211-191411.mp3" => sub {
    my ( $dj, $timestamp ) = AnonFM::Util::parseFilename('ANONFM-20121211-191411.mp3');
    is( $timestamp, timelocal( 11, 14, 19, 11, 11, 2012 ), 'Time' );
    is( $dj, 'unkown', "Dj name");
};

subtest "2012-03-12-Гикский четверг.mp3" => sub {
    my ( $dj, $timestamp ) = AnonFM::Util::parseFilename('2012-03-12-Гикский.четверг.mp3');
    is( $timestamp, timelocal( 0, 0, 0, 12, 2, 2012 ), 'Time' );
    is( $dj, 'Гикский.четверг', "Dj name");
};

subtest "1349296444.mp3" => sub {
    my ( $dj, $timestamp ) = AnonFM::Util::parseFilename('1349296444.mp3');
    is( $timestamp, 1349296444, 'Time' );
    is( $dj, 'unkown', "Dj name");
};
