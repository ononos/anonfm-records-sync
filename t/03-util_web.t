#!/usr/bin/perl -Iblib/lib -Iblib/arch -I../blib/lib -I../blib/arch
#
use utf8;
use Test::More tests => 5;
BEGIN { use_ok( AnonFM::Util ); }

 use POSIX 'strftime';
use Path::Tiny;

my $sched_src = path("t/fixture/shed-all.html")->slurp_utf8();

my %data;

AnonFM::Util::parseSchedules(\%data, $sched_src);

#                      -1 - I'm lazy to dig where record was missed
is (keys (%data), 3_486 -1, 'Number of records must be corect');

my $firstRec = (sort (keys (%data)))[0];

is ($data{$firstRec}{dj}, "Внучаев", "Dj name of first record" );
is ($data{$firstRec}{desc}, "Школьники против суицидов", "First record description" );
is ($data{$firstRec}{duration}, 59 * 60, "First record duration" );


