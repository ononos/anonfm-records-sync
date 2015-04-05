package AnonFM::Util;

use utf8;
use strict;
use warnings;

use Carp;
use Time::Local;
use Mojo::Util qw(url_unescape);

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

=head2 parseSchedules (\%schedule, $source_text)


Fill hash %schedule with timestamp => {dj =>"..", desc => "..", duration => ".."} from $source_text

=cut

sub parseSchedules {
    my $res      = shift;
    my $shed_all = shift;

    # parse schedule content: example of content:
    # <span class="timestamp">[2012 Ср, 7 мaрта, 20:00...20:59]</span>  —  <span class="dj">Внучаев</span>: Школьники против суицидов<br>
    my @moy =
      qw(января февраля марта апреля мая июня июля августа сентября октября ноября декабря);
    my %MoY = map { $moy[$_] => $_ } ( 0 .. scalar(@moy) - 1 );

    while ( $shed_all =~
m!<span class="timestamp">\[(.*?)\]</span>  —  <span class="dj">(.*?)</span>: (.*?)<br>!g
      )
    {
        my ( $timestr, $dj, $desc ) = ( $1, $2, $3 );

        # parse timestamps
        if (
            my ( $year, $day, $month, $hr_start, $min_start, $hr_end, $min_end )
            = $timestr =~
            m/(\d{4}) \w+, (\d+) (\w+), (\d\d):(\d\d)...(\d\d):(\d\d)/ ) {

            $month =~ tr(abvgdzijklmnoprstufhc)
                        (абвгдзийклмнопрстуфхц);

            $month = $MoY{ lc($month) };
            my $timestamp;
            eval {
                $timestamp =
                  timelocal( 0, $min_start, $hr_start, $day, $month, $year );
            };
            die "parse date error: $timestr\n $@" if ($@);

            my $start = $hr_start * 60 + $min_start;    # hh:min
            my $end   = $hr_end * 60 + $min_end;
            my $len   = $end - $start;
            $len = ( 24 * 60 + $end ) - $start
              if ( $start > $end );                     # 01:00 - 23:00
            $len *= 60;                                 # in seconds
            $res->{$timestamp} = {
                dj           => $dj,
                desc         => $desc,
                duration     => $len
            };
        }
        else {
            die "Time stamp not parsed: $timestr - $dj - $desc\n";
        }
    }
}


=head2 parseAnonFMrecords($htmlsource)

Parse anon.fm record page (primary http://anon.fm/records/index.html).
Return array of {filename => '..', size => '..'}

=cut

sub parseAnonFMrecords {
    my $source = shift;

    my @files;

    if ($source =~ m|onclick=['"]showPlayer\(this\);return false['"]>|) {
        # looks like anon.fm/records.html
        while ($source =~ m|<td><a href=['"](.*?)['"] onclick=['"]showPlayer\(this\);return false['"]>.*?</a></td><td>(.*?)</td></tr>|g) {
            my ($url, $size) = ($1, $2);
            next unless ($url =~m |^(.*/)?(.*)|);
            my $filename = $2;

            $filename = url_unescape $filename;

            # parse size
            if ($size =~/(\d+)kb/i) {
                $size = $1 * 1024;
            } else {
                $size = 0;
            }
            push (@files, {filename => $filename, size => $size});
        }
    }
    return @files;
}

=head2 parseApacheIndex($htmlpage)

Parse apache index page and return filenames and size

Return array of {filename => '..', size => '..'}

=cut

sub parseApacheIndex {
    my $source = shift;
    my @files;

    if ($source =~m|<tr><td valign="top"><img.*?</td><td>&nbsp;</td></tr>|) {
        while ($source =~ m|<td><a href=".*?">([^/].*?)</a></td><td align="right">.*?</td><td align="right">(.*?)</td>|g) {
            my ($filename, $size) = ($1, $2);

             # parse size
            if ( $size =~ /(\d+)K/ ) {
                $size = $1 * 1024;
            }
            elsif ( $size =~ /(\d+)M/ ) {
                $size = $1 * 1024 * 1024;
            }
            elsif ( $size =~ /(\d+)G/ ) {
                $size = $1 * 1024 * 1024 * 1024;
            }
            else {
                $size = int($size);
            }
            push( @files, { filename => $filename, size => $size } );
       }
    }
    return @files;
}

=head2 parseGoogleDrivePage($htmlpage)

Parse google drive html page.

Return

     {
       files => [{filename => '..', id => '..google id..'}, ..],
       folders => [{filename => '..', id => '..google id..'}, ..]
     }

=cut

sub parseGoogleDrivePage {
    my $html = shift;
    my (@files, @folders);

    while ($html =~m |<div class="flip-entry" id="entry-(.*?)" tabindex="0" role="link">.*?<div class="flip-entry-list-icon">(.*?)<div class="flip-entry-title">(.*?)</div>|g) {
        my ($newID, $typeStr, $filename) = ($1, $2, $3);
        # does it folder
        if (index ($typeStr, 'drive-sprite-folder-list-shared-icon') >=0) {
            push @folders, {filename => $filename, id => $newID};
        } else {
            push @files, {filename => $filename, id => $newID};
        }
    }
    return {files => \@files, folders => \@folders};
}

1;
