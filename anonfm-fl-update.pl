#!/usr/bin/perl -w

=head1 NAME

anonfm-fl-update.pl - Update file list from sources

=head1 SYNOPSIS

  anonfm-fl-update.pl [options] [ --scan | --mkprev]

  Help Options:
   --help     Show this scripts help information.
   --manual   Read this scripts manual.

=cut

=head1 OPTIONS

=over 8

=item B<--help>

Show the brief help information.

=item B<--manual>

Read the manual.

=item B<--config>

Local config file, store cache, preview

=item B<--add source>

Add source url, google drive id.

=item B<--rm source>

Remove source.

=item B<--list>

List sources.

=item B<--scan>

Scan sources for files, update db.

=item B<--mkprev>

Download files from sources and make audio preview, update db.

=back

=cut

=head1 BASIC USAGE

Example of usage:

Add source,for example Nikita's Googledrive (https://docs.google.com/folder/d/0B6HMhe4i6iXGNWFpQXlIckNGeE0/edit)

    % ./anonfm-fl-update.pl -con ./anonfm-fl.yaml --add 0B6HMhe4i6iXGNWFpQXlIckNGeE0

Scan source for files

    % ./anonfm-fl-update.pl -con ./anonfm-fl.yaml --scan

Download and make preview.

    % ./anonfm-fl-update.pl -con ./anonfm-fl.yaml --mk

=head1 CONFIGURATION FILE


    mongodb: mongodb://localhost:27017/anonfm
        
    #
    # Preview generator
    #

    # Try get files here before downloading
    cache:
      - /home/anon/tmp/cache1/
      - /home/anon/tmp/cache2/
    
    # Location where to download files
    download_dir: /home/anon/tmp/download/
    
    preview_dir: /home/anon/tmp/preview/

    # optional, set ffmpeg setting
    ffmpeg_cmd: -acodec libfdk_aac -profile:a aac_he -ab 12k -ac 2 -ar 22050
    ffmpeg: /usr/local/bin/ffmpeg

=head1 MongoDB schema

When run this script with B<--scan> option all sources will be scanned,
and "files" collection will contain objects:

	"_id" : ObjectId("5522448aafad4263e2b90bab"),
	"addedAt" : NumberLong(1428309130),
	"dj" : "unkown",
	"name" : "1346188814.mp3",
	"size" : null,
	"sources" : [
		{
			"url" : "https://googledrive.com/host/0B6HMhe4i6iXGdDFqQjdKQnEwMFU",
			"id" : "55224342afad4263e2b90b96"
		}
	],
	"timestamp" : "1346188814"

After B<--mkprev>:

	"_id" : ObjectId("5522448aafad4263e2b90b97"),

	"bitrate" : "192",
	"duration" : NumberLong(663),
	"hasPreview" : true,

	"addedAt" : NumberLong(1428309130),
	"dj" : "unkown",
	"name" : "1346082313.mp3",
	"size" : NumberLong(15930848),
	"sources" : [
		{
			"url" : "https://googledrive.com/host/0B6HMhe4i6iXGRjhqenE3X1RNdFk",
			"id" : "55224342afad4263e2b90b96"
		}
	],
	"timestamp" : "1346082313"

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
use boolean;
use Config::Any::YAML;
use Path::Tiny;
use FindBin;
use lib "$FindBin::Bin/lib";
use Mojo::UserAgent;


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
my $MAKE_PREV = 0;

my $MONGO_URL;

my @ADD_SRC;
my @RM_SRC;
my $LIST = 0;
my $CONFIG_FILE;

GetOptions(
    "help"      => \$HELP,
    "manual"    => \$MANUAL,
    "mongodb=s" => \$MONGO_URL,
    "add=s"     => \@ADD_SRC,
    "remove=s"  => \@RM_SRC,
    "list"      => \$LIST,
    "scan"      => \$SCAN,
    "mkprev"    => \$MAKE_PREV,
    "config=s"  => \$CONFIG_FILE,
);
# ------------------------------------------------------

pod2usage(1) if $HELP || !$CONFIG_FILE;
pod2usage(-exitval => 0, -verbose => 2) if $MANUAL;

my $config = Config::Any::YAML->load ($CONFIG_FILE);

my $db;

foreach (qw/mongodb cache download_dir preview_dir/) {
    die "Config file have no \"$_\" key\n" unless exists $config->{$_};
}

if ( $config->{mongodb} =~ m|mongodb://(.*?):(.*?)@(.*?):(.*?)/(.*)| ) {
    my $client = MongoDB::MongoClient->new(
        password => $1,
        username => $2,
        host     => "$3:$4",
        db_name  => $5,
    );
    $db = $client->get_database($5);
} elsif ( $config->{mongodb} =~ m|mongodb://(.*?):(.*?)/(.*)| ) {
  my $client = MongoDB::MongoClient->new(
      host    => "$1:$2",
      db_name => $3,
  );
  $db = $client->get_database($3);
}

die "Can't connect to mongodb: $MONGO_URL" unless defined $db;

my $col_source = $db->get_collection('sources');
my $col_files = $db->get_collection('files');

# --add
foreach my $item (@ADD_SRC) {
    if (
        $col_source->update(
            { url    => $item },
            { '$set' => { url => $item }, '$unset' => { rm => "" } },
            { upsert => 1 }
        )->{n}
      )
    {
        print "added source: $item\n";
        $LIST = 1;
    }

}

# --remove
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
        printf "%-8s %s\n", $_->{rm} ? 'removed' : '', $_->{url},;
    }
}

# --scan
if ($SCAN) {
    print "Start scanning sources\n";

    my @a = $col_source->find( { rm => { '$ne' => boolean::true } } )->all();

    # fetch all files from mongodb, and  convert to hash, where key is
    # "name" field of record
    my %stored_files;

    foreach my $f ( $col_files->find( { rm => { '$ne' => boolean::true } } )
        ->fields( { name => 1, sources => 1 } )->all() )
    {
        $stored_files{ $f->{name} } = $f;
    }

    # Hash of filenames->sources that alive.
    # At end, we remove dead sources from db, and put to "oldsources" field of collection
    my %confirm_sources;

    my %files;

    foreach my $src (@a) {
        my $source = $src->{url};
        my $sourceId = $src->{_id}->value;

        print "=> $source\n";

        my @result;

        # google drive id?
        if ($source =~ m|\w{28}|) {
            @result = recursiveGoogle($source);
        }
        # google ddrive url?
        elsif ( $source =~ m|^http[s]://docs.google.com/folderview| ) {
            my $url = Mojo::URL->new ($source);
            my $id = $url->query->param ('id');

            @result = recursiveGoogle($id);
        }
        elsif ( $source =~ m/http:/ ) {
            my $page = fetch_page($source);

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

        my $now = time();
        foreach (@result) {
            my $filename = $_->{filename};
            my $size     = $_->{size};
            my $url      = $_->{url};

            my ( $dj, $timestamp ) = AnonFM::Util::parseFilename($filename);

            unless ( defined $timestamp ) {
                print "Ignored $filename\n";
                next;
            }

            # if sourceId allredy exist in record, skip
            if ( exists $stored_files{$filename}
                     && grep { $_->{id} eq $sourceId } @{$stored_files{$filename}{'sources'}} ) {
                # mark this source as seen and next
                $confirm_sources{ $filename }{$sourceId} = 1;
                next;
            }

            my $sourceObj = {id => $sourceId};
            if (defined $url) {
                $sourceObj->{url} = $url;
            }

            # modifier for mongo
            my $modifier = { '$addToSet' => { sources => $sourceObj } };


            # if not event exist record, add to modifier $set name and size
            if ( !exists $stored_files{ $_->{filename} } ) {
                $modifier->{'$set'} = {
                    name      => $filename,
                    addedAt   => $now,
                    dj        => $dj,
                    timestamp => $timestamp,
                    size      => $size
                };
                print "  New file: $filename\n";
            } else {
                print "  Update source for: $filename\n";
            }

            # update collection
            $col_files->update({name => $filename}, $modifier, {upsert => 1});

            # mark this source as seen
            $confirm_sources { $filename }{$sourceId} = 1;
        }

    }

    # check sources. and remove deadlinks
    foreach my $filename ( keys %stored_files ) {

        foreach my $source ( @{ $stored_files{$filename}{'sources'} } ) {
            my $sourceId = $source->{id};
            if ( exists $confirm_sources{$filename}{$sourceId} ) {
                next;
            }
            $col_files->update(
                {
                    _id => $stored_files{$filename}{_id},
                    'sources.id' => $sourceId
                },
                {'$set' => {'sources.$.rm' => true}});
        }
    }
} # / SCAN

if ($MAKE_PREV) {
    print "Start build preview\n";

    path( $config->{preview_dir} )->mkpath;
    path( $config->{download_dir} )->mkpath;

    my %sourcesById;
    foreach ( $col_source->find()->all() ) {
        $sourcesById{ $_->{_id}->value } = $_;
    }

    my @a = $col_files->find(
        {
            '$and' => [
                { hasPreview => { '$ne' => boolean::true } },
                { rm         => { '$ne' => boolean::true } }
            ]
        }
    )->fields( { name => 1, sources => 1 } )->all();

    foreach (@a) {

        my $filename = $_->{name};
        my $file_sources = $_->{sources};
        my $previewName = $_->{_id};
        my $fileId = $_->{_id};


        # check if file exist in cache
        my $fullname;

        foreach ( $config->{download_dir}, @{ $config->{cache} } ) {
            my $f = path( $_, $filename );
            if ( $f->is_file ) {
                $fullname = $f;
                print "Using cached file $f\n";
                last;
            }
        }

         # download if not exist
        unless ( defined $fullname ) {
            my $file_download = path( $config->{download_dir}, $filename );

            foreach ( @{$file_sources} ) {
                next if ($_->{rm} // 0);

                my $id  = $_->{id};
                # source may have url (google drive)
                my $url = $_->{url} // $sourcesById{$id}->{url} . $filename;

                print $url . "\n";

                if ( download( $url, $file_download ) ) {
                    $fullname = $file_download;
                    last;
                }
            }
        }

        if ( defined $fullname && $fullname->is_file ) {

            my $info = AnonFM::Util::Audio::file_info($fullname);

            AnonFM::Util::Audio::mk_preview(
                $fullname,
                path( $config->{preview_dir}, $previewName . '.flv' ),
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
                        hasPreview => true
                    }
                }
            );

        }


    }
} # / MAKE PREVIEW

##########################
# helpers
##########################

sub fetch_page {
    my $url = shift;
    state $ua = Mojo::UserAgent->new( max_redirects => 5 );
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
        $tx->res->content->asset->move_to($filename);
        print "Saved as $filename\n";
        return 1;
    }
    else {
        my ( $err, $code ) = $tx->error;
        print "Error download \"$url\"\n";
        print Dumper \$err;
        return 0;
    }
}


# recursive traverse google drive pages, get array [{filename => .., url => ..}, ..]
sub recursiveGoogle {
    my ($id, $tid) = @_;

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
    }

    die "Couldn't get google drive page id=$id tid=$tid" unless (defined $html);

    my $data = AnonFM::Util::parseGoogleDrivePage($html);

    foreach (@{$data->{folders}}) {
        print "==> Entering " . $_->{filename} . "\n";
        push @result, recursiveGoogle($_->{id}, $tid);
        print "==> Leaved " . $_->{filename} . "\n";
    }

    foreach (@{$data->{files}}) {
        push @result,
          {
            filename => $_->{filename},
            url      => "https://googledrive.com/host/" . $_->{id}
          };
    }

    print "    Files " . scalar(@{$data->{files}}) . "\n";

    return @result;
}
