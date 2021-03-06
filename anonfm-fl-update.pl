#!/usr/bin/perl -w

=head1 NAME

anonfm-fl-update.pl - Anonfm archive updater

=head1 SYNOPSIS

  anonfm-fl-update.pl [options] [ --scan | --mkprev]

  Help Options:
   --help     Show this scripts help information.
   --manual   Read this scripts manual.

=cut

=head1 DESCRIPTION

Record fetcher, information aggregator, record preview generator.

Multiple sources used as records archive. Supported anonfm record page,
nginx/apache index pages, google drive as sources.

=over 4

=item

Live page http://anonfm.ononos.tk

=item

Source of website: https://github.com/ononos/meteor-anonfm-records

=back

=head1 OPTIONS

=over 8

=item B<--help>

Show the brief help information.

=item B<--manual>

Read the manual.

=item B<--config>

Local config file.

=back

=head2 Source list options

=over 8

=item B<--add source,duration,title>

Add source url or google drive id,  B<duration> for next update, B<title> is short source describe title

=item B<--rm source>

Remove source.

=item B<--list>

List sources.

=back

=head2 Crawler options

=over 8

=item B<--scan>

Scan sources for files, update db.
You can use B<--force> flag for forcing update even no source duration time excited.

=item B<--schedule>

Download schedule page, update db.

=item B<--mkprev>

Download files from sources and make audio preview, update db.
You may want download first files using B<--download>.

Skip records where timestamp is < time() - 8hr

=back

=head2 Utility options

=over 8

=item B<--download source>

Download files from source.
See also YAML config file for B<cache> directories and B<download_dir>.

Skip records where timestamp is < time() - 8hr

=item B<--files source>

Show files of source and if have local copy show locations.

Example of output for file "anonfm-12345-virt.mp3" and size 3_023_423:

  | | anonfm-12345-virt.mp3 | 3023423 /var/lib/cache1/anonfm-12345-virt.mp3 | 3023423 /var/lib/cache2/anonfm-12345-virt.mp3

or if have remove mark:

  | REMOVED | anonfm-12345-virt.mp3 | 3023423 /var/lib/cache1/anonfm-12345-virt.mp3 | 3023423 /var/lib/cache2/anonfm-12345-virt.mp3

Also if size for places is different, DIFFSIZE label appear.

=back

=cut

=head1 BASIC USAGE

Example of usage:

Add source,for example Nikita's Googledrive (https://docs.google.com/folder/d/0B6HMhe4i6iXGNWFpQXlIckNGeE0/edit)

    % ./anonfm-fl-update.pl -con ./anonfm-fl.yaml --add 0B6HMhe4i6iXGNWFpQXlIckNGeE0

Scan source for files

    % ./anonfm-fl-update.pl -con ./anonfm-fl.yaml --scan

Update schedule from anon.fm, see config file for more.

    % ./anonfm-fl-update.pl -con ./anonfm-fl.yaml --sch

Download and make preview.

    % ./anonfm-fl-update.pl -con ./anonfm-fl.yaml --mk

=head1 CONFIGURATION FILE


    mongodb: mongodb://localhost:27017/anonfm
    
    schedule: http://anon.fm/shed-all.html
        
    schedule: http://anon.fm/shed-all.html
    
    #
    # Preview generator
    #
    
    cache:
      - /home/anon/tmp/cache1/
      - /home/anon/tmp/cache2/
    
    # Location where to download files
    download_dir: /home/anon/tmp/download/
    
    preview_dir: /home/anon/tmp/preview/
    
    preview_ext: .ogg
    
    ffmpeg_cmd: -acodec libvorbis -ab 16k -ac 1 -ar 22050 -af 'volume=1.2'
    ffmpeg: /usr/local/bin/ffmpeg
    
    pid: /tmp/anonfm-fl-update.pid

=head1 MongoDB schema

When run this script with B<--scan> option all sources will be scanned,
and "files" collection will contain objects:

	"_id" : ObjectId("5522448aafad4263e2b90bab"),
	"addedAt" : ISODate("2015-01-04T19:10:00Z"),
	"dj" : "unkown",
	"fname" : "1346188814.mp3",
	"size" : null,
	"sources" : [
		{
                        # url is optional, otherwisem you should concat source's url and this.fname
			"url" : "https://googledrive.com/host/0B6HMhe4i6iXGdDFqQjdKQnEwMFU",
			"id" : "55224342afad4263e2b90b96"
		}
	],
	"t" :  ISODate("2015-01-04T19:10:00Z")

After B<--mkprev>:

	"_id" : ObjectId("5522448aafad4263e2b90b97"),

	"bitrate" : "192",
	"duration" : NumberLong(663),
	"preview" : "1346082313.mp3.aac",

	"addedAt" : NumberLong(1428309130),
	"dj" : "unkown",
	"fname" : "1346082313.mp3",
	"size" : NumberLong(15930848),
	"sources" : [
		{
			"url" : "https://googledrive.com/host/0B6HMhe4i6iXGRjhqenE3X1RNdFk",
			"id" : "55224342afad4263e2b90b96"
		}
	],
	"t" : ISODate("2015-01-04T19:10:00Z"),

	"schOk" : true,

Field I<schOk> for record indicate that it scheduled,
i. e. it started before 20minutes of nearest schedule start
and not later 20 minutes after end that schedule.


Example of schedules's record:

	"_id" : ObjectId("5527883026b31612ff0b08b6"),
	"dj" : "Никита Ветров",
	"isSch" : true,
	"duration" : NumberLong(3420),
	"addedAt" : ISODate("2015-04-10T08:22:08Z"),
	"schedule" : "Никита читает новости об МММ",
                                               # forward timestamp - 15 minutes (t - used for sorting,
                                               # need schedule move before record start, som djs start recording faster)
	"t" : ISODate("2012-05-05T14:03:00Z")
	"schTime" : ISODate("2012-05-05T13:48:00Z"), # REAL TIME STAMP



Additional fields: B<rm> - boolean - removed or not

=head1 AUTHOR


 Ononos
 --
 http://github.com/ononos/

=cut

use warnings;
use strict;
use feature "state";

use Getopt::Long;
use Pod::Usage;
use MongoDB;
use DateTime;
use boolean;
use Config::Any::YAML;
use Path::Tiny;
use FindBin;
use lib "$FindBin::Bin/lib";
use Mojo::UserAgent;
use Mojo::Util qw(html_unescape);
use PID::File;

use AnonFM::Util;
use AnonFM::Util::Audio;

use Data::Dumper;

# prevent Wide character warning
binmode(STDOUT,':utf8');

# Increase limit to 0.72GB
$ENV{MOJO_MAX_MESSAGE_SIZE} = 746586112;

# ------------------------------------------------------
# commandline options
my $HELP = 0;
my $MANUAL = 0;

my $SCAN = 0;
my $SCHEDULE = 0;
my $MAKE_PREV = 0;
my $SHOW_SOURCE_FILES;
my $DOWNLOAD;


my $FORCE = 0;

my @ADD_SRC;
my @RM_SRC;
my $LIST = 0;
my $CONFIG_FILE;

GetOptions(
    "help"      => \$HELP,
    "manual"    => \$MANUAL,
    "add=s"     => \@ADD_SRC,
    "remove=s"  => \@RM_SRC,
    "list"      => \$LIST,
    "scan"      => \$SCAN,
    "force"     => \$FORCE,
    "schedule"  => \$SCHEDULE,
    "mkprev"    => \$MAKE_PREV,
    "files=s"   => \$SHOW_SOURCE_FILES,
    "download=s"=> \$DOWNLOAD,
    "config=s"  => \$CONFIG_FILE,
);
# ------------------------------------------------------

pod2usage(-verbose => 2) && exit if $MANUAL;
pod2usage(1) && exit if $HELP || !$CONFIG_FILE;

my $config = Config::Any::YAML->load ($CONFIG_FILE);

# exit if still running
my $pid;
{
    my $pid_file = path($config->{pid} // '/tmp/anonfm-fl-update.pid');

    $pid = PID::File->new(file => $pid_file);
    if ($pid->running) {
        print "anonfm-fl-update still running\n";
        exit 1;
    }
    unlink $pid_file;

    die "can't create pid file"
        if ! $pid->create;
    $pid->guard;
}

foreach (qw/mongodb cache download_dir preview_dir schedule/) {
    die "Config file have no \"$_\" key\n" unless exists $config->{$_};
}

my $client = MongoDB::MongoClient->new(
    host => $config->{mongodb}
);
$client->dt_type('DateTime');

my $db = $client->get_database( $client->{_opts}->{db_name} );

die "Can't connect to mongodb, check config file" unless defined $db;

my $col_source = $db->get_collection('sources');
my $col_files = $db->get_collection('files');

# --add source
foreach my $source (@ADD_SRC) {
    die "Format of source is \"URL,DURATION,TITLE\". Fail to add $source"
      unless ( $source =~ m/(.*?),(.*?),(.*)/ );

    my ( $url, $updateDuration, $title ) = ( $1, $2, $3 );

    if (
        $col_source->update(
            {
                url => $url
            },
            {
                '$set' =>
                  { url => $url, update => $updateDuration, title => $title },
                '$unset' => { rm => "" }
            },
            {
                upsert => 1
            }
        )->{n}
      )
    {
        print "added/updated source: $url\n";
        $LIST = 1;
    }
}

# --remove source
foreach my $item (@RM_SRC) {
    if ($col_source->update({url => $item}, {'$set' => {rm => true}})->{n}) {
        print "removed source: $item\n";
        $LIST = 1;
    } else {
        print "Source not found $item\n";
    }
}

# --list
if ($LIST) {
    my @a = $col_source->find()->all();
    my $indent = "     ";
    foreach (@a) {
        printf "%-8s %-10s %-12s %s\n", $_->{rm} ? 'removed' : '',
          $_->{update}, $_->{title}, $_->{url},;
    }
}

# --scan
if ($SCAN) {
    print "Start scanning sources\n";

    my @a = $col_source->find( { rm => { '$ne' => boolean::true } } )->all();

    # fetch all files from mongodb, and  convert to hash, where key is
    # "fname" field of record
    my %stored_files;

    # sources that was skipped;
    my @skipped_sources;
    

    foreach
      my $f ( $col_files->find( { isSch => { '$ne' => boolean::true } } )
        ->fields( { fname => 1, sources => 1 } )->all() )
    {
        $stored_files{ $f->{fname} } = $f;
    }

    # Hash of filenames->sources that alive.
    # At end, we remove dead sources from db, and put to "oldsources" field of collection
    my %confirm_sources;

    # Helper, make text id from  source object. we support only Google
    # drive  subfolder   support,  need   create  uniq  id   for  EACH
    # subfolder. Used as key of $confirm_sources.
    #
    # $confirm_sources after scanning, will be traversed, and record's
    # source that  not presented here  will be marked as  removed (rm: true)
    sub source_to_confirmId {
        my $recordSource = shift;
        my $id = $recordSource->{id}->value;
        return ( exists $recordSource->{folder} )
          ? $id . $recordSource->{folder}
          : $id;
    }

    my %files;

    foreach my $src (@a) {
        my $source = $src->{url};
        my $sourceId = $src->{_id};

        sub update_source_msg {    # helper
            my $msg = shift;
            $col_source->update(
                {
                    _id => $sourceId
                },
                {
                    '$set' => { msg => $msg }
                }
            );
        }

        # decide, does we need continue or skip
        my $lastUpdated = $src->{lastUpdated};
        if ( !$FORCE && defined $lastUpdated ) {
            my $update = $src->{update};
            unless ( time() > $update + $lastUpdated->epoch() ) {
                push @skipped_sources, $sourceId->value;
                print "Skip source $source\n";
                next;
            }
        }
        $col_source->update( { _id => $src->{_id} },
            { '$set' => { lastUpdated => DateTime->now() } } );

        print "=> $source\n";

        my @result;

        # google drive id?
        if ($source =~ m|\w{28}|) {
            eval { @result = recursiveGoogle('.', $source); };
            if ($@) {
                print Dumper $src;
                update_source_msg $@;
                push @skipped_sources, $sourceId->value;
                next;
            }
        }
        elsif ( $source =~ m/http:/ ) {
            my $page = fetch_page($source);

            unless (defined $page) {
                update_source_msg 'Failure download page';
                push @skipped_sources, $sourceId->value;
                next;
            }

            # apache index?
            if ( $page =~
                m|<tr><td valign="top"><img.*?</td><td>&nbsp;</td></tr>| )
            {
                @result = AnonFM::Util::parseApacheIndex($page);
            }

            # anonfm?
            elsif (
                $page =~ m|onclick=['"]showPlayer\(this\);return false['"]>| )
            {
                @result = AnonFM::Util::parseAnonFMrecords($page);
            }

            # nginx?
            elsif ( $page =~ m|<body bgcolor="white">| ) {
                @result = AnonFM::Util::parseNginxIndex($page);
            }
        }
        else {
            print "!! Unknown source type, skip.\n";
        } # /if

        update_source_msg 'ok';

        my $now = DateTime->now();

        foreach (@result) {
            my $filename = $_->{filename};
            my $size     = $_->{size};
            my $url      = $_->{url};
            my $folder   = $_->{folder};

            my ( $dj, $timestamp ) = AnonFM::Util::parseFilename($filename);

            unless ( defined $timestamp ) {
                print "Ignored $filename\n";
                next;
            }

            my $sourceObj = {id => $sourceId};
            if (defined $url) {
                $sourceObj->{url} = $url;
            }
            if (defined $folder) {
                $sourceObj->{folder} = $folder;
            }

            # if source allredy exist in record, mark as seen and skip
            if (
                exists $stored_files{$filename}
                && grep {
                    source_to_confirmId($_) eq source_to_confirmId($sourceObj)
                } @{ $stored_files{$filename}{'sources'} }
              )
            {
                # mark this source as seen and next
                $confirm_sources{$filename}{ source_to_confirmId($sourceObj) }
                  = 1;

                next;
            }

            # if not event exist record, insert new one
            if ( !exists $stored_files{ $filename } ) {
                my $doc = {
                    fname    => $filename,
                    addedAt => $now,
                    dj      => $dj,
                    t       => DateTime->from_epoch( epoch => $timestamp ),
                    size    => $size,
                    sources => [$sourceObj]
                };

                print "  New file: $filename\n";
                $col_files->insert($doc);

                # ensure we have will have no duplication in future for this filename
                $stored_files{ $filename } = $doc;

            } else {
                print "  Update source for: $filename\n";
                # update collection
                $col_files->update({fname => $filename}, { '$addToSet' => { sources => $sourceObj } });
            }

            # mark this source as seen
            $confirm_sources{$filename}{ source_to_confirmId($sourceObj) } = 1;
        }

    }

    # check sources. and remove deadlinks by adding "rm" field to source
    foreach my $filename ( keys %stored_files ) {

        foreach my $source ( @{ $stored_files{$filename}{'sources'} } ) {
            my $sourceId = $source->{id};

            next if ( $sourceId->value ~~ @skipped_sources );

            if (exists $confirm_sources{$filename}{ source_to_confirmId($source) } )
            {
                if ( $source->{rm} // 0 ) {

                    # looks this file now present in source, remove "rm" field
                    $col_files->update(
                        {
                            _id          => $stored_files{$filename}{_id},
                            'sources.id' => $sourceId
                        },
                        {
                            '$unset' => { 'sources.$.rm' => "" }
                        }
                    );
                }
                next;
            }

            next if ( $source->{rm} // 0 );

            $col_files->update(
                {
                    _id          => $stored_files{$filename}{_id},
                    'sources.id' => $sourceId
                },
                { '$set' => { 'sources.$.rm' => true } }
            );
        }
    }
} # / SCAN

if ($SCHEDULE) {
    print "Download schedule\n";

    my $page = fetch_page( $config->{schedule} );
    die unless defined $page;

    my %stored_schedules;       #  scheduled by timestamps

    # "schTime" field is real time stamp of scheduled, "t" - is (schTime-20minuts)
    foreach my $s (
        $col_files->find( { isSch => boolean::true } )->fields( { schTime => 1, schedule => 1 } )
        ->all() )
    {
        my $time = $s->{schTime}->epoch();
        $stored_schedules{$time} = $s;
    }

    my %schedules;
    AnonFM::Util::parseSchedules( \%schedules, $page );

    my $now = DateTime->now();
    my %seen_schedules;

    while ( my ( $time, $data ) = each %schedules ) {
        # need unescape schedules anon.fm
        $data->{desc} = html_unescape $data->{desc};

        $seen_schedules{$time} = 1;

        next
          if ( exists $stored_schedules{$time}
            && $stored_schedules{$time}->{schedule} eq $data->{desc} );

        my $doc = {
            isSch    => boolean::true,
            schTime  => DateTime->from_epoch( epoch => $time ),
            t        => DateTime->from_epoch( epoch => $time - 20 * 60 ),
            addedAt  => $now,
            dj       => $data->{dj},
            schedule => $data->{desc},
            duration => $data->{duration}
        };

        # add new schedule
        $col_files->insert($doc);

        $stored_schedules{$time} = $doc;

    }

    # check for removed schedule
    foreach my $s ( $col_files->find( { isSch => boolean::true } )
        ->fields( { schTime => 1, rm => 1 } )->all() )
    {
        my $time = $s->{schTime}->epoch();
        my $need_rm = !exists $seen_schedules{$time};

        if ( ( $s->{rm} // false ) != $need_rm ) {
            $col_files->update( { _id => $s->{_id} },
                { '$set' => { rm => boolean($need_rm) } } );
        }
    }

    # now Traverse all records and mark scheduled
    %stored_schedules = ();
    print "Precalculate covered by scheduled records\n";

    sub updateSchRec {
        my ($record, $scheduled) = @_;
        # update only if need
        if (($record->{schOk} // false) != $scheduled) {
            $col_files->update( { _id => $record->{_id} },
                                {
                                    '$set' => { schOk => $scheduled } } );
        };
    }

    foreach my $s (
        $col_files->find( { isSch => boolean::true } )->fields( { t => 1, duration => 1, rm => 1 } )
        ->all() )
    {
        my $time = $s->{t}->epoch();
        $stored_schedules{$time} = $s;
    }
    my @schTimes = sort keys %stored_schedules;
    
    foreach my $record (
        $col_files->find( { isSch => { '$ne' => boolean::true } } )
        ->fields( { t => 1, schOk => 1, fname => 1 } )->all() )
    {
        my $recTime = $record->{t}->epoch();

        # http://stackoverflow.com/questions/17185169/perl-find-closest-date-in-array
        my $schNearestDate = ( grep $_ <= $recTime, @schTimes )[-1];

        # there may be no schedule
        unless (defined $schNearestDate) {
            updateSchRec( $record, false );
            next;
        }

        my $sch = $stored_schedules{$schNearestDate};

        # We found scheduled that was before this record (and btw, t is -20 minutes),
        # now check is record started before this schedule ended (and +20 minutes, so +20)
        if ( $schNearestDate + ( 40 * 60 + $sch->{duration} ) > $recTime
            && !$sch->{rm} )
        {
            updateSchRec( $record, true );
        }
        else {
            updateSchRec( $record, false );
        }
    }


} # / SCHEDULE

if ($MAKE_PREV) {
    print "Start build preview\n";

    path( $config->{preview_dir} )->mkpath;
    path( $config->{download_dir} )->mkpath;

    my %sourcesById;
    foreach ( $col_source->find()->all() ) {
        $sourcesById{ $_->{_id}->value } = $_;
    }

    # Helper
    # $path_to_file =
    #   download_in_cache( 'anonfm--20121004-183959-Лемур катта.mp3',
    #                      \[ { id => .. }, { id => .., url => } ] )

    sub download_in_cache {
        my ( $filename, $record_sources ) = @_;
        my $file_download = path( $config->{download_dir}, $filename );

        foreach ( @{$record_sources} ) {
            next if ( $_->{rm} // 0 );

            my $id = $_->{id};

            # source may have url (google drive)
            my $url = $_->{url} // $sourcesById{$id}->{url} . $filename;

            print $url . "\n";

            if ( download( $url, $file_download ) ) {
                return $file_download;
            }
        }
	return undef;
    }

    my @a = $col_files->find(
        {
            t => {
                # only < 8 hr from now
                '$lt' => DateTime->from_epoch( epoch => time() - 8 * 60 * 60 )
            },
            isSch      => { '$ne' => boolean::true },
            rm         => { '$ne' => boolean::true }
        }
    )->fields( { fname => 1, sources => 1, duration => 1, preview => 1 } )->all();

    foreach (@a) {

        my $filename = $_->{fname};
        my $file_sources = $_->{sources};
        my $previewname = $_->{fname} . $config->{preview_ext} // '.aac';
        my $previewFullpath = path( $config->{preview_dir}, $previewname );
        my $fileId = $_->{_id};

        next if (exists $_->{duration} && $_->{duration} == 0);

        if ( $previewFullpath->exists() ) {
            unless ( exists $_->{preview} ) {
                $col_files->update( { _id => $fileId },
                                    { '$set' => { preview => $previewname } } );
            }

            # make sure file info (duration, bitrate) exists, update if not
            unless (exists $_->{duration}) {
                print "Preview exists, I just extract duration for $filename\n";
                my $fullname = file_from_cache($filename);

                # if file not exist in cache, download
                unless (defined $fullname) {
                    $fullname = download_in_cache($filename, $file_sources);
                }

                next unless defined $fullname;

                my $info = AnonFM::Util::Audio::file_info($fullname);
                $col_files->update(
                    {
                        _id => $fileId },
                    {
                        '$set' => {
                            size     => $info->{size}     // 0,
                            bitrate  => $info->{bitrate}  // 0,
                            duration => $info->{duration} // 0,
                        }
                    }
                );
            }
            next;
        }

        # check if file exist in cache
        my $fullname = file_from_cache($filename);

        # download if not exist
        unless ( defined $fullname ) {
            $fullname = download_in_cache($filename, $file_sources);
        } else {
            print "Using cached file $fullname\n";
        }

        if ( defined $fullname && $fullname->is_file ) {

            my $info = AnonFM::Util::Audio::file_info($fullname);

            AnonFM::Util::Audio::mk_preview(
                $fullname,
                $previewFullpath,
                {
                    ffmpeg     => $config->{ffmpeg},
                    ffmpeg_cmd => $config->{ffmpeg_cmd}
                }
            );

            $col_files->update(
                { _id => $fileId },
                {
                    '$set' => {
                        size     => $info->{size}     // 0,
                        bitrate  => $info->{bitrate}  // 0,
                        duration => $info->{duration} // 0,
                        preview => $previewname,
                    }
                }
            );
        }
    }
} # / MAKE PREVIEW

if ($DOWNLOAD) {
    my $source = $col_source->find_one( { url => $DOWNLOAD } );

    die qq|Source "$DOWNLOAD" not found, try --list\n|
      unless defined $source;

    print "Download missing files from source $DOWNLOAD\n";

    for my $filerecord (
        $col_files->find(
            {
                t => {
                    '$lt' =>
                      DateTime->from_epoch( epoch => time() - 8 * 60 * 60 )
                },
                rm           => { '$ne' => boolean::true },
                'sources.id' => $source->{_id}
            }
        )->fields( { fname => 1, sources => 1 } )->all()
      )
    {
        my $filename = $filerecord->{fname};
        my $url;

        foreach ( @{ $filerecord->{sources} } ) {
            if ( $_->{id}->value eq $source->{_id}->value ) {
                $url = $_->{url};
                last;
            }
        }
        $url //= $source->{url} . $filename;

        next if ( defined file_from_cache($filename) );

        my $file_download = path( $config->{download_dir}, $filename );

        print "==> $filename\n";
        download( $url, $file_download );
    }
}    # /DOWNLOAD

if ($SHOW_SOURCE_FILES) {
    my $source = $col_source->find_one(
        {
            url => $SHOW_SOURCE_FILES,
        }
    );

    die qq|Source "$SHOW_SOURCE_FILES" not found, try --list\n|
      unless defined $source;

    for my $filerecord (
        $col_files->find(
            {
                'sources.id' => $source->{_id}
            }
        )->fields( { fname => 1, rm => 1 } )->all()
      )
    {
        my $filename = $filerecord->{fname};
        my $removed  = $filerecord->{rm};
        my @downloaded;
        my ($size, $isSizeDiff);

        foreach ( $config->{download_dir}, @{ $config->{cache} } ) {
            my $f = path( $_, $filename );
            if ( $f->is_file ) {
                my $fsize = -s $f;
                $size //= $fsize;
                $isSizeDiff = 1 if $size != $fsize;

                push @downloaded, { f => $f, s => $fsize };
            }
        }

        my @flags;
        push @flags, 'REMOVED' if $removed;
        push @flags, 'DIFFSIZE' if $isSizeDiff;

        print '| ' . join(' ', @flags) . ' | ' . $filename . ' | ' . join(' | ', map {$_->{s} . ' ' . $_->{f} } @downloaded) . "\n";
    }
}


##########################
# helpers
##########################

# get file from cache or download_dir
sub file_from_cache {
    my $filename = shift;

    foreach ( $config->{download_dir}, @{ $config->{cache} } ) {
        my $f = path( $_, $filename );
        if ( $f->is_file ) {
            return $f;
        }
    }
    return;
}

sub fetch_page {
    my $url = shift;
    my $ua = Mojo::UserAgent->new( max_redirects => 5 );
    $ua->transactor->name('Mozilla/5.0');

    my $tx = $ua->get($url);
    my $page;

    # get page
    if ( my $res = $tx->success ) {
        $page = $res->body;
        utf8::decode($page);
    }
    else {
        my ( $err, $code ) = $tx->error;
        print "Error fetching \"$url\"\n";
        print Dumper \$err;
    }
    return $page;
}


# download url and save
sub download {
    my ( $url, $filename ) = @_;

    state $ua = Mojo::UserAgent->new( max_redirects => 5 );
    $ua->transactor->name('Mozilla/5.0');

    if ( index( $url, 'google.com' ) >= 0 ) {

        # check id
        if ( $url =~ m|docs.google.com/file/d/(\w+)| ) {
            $url = 'https://googledrive.com/host/' . $1;
        }
    }

    print "Downloading: $url\n";
    my $tx = $ua->get($url);
    if ( $tx->success ) {
        if ($tx->res->headers->content_type() =~ m/html/) {
            print "!! Failure download, looks file is not audio, but HTML ($url)\n";
            return 0;
        }
        $tx->res->content->asset->move_to($filename);
        print "Saved as $filename\n";
        return 1;
    }
    else {
        my ( $err, $code ) = $tx->error;
        print "!! Error download \"$url\"\n";
        print Dumper \$err;
        return 0;
    }
}


# recursive traverse google drive pages, get array [{filename => .., url => ..}, ..]
sub recursiveGoogle {
    my ($dirname, $id, $tid) = @_;

    my $html;

    my $url;
    my @result;

    if (defined $tid) {
        $url = "https://docs.google.com/folderview?id=$id&tid=$tid";
    } else {
        $url = "https://docs.google.com/folderview?id=$id";
        $tid = $id;
    }

    for my $retry (1..5) {
        $html = fetch_page $url;
        last if defined $html;
        sleep 1;
        print "    Retry...\n";
    }

    die "Couldn't get google drive page id=$id tid=$tid" unless (defined $html);

    my $data = AnonFM::Util::parseGoogleDrivePage($html);

    foreach ( @{ $data->{folders} } ) {
        my $folder = '' . path($dirname, $_->{filename});
        print "==> Entering $folder\n";
        push @result, recursiveGoogle( $folder, $_->{id}, $tid );
        print "==> Leaved $folder\n";
    }

    foreach ( @{ $data->{files} } ) {
        push @result,
          {
            folder   => $dirname,
            filename => $_->{filename},
            url => "https://googledrive.com/host/" . $id . '/' . $_->{filename}
          };
    }

    print "    Files " . scalar(@{$data->{files}}) . "\n";

    return @result;
}
