#!perl

use strict;
use warnings;

use Data::Dump qw(dump);
use Getopt::Long;

use Diffbot::Client;

#input arguments
my $token;    #required
my ($content, $content_string, $content_file); #content is required
my $target_url = 'http://www.diffbot.com';
my $request_type = 'all';
my $help;

GetOptions(
    'token=s'        => \$token,
    'url:s'          => \$target_url,
    'request_type:s' => \$request_type,
    'content:s'      => \$content_string, 
    'content_file:s' => \$content_file, 
    'help'           => \$help 
) or die "Error getting command line options: $!";
usage() if $help;

#validate input
usage("The URL must begin with http://") unless $target_url =~ qr{^http://}; 

usage("content AND content_file cannot both be provided") if
    $content_string && $content_file;

usage("content_file does not exist") if
    $content_file && ! -r $content_file;

if ($content_file) {
    open my $fh, '<', $content_file or die $!;
    while (<$fh>) { $content .= $_; }
    close $fh or die $!;
}
else {
    $content = $content_string;
}

my $client = Diffbot::Client->new({ token => $token });

for my $api (qw(article frontpage product image analyze classifier)) {
    if ($request_type =~ /(all|$api)/) {
        my $diffbot_response;
        eval {

            my $query_args = {
                url     => $target_url
            };
            $query_args->{content} = $content if $content;
            $diffbot_response = $client->$api($query_args);
        };
        if ($@) {
            print "There was an error getting the $api response for '$target_url': $@";
        }
        else {
            print "\n";
            print "Diffbot $api API response for '$target_url': \n";
            print dump($diffbot_response) . "\n";
        }
    }
}

sub usage {
    my ($error) = @_;

    print "\n$error\n" if $error;

    print <<USAGE;

Usage: 
    perl test_live_diffbot.pl --token <TOKEN> --url <URL> [ --request_type <TYPE> ] [ --content <CONTENT_STRING> ] --content_file <CONTENT_FILE>]  

Example Usage: 

    perl test_live_diffbot.pl --token 5555555 --url http://www.diffbot.com 

    perl test_live_diffbot.pl --token 5555555 --url http://www.diffbot.com --request_type image

    perl test_live_diffbot.pl --token 5555555 --url http://www.diffbot.com --request_type article --content_file local_capture.html
    
    perl test_live_diffbot.pl --token 5555555 --url http://www.diffbot.com --request_type article --content "<html><body>TestTest!</body></html>"

Options:
    TOKEN : get your token at http://diffbot.com/pricing/. Dont worry there is a free option!
    URL : The URL you want diffbot to analyze. Please include 'http://'. Default is $target_url
    REQUEST_TYPE : all | article | frontpage | product | image
    
    CONTENT : A string containing the content you wish diffbot to analyze
    
    CONTENT_FILE : A path to fil containing the content you wish diffbot to analyze

USAGE

    exit((defined $error) ? 1 : 0);
}
