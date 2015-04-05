package AnonFM::Util::Audio;

use strict; 
use warnings;

use Data::Dumper;

use Carp;
use IPC::Cmd qw[run can_run];
use String::ShellQuote qw/shell_quote/;

our $VERSION = '0.1.0';

=head1 NAME

AnonFM::Util::Audio - audio utils

=head1 SYNOPSIS

   use AnonFM::Util::Audio;

   my $res = AnonFM::Util::Audio::file_info("audio.mp3")
   # $res = {bitrate => .., duration => .., size => ..}

   # default is `-acodec libfdk_aac` codec
   mk_preview ("t/fixture/au/korovan.mp3", "/tmp/out.aac);

=head1 DESCRIPTION

Audio utils, get info about audio file, make audio preview.

=cut

our %badformats;		#  File suffix that have  problem with
                                # `sox`, piped `ffmpeg` use instead.

use constant FFMPEG_CMD => "-acodec libfdk_aac -profile:a aac_he -ab 12k -ac  1 -ar 22050";
use constant FFMPEG => "ffmpeg";

use constant CHUNKS => 30;
use constant TEMPO => 1.5;

=head1 EXPORTS

=head2 file_info($filename)

Return hash or undef if file not exist file. Keys:

=over 2

=item bitrate

Number or undef

=item duration

Number or undef

=item size

File size.

=back

=cut

sub file_info {
    my $file = shift;

    return unless -e $file;

    my $res;

    my ( $ok, $err, $full_buf, $stdout_buf, $stderr_buf ) =
      run( command => [ 'ffmpeg', '-i', $file ], verbose => 0 );

    my $stderr = join '', @{$stderr_buf};
    if ( my ( $hr, $min, $sec ) =
        ( $stderr =~ m/Duration: (\d+):(\d+):(\d+)/ ) )
    {
        $res->{duration} = 3600 * $hr + 60 * $min + $sec;
    }
    if ( $stderr =~ m/bitrate: (\d+)/ ) {
        $res->{bitrate} = $1;
    }
    $res->{size} = -s $file;

    return $res;

}

=head2 mk_preview ($in_filename, $out_filename, $options)

Build short preview of audio file.

   mk_preview ("t/fixture/au/korovan.mp3", "/tmp/out.flv", {ffmpeg_cmd => "-acodec libfdk_aac -profile:a aac_he -ab 12k -ac  1 -ar 22050"});

For option see sox()

=cut

sub mk_preview {
  my $filename = shift;
  my $outname = shift;
  my $options = shift;

  my $duration = 0;
  print "Make preview for: $filename\n";

  my $fileinfo = file_info ($filename);
  $duration = $fileinfo->{duration};

  print " File: $filename " . " duration: " . $fileinfo->{duration} . " bitrate: " . $fileinfo->{bitrate} . "\n";

  my @trims;
  if ($duration == 0) {
    print " Skipped.\n";
    return $fileinfo;
  } elsif ($duration < 364 ) {	# less 6min trim to 1.5min
    push @trims, (0, 120);
  } else {
      my $chunks;
      if ($duration < 1500) {	# less 25 min
	  $chunks = CHUNKS
      } elsif ($duration < 4200) { # less 1.5 hour
	  $chunks = CHUNKS * 1.5;
      } else {
	  $chunks = CHUNKS * 2
      }
      my $seek = int (( (1 / TEMPO) * $duration - ($chunks * 9)) / $chunks);
      foreach (1 .. $chunks) {
	  push @trims, ($seek, 1, 2, 1, 3, 1);
      }
  }
  sox ($filename, $outname, \@trims, $options);

  return $fileinfo;
}

=head2 sox ($in, $outname, $trims, $options)

    push @trims, (0, 1, 2, 1, 3, 1);
    sox ('file.aac', '/tmp/file.flv', \@trims)

=head3 Options:

=over 2

=item tempo

Audio tempo. Default 1.5

=item ffmpeg

FFMPEG bin file, default "ffmpeg"

=item ffmpeg_cmd

FFMPEG codec command line. (Be sure that extension compatible too).

Default:

     "-acodec libfdk_aac -profile:a aac_he -ab 12k -ac  1 -ar 22050"

=back

=cut

sub sox {
    my ( $in, $outfile, $trims, $options ) = @_;

    my ($sufix) = $outfile =~ m /\.([^.]*)/;

    my $tmpname = $outfile . '.tmp.' . $sufix;

    # piped version, sox + ffmpeg
    if ( exists $badformats{$sufix} ) {
        my $cmd =
            'ffmpeg -i '
          . shell_quote($in)
          . ' -loglevel panic -f sox - | sox -p -t .wav - tempo '
          . ($options->{tempo} // TEMPO)
          . ' trim '
          . join( ' ', @{$trims} )
          . ' | ffmpeg -y -i - '
          . ($options->{ffmpeg_cmd} // FFMPEG_CMD) . ' '
          . shell_quote($tmpname);
        print " Run piped: $cmd\n";
        my $ok = run( command => $cmd );
        if ($ok) {
            rename( $tmpname, $outfile);
        }
    }
    else {
        my $cmd = 'sox '
          . shell_quote($in)
          . ' -t .wav - tempo '
          . ($options->{tempo} // TEMPO)
          . ' trim '
          . join( ' ', @{$trims} )
          . ' | ffmpeg -y -i - '
          . ($options->{ffmpeg_cmd} // FFMPEG_CMD) . ' '
          . shell_quote($tmpname);

        print " Run: $cmd\n";
        my ( $ok, $err, $full_buf, $stdout_buf, $stderr_buf ) =
          run( command => $cmd );

        unless ($ok) {
            if ( grep ( /sox FAIL formats/, @{$stderr_buf} ) ) {
                $badformats{$sufix}++;

                # try again
                sox( $in, $outfile, $trims, $options );
            }
            else {
                print( join( "\n", @{$stderr_buf} ) );
            }
        }
        else {
            rename( $tmpname, $outfile);
        }
    }
}

1;
__END__

