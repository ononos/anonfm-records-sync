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
    "scan=s"    => \$SCAN,
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

foreach my $item (@ADD_SRC) {
    if ($col_source->update({src => $item}, {'$set' => {src => $item}}, {upsert => 1})) {
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
    foreach (@a) {
        printf("%-30s %-5s\n", $_->{src}, $_->{rm} ? 'yes' : 'no');
    }
}


