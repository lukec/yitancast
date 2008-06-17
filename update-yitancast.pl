#!/usr/bin/perl
use strict;
use warnings;
use Fatal qw/open close rename/;
use LWP::Simple qw/getstore get/;
use YAML qw/DumpFile/;
# use lib 'MP3-Podcast-0.06/lib';
use MP3::Podcast;

# Read email forwards of Yi-tan calls, and extract the 
# download link and some other info.  Then create a podcast.
my $DEBUG = 1;

my $YITAN_DIR = '/var/www/yitancast';
my $WEB_PATH  = 'http://open.socialtext.net';
my $BASE_DIR  = '/var/www';
usage("YITAN_DIR doesn't exist!") unless -d $YITAN_DIR;


printlog("Message received - " . localtime() . "\n");
my $msg = read_message();
my $recording = {
    url => audio_url($msg),
    date => audio_date($msg),
};
printlog("$recording->{date}{string}: $recording->{url}\n");

fetch_audio($recording);

create_podcast();

exit;

sub usage {
    my $msg = shift || '';
    die <<EOT;
$msg

USAGE: $0 /path/to/yitancast http://path/to/yitancast
  Where:
    /path/to/yitancast is the local directory containing MP3 files
        for the podcast, and this script will create a RSS file here.
    http://path/to/yitancast is the web address for the podcast
EOT
}


sub create_podcast {
    my $pod = MP3::Podcast->new($BASE_DIR, $WEB_PATH);
    my $rss = $pod->podcast('yitancast', "Yi-tan: Conversations About Change");
    my $rss_file = "$YITAN_DIR/yitancast.rss";
    my $tmp_file = "$rss_file.tmp";
    open my $fh, ">$tmp_file";
    print $fh $rss->as_string;
    close $fh;
    rename $tmp_file => $rss_file;
    printlog("Created $rss_file\n");
}

sub fetch_audio {
    my $r = shift;
    my $date = $r->{date};
    my $basename = "yitan-$date->{year}-$date->{month}-$date->{day}";
    my $file = $r->{mp3_file} = "$YITAN_DIR/$basename.mp3";
    if (! -e $file) {
        my $content = get($r->{url});
        unless ($content =~ m{href="(Recordings/ConferenceRecording-.+?\.mp3)">Recording Download Link}) {
            bad_message("Couldn't find recording download link!");
        }
        my $download_url = "http://www.freeconference.com/$1";

        my $code = getstore($download_url, $file);
        unless (-e $file) {
            bad_message("Couldn't fetch download link: $download_url!");
        }
        printlog("Fetching $download_url to $file: $code\n");
    }
    my $yaml = "$YITAN_DIR/$basename.yaml";
    DumpFile($yaml, $r);
}

sub audio_date {
    my $msg = shift;
    if ($msg =~ m{Conference Date and Time:(.+)$}m) {
        my $string = $1;
        $string =~ m/^((\w+) (\d+), (\d+)) (\d+:\d+ \w+) (.+)$/;
        return {
            string => $string,
            date => $1,
            month => $2, day => $3, year => $4,
            time => $5,
            timezone => $6,
        };
    }
    bad_message($msg, "Could not find date and time!");
}

sub audio_url {
    my $msg = shift;
    if ($msg =~ m{<(\Qhttp://www.freeconference.com/RecordingDownload.aspx?R=\E.+?)>}) {
        return $1;
    }
    bad_message($msg, "Could not find audio URL!");
}

sub bad_message {
    my $msg = shift;
    my $problem = shift;
    printlog("$problem\nMESSAGE: ($msg)\n");
}

sub read_message {
    local $/ = undef;
    my $msg = join "\n", <>;
    return $msg;
}
        

sub printlog {
    my $log_file = "/tmp/yitancast/log";
    open my $fh, ">>$log_file";
    print $fh @_;
    close $fh;
}

