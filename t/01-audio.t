#!/usr/bin/perl -Iblib/lib -Iblib/arch -I../blib/lib -I../blib/arch

use Test::More tests => 5;
use Data::Dumper;
use Path::Tiny;

BEGIN { use_ok( AnonFM::Util::Audio ); }

subtest "File information about korovan.mp3 (corect file)" => sub {
    my $result = AnonFM::Util::Audio::file_info("t/fixture/au/korovan.mp3");

    is( 128,     $result->{bitrate},  'Bitrate must be "128"' );
    is( 29,      $result->{duration}, 'Duration must be "29"' );
    is( 471_846, $result->{size},     'Size must be "471_846"' );
};

subtest "File information for unexist file" => sub {
    my $result = AnonFM::Util::Audio::file_info("foo bar.mp3");

    is( undef,     $result,  'result must be undef' );

};

subtest "File information about NON-audio file" => sub {
    my $result = AnonFM::Util::Audio::file_info("t/fixture/au/nonaudio.mp3");

    is( undef, $result->{bitrate},  'Bitrate must be undef' );
    is( undef, $result->{duration}, 'Duration must be undef' );
    is( 28,    $result->{size},     'Size must be 28' );


};

subtest "Create preview" => sub {
    my $tmpdir = "t/tmp/";

    path ($tmpdir)->remove_tree({save => 0});
    path ($tmpdir)->mkpath;

    subtest "mk_preview() with custom ffmpeg options" => sub {
        AnonFM::Util::Audio::mk_preview ("t/fixture/au/korovan.mp3", 't/tmp/out.ogg', {ffmpeg_cmd => "-acodec libvorbis -ab 32k -ac  1 -ar 22050"});
        ok(-e 't/tmp/out.ogg', 'Make preview by libvorbis');
    };

    subtest "mk_preview() with default aac ffmpeg options" => sub {
        AnonFM::Util::Audio::mk_preview ("t/fixture/au/korovan.mp3", 't/tmp/out.flv');
        ok(-e 't/tmp/out.flv', 'Make preview by libvorbis');
    }

}
