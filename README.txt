NAME
    anonfm-fl-update.pl - Anonfm archive updater

SYNOPSIS
      anonfm-fl-update.pl [options] [ --scan | --mkprev]

      Help Options:
       --help     Show this scripts help information.
       --manual   Read this scripts manual.

DESCRIPTION
    Record fetcher, information aggregator, record preview generator.

    Multiple sources used as records archive. Supported anonfm record page,
    nginx/apache index pages, google drive as sources.

    Live page http://anonfm.ononos.tk

OPTIONS
    --help  Show the brief help information.

    --manual
            Read the manual.

    --config
            Local config file.

  Source list options
    --add source,duration,title
            Add source url or google drive id, duration for next update,
            title is short source describe title

    --rm source
            Remove source.

    --list  List sources.

  Crawler options
    --scan  Scan sources for files, update db. You can use --force flag for
            forcing update even no source duration time excited.

    --schedule
            Download schedule page, update db.

    --mkprev
            Download files from sources and make audio preview, update db.
            You may want download first files using --download.

            Skip records where timestamp is < time() - 8hr

  Utility options
    --download source
            Download files from source. See also YAML config file for cache
            directories and download_dir.

            Skip records where timestamp is < time() - 8hr

    --files source
            Show files of source and if have local copy show locations.

            Example of output for file "anonfm-12345-virt.mp3" and size
            3_023_423:

              | | anonfm-12345-virt.mp3 | 3023423 /var/lib/cache1/anonfm-12345-virt.mp3 | 3023423 /var/lib/cache2/anonfm-12345-virt.mp3

            or if have remove mark:

              | REMOVED | anonfm-12345-virt.mp3 | 3023423 /var/lib/cache1/anonfm-12345-virt.mp3 | 3023423 /var/lib/cache2/anonfm-12345-virt.mp3

            Also if size for places is different, DIFFSIZE label appear.

BASIC USAGE
    Example of usage:

    Add source,for example Nikita's Googledrive
    (https://docs.google.com/folder/d/0B6HMhe4i6iXGNWFpQXlIckNGeE0/edit)

        % ./anonfm-fl-update.pl -con ./anonfm-fl.yaml --add 0B6HMhe4i6iXGNWFpQXlIckNGeE0

    Scan source for files

        % ./anonfm-fl-update.pl -con ./anonfm-fl.yaml --scan

    Update schedule from anon.fm, see config file for more.

        % ./anonfm-fl-update.pl -con ./anonfm-fl.yaml --sch

    Download and make preview.

        % ./anonfm-fl-update.pl -con ./anonfm-fl.yaml --mk

CONFIGURATION FILE
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

MongoDB schema
    When run this script with --scan option all sources will be scanned, and
    "files" collection will contain objects:

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

    After --mkprev:

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

    Field *schOk* for record indicate that it scheduled, i. e. it started
    before 20minutes of nearest schedule start and not later 20 minutes
    after end that schedule.

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

    Additional fields: rm - boolean - removed or not

AUTHOR
     Ononos
     --
     http://github.com/ononos/

