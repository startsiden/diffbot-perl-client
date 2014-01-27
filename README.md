# Diffbot API Perl Client

# Overview

This module provides a Perl client for the diffbot REST API. 

Details of the REST API can be found here : http://www.diffbot.com/. 

You will need a token from diffbot to use their service.

# Installation

The following are the environment prerequisites:
 
You will need _make_ installed in your environment.

    In debian based systems (e.g., ubuntu, mint, etc):
    sudo apt-get install build-essential

You will need to install some perl dependancies:

    cpan install LWP::UserAgent Data::Dump JSON Test::Deep Test::Exception Test::Fake::HTTPD Getopt::Long

Ok, now you can install the actual module after downloading and extracting:

    tar xzvf Diffbot-Client-0.01.tar.gz
    cd Diffbot-Client-0.01
    perl Makefile.PL
    make
    make test
    sudo make install

# Documentation

This module contains built in documentation that is browsable once the module is installed.

To view the documentation after installation via manpages:

    man Diffbot::Client

To view the documentation after installation via perldoc: 

    perldoc Diffbot::Client

# Usage

## Make Diffbot fetch and analyze content using the article, frontpage, product, and image API
    
Once you have received a token from The Diffbot, you begin using the client module by instantiatng it:

    use Diffbot::Client
    my $client = Diffbot::Client->new({ token => '123456789' });

If you need manipuate the WWW Client config you can provide your own instantiated LWP::UserAgent:

    use Diffbot::Client;
    use LWP::UserAgent;
    my $ua = LWP::UserAgent->new( agent => 'Custom UserAgent!!' );
    my $client = Diffbot::Client->new({ token => '123456789', ua => $ua });

Now all you have to do is begin calling sub routines to get results!

To submit a URL to the article API make the following request :

    my $response = $client->article({ url => 'http://analyzethis.com' });

This simpler parameter syntax works too:

    my $response = $client->article('http://analyzethis.com');

To submit a URL to the classifier (aka analyze) API make the following request :

    my $response = $client->analyze({ url => 'http://analyzethis.com' });

Similarly, to use the other APIs make requests like this:

    $response = $client->frontpage({ url => 'http://analyzethis.com' });
    $response = $client->product({ url => 'http://analyzethis.com' });
    $response = $client->image({ url => 'http://analyzethis.com' });

If you want to extract key values out of the response, do so like this:

    print $response->{title};

If you want to see the full Diffbot response in all of it's glory do this:

    use Data::Dump qw(dump);
    print dump($response); #wowsa thats a lotta data!

If you want to control the timeout behaviour and the fields returned, make a request like this:

    my $response = $client->article({ 
        url => 'http://analyzethis.com',
        timeout => 30000, 
        fields => 'title,link,text'
    });

Here is an alternate syntax for making the same request:
    
    my $response = $client->query({
        request_type => 'article',
        query_args => { 
            url => 'http://analyzethis.com',
            timeout => 30000, 
            fields => 'title,link,text'
        }
    });

If something is going wrong and you want to get a better look at the full HTTP request and response make a request like this:
    
    use Data::Dump qw(dump)

    #$response is no the HTTP::Response object
    my $response = $client->query({
        request_type => 'article',
        query_args => { url => 'http://analyzethis.com', },
        return_http_response => 1 
    });

    print $response->status_line

## Submit content to Diffbot for analysis

If you want to submit local content to diffbot make a request like this:

    my $response = $client->article({ 
        url => 'http://analyzethis.com',
        content => $local_html_content
    });

This alternative syntax for submitting content to analyze works too:

    my $response = $client->query({
        request_type => 'article',
        query_args => { 
            url     => 'http://analyzethis.com',
            content => $local_html_content
        }
    });

Note that not all of the diffbot APIs support submitting local content for analysis. See the diffbot API docs for more details.

## Exceptions

See the built in docs for up to date exception listing and description. But given we are using Perl, it's easy! Just eval everything:

    my $response;
    eval {
        $response = $client->article({ url => 'http://analyzethis.com' });
    };
    if ($@) {
        print "Something went wrong: $@";
    }

## Can I havez some example code ?

The module ships with a fully functional script that uses the module, called query\_diffbot.pl
Run the following command to get up to date usage instructions:

    perl bin/query_diffbot.pl --help

-Initial commit by Zyle Zeeuwen-
