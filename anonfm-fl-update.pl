#!/usr/bin/perl -w

=head1 NAME

pod-usage - Update file list from sources

=head1 SYNOPSIS

  anonfm-fl-update.pl [options]

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

=item B<--mongodb>

Set mongo db url like "mongodb://user:password:@host:port/dbname"

=item B<--add source>

Add source url, google drive id.

=item B<--rm source>

Remove source.

=item B<--list>

List sources.

=back

=cut

=head1 AUTHOR


 Ononos
 --
 http://github.com/ononos/

=cut

use warnings;
use strict;

use Getopt::Long;
use Pod::Usage;
use MongoDB;
use boolean;

use FindBin;
use lib "$FindBin::Bin/lib";

use Mojo::UserAgent;

use AnonFM::Util;

use Data::Dumper;

# prevent Wide character warning
binmode(STDOUT,':utf8');

my $HELP = 0;
my $MANUAL = 0;
my $SCAN = 0;

my $MONGO_URL;

my @ADD_SRC;
my @RM_SRC;
my $LIST = 0;

GetOptions(
    "help"      => \$HELP,
    "manual"    => \$MANUAL,
    "mongodb=s" => \$MONGO_URL,
    "add=s"     => \@ADD_SRC,
    "remove=s"  => \@RM_SRC,
    "list"      => \$LIST,
    "scan"    => \$SCAN,
);

$MONGO_URL //= $ENV{'MONGO_URL'};

pod2usage(1) if $HELP || !$MONGO_URL;
pod2usage(-exitval => 0, -verbose => 2) if $MANUAL;

my $db;

if ( $MONGO_URL =~ m|mongodb://(.*?):(.*?)@(.*?):(.*?)/(.*)| ) {
    my $client = MongoDB::MongoClient->new(
        password => $1,
        username => $2,
        host     => "$3:$4",
        db_name  => $5,
    );
    $db = $client->get_database($5);
} elsif ( $MONGO_URL =~ m|mongodb://(.*?):(.*?)/(.*)| ) {
  my $client = MongoDB::MongoClient->new(
      host    => "$1:$2",
      db_name => $3,
  );
  $db = $client->get_database($3);
}

die "Can't connect to mongodb: $MONGO_URL" unless defined $db;

my $col_source = $db->get_collection('sources');
my $col_files = $db->get_collection('files');

foreach my $item (@ADD_SRC) {
    if (
        $col_source->update(
            { src    => $item },
            { '$set' => { src => $item }, '$unset' => { rm => "" } },
            { upsert => 1 }
        )
      )
    {
        print "added source: $item\n";
    }

}

foreach my $item (@RM_SRC) {
    if ($col_source->update({src => $item}, {'$set' => {rm => true}})) {
        print "removed source: $item\n";
    }
}

if ($LIST) {
    my @a = $col_source->find()->all();
    my $indent = "     ";
    foreach (@a) {

        print "URL: " . $_->{src} ."\n";
        if ($_->{rm}) {
            print $indent. "removed\n";
        }
    }
}

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

    my $ua = Mojo::UserAgent->new( max_redirects => 5 );
    $ua->transactor->name('Mozilla/5.0');

    my %files;

    foreach my $src (@a) {
        my $source = $src->{src};
        my $sourceId = $src->{_id}->value;

        print "=> $source\n";

        # google drive
        if ( $source =~ m|^http[s]://docs.google.com/folderview| ) {

        }
        elsif ( $source =~ m/http:/ ) {
            my $tx = $ua->get($source);
            my $page;

            # get page
            if ( my $res = $tx->success ) {
                $page = $res->body;
                utf8::decode($page);
            }
            else {
                my $err = $tx->error;
                die "$err->{code} response: $err->{message}" if $err->{code};
                die "Connection error: $err->{message}";
            }

            my @result;

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
            else {
                print "!! Unknown source type, skip.\n";
            }

            my $now = time();
            foreach (@result) {
                my $filename = $_->{filename};
                my $size     = $_->{size};

                # if sourceId allredy exist in record, skip
                if ( exists $stored_files{$filename}
                    && $sourceId ~~ $stored_files{$filename}{'sources'} )
                {
                    # mark this source as seen and next
                    $confirm_sources{ $filename }{$sourceId} = 1;
                    next;
                }
                my $modifier = { '$addToSet' => { sources => $sourceId } };

                # if not event exist record, add to modifier $set name and size
                if ( !exists $stored_files{ $_->{filename} } ) {
                    $modifier->{'$set'} = { name => $filename,
                                            addedAt => $now,
                                            size => $size };
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
    }
    # check sources. and remove deadlinks

    foreach my $filename ( keys %stored_files ) {

        my @deadSource;
        foreach my $source ( @{ $stored_files{$filename}{'sources'} } ) {
            if ( exists $confirm_sources{$filename}{$source} ) {
                next;
            }
            push @deadSource, $source;
        }

        if (@deadSource) {
            $col_files->update(
                {
                    _id => $stored_files{$filename}{_id}
                },
                {
                    '$pullAll'  => { sources => \@deadSource },
                    '$addToSet' => { oldsource => { '$each' => \@deadSource } }
                }
            );
        }
    }
}
