package AnonFM::Util;

use utf8;
use strict;
use warnings;

use Carp;
use Time::Local;

=head1 NAME

AnonFM::Util - some utils for parsing

=head1 EXPORT

=head2 parseFilename($filename)

Parse filename

    my ($dj, $timestamp) = parseFilename('anonfm-20121230-002201-TrollStation.mp3);

=cut

sub parseFilename {
    my $filename = shift;

    my ($dj, $timestamp);

    # tresh rg host on nikita google drive or .part
    return if ($filename =~m /(^rg-)|(.part$)/);

    # like this anonfm-20121230-002201-TrollStation.mp3
    if ($filename =~ m/^anonfm[-]+(\d\d\d\d)(\d\d)(\d\d)-(\d\d)(\d\d)(\d\d)-(.*?)\.\w+$/) {
        my ($year, $month, $day, $hour, $min, $sec) = ($1, $2, $3, $4, $5, $6);
        $dj = $7;
        $timestamp = timelocal ($sec, $min, $hour, $day, $month-1, $year);
    } elsif 
        # anonfm-bomjway-20120810-130145.aac
        ($filename =~ m/^anonfm-(.*?)-(\d\d\d\d)(\d\d)(\d\d)-(\d\d)(\d\d)(\d\d)\.\w+$/) {
        my ($year, $month, $day, $hour, $min, $sec) = ($2, $3, $4, $5, $6, $7);
        $dj = $1;
        $timestamp = timelocal ($sec, $min, $hour, $day, $month-1, $year);
    } elsif
        # special case 'anonfm-20140610-anonfm-1402408800.mp3-ХуиТа.mp3'
        # fuck it!
        ($filename =~ m/^anonfm-.*?-anonfm-(\d+).\w+-(.*?)\.\w+$/) {
        $dj = $2;
        $timestamp = $1;
    } elsif
        # special case stream.2013-05-12.2202270-Искусственный интеллект.mp3
        ($filename =~ m/(\d\d\d\d)-(\d\d)-(\d\d)[.-](\d\d)(\d\d)(\d\d)\d*-(.*?)\.\w+$/) {
        $dj = $7;
        $timestamp = timelocal ($6, $5, $4, $3, $2 - 1, $1);
    } elsif
        # special case stream.2013-11-30.200123.mp3
        ($filename =~ m/(\d\d\d\d)-(\d\d)-(\d\d)[.-](\d\d)(\d\d)(\d\d)/) {
        $timestamp = timelocal ($6, $5, $4, $3, $2 - 1, $1);
        $dj = 'unkown';
    } elsif
        # special case ANONFM-20121211-191411
        ($filename =~ m/anonfm-(\d\d\d\d)(\d\d)(\d\d)-(\d\d)(\d\d)(\d\d)/i) {
        $timestamp = timelocal ($6, $5, $4, $3, $2 - 1, $1);
        $dj = 'unkown';
    } elsif
        # special case 2012-03-12-Гикский четверг.mp3
        ($filename =~ m/(\d\d\d\d)-(\d\d)-(\d\d)-(.*?)\.\w+$/) {
        $timestamp = timelocal (0, 0, 0, $3, $2 - 1, $1);
        $dj = $4;
    } elsif
        # noway, maybe we have unix time like this 1349296444.mp3
        ($filename =~ m/((\d{10}))/) {
        $dj = 'unkown';
        $timestamp = $1;
    }
    return ($dj, $timestamp);
}


1;
