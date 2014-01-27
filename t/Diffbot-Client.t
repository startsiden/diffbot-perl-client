#!perl

use strict;
use warnings;

use Test::Deep;
use Test::More;
use Test::Exception;
use Test::Fake::HTTPD;

BEGIN { use_ok('Diffbot::Client') };

#########
# Constructor Tests
my $client; #define once

#token is required
ok( Diffbot::Client->new({token => '42' }), 'Class init with token ok');
throws_ok( sub { Diffbot::Client->new() }, qr/missing token/i, 'Class init without token throws exception');

#random args are discarded
$client = Diffbot::Client->new({ token => '42', foo => 'bar' });
ok( ! exists($client->{foo}), 'Class init random args are discarded'); 

#diffbot host can be overridden, and is cleaned up
$client = Diffbot::Client->new({ token => '42', diffbot_host => 'http://foobar.com' });
is ($client->{diffbot_host}, 'http://foobar.com', 'Class init diffbot host can be overriden');  

$client = Diffbot::Client->new({ token => '42', diffbot_host => 'foobar.com' });
is ($client->{diffbot_host}, 'http://foobar.com', 'Class init diffbot host http:// added');  

$client = Diffbot::Client->new({ token => '42', diffbot_host => 'http://foobar.com/' });
is ($client->{diffbot_host}, 'http://foobar.com', 'Class init diffbot host trailing slash stripped');  

#########
# query tests (this is the worker that realizes article, frontpage, product, and image client calls

my $httpd = get_a_simple_httpd(200);

$client = Diffbot::Client->new({ token => '42', diffbot_host => $httpd->endpoint });

#test that we get back JSON and query_args can be a HASH
cmp_deeply(
    $client->query({ 
        request_type => 'article', 
        query_args => { url => 'http://doesntmatter.com' }
    }),
    superhashof({ test => "true", fake_response => 'output' }),
    "query returns json resonse as perl object"
);

#test that query_args can be a scalar
cmp_deeply(
    $client->query({ 
        request_type => 'article', 
        query_args => 'http://doesntmatter.com'
    }),
    superhashof({ test => "true", fake_response => 'output' }),
    "query_args can be a scalar containing URL"
);

#test that the actual API calls work (article/frontpage/prduct/image)
# -the mothod is exported
# -the request URL is as expected
for my $api (qw(article frontpage product image classifier)) {
    cmp_deeply(
        $client->$api('http://doesntmatter.com'),
        superhashof({ 
            test => "true", 
            fake_response => 'output',
            url => "/v2/$api?token=42&url=http://doesntmatter.com"
        }),
        "calls to $api form the correct HTTP request"
    )
}

#test post method to article API
cmp_deeply(
    $client->article({
        url => 'http://doesntmatter.com',
        content => 'local_content!'
    }),
    superhashof({
        test => "true", 
        fake_response => 'output',
        url => "/v2/article?token=42&url=http://doesntmatter.com",
        content => 'local_content!'
    }),
    "POST to article are made"
);

#########
# Error handling tests

#URL is required
throws_ok( sub {
    $client->query({ 
        request_type => 'article', 
        query_args => { timeout => 5 } # no url
    })
}, qr/missing url/i, 'URL is required');
     
#timeout must be INT
throws_ok( sub {
    $client->query({ 
        request_type => 'article', 
        query_args => { url => 'http://doesntmatter.com', timeout => 'Fiveish seconds' }
    })
}, qr/invalid timeout/i, 'Timeout must be positive integer');

#invalid API call is rejected by cient
throws_ok( sub {
    $client->query({ 
        request_type => 'foo', 
        query_args => { url => 'http://doesntmatter.com' }
    })
}, qr/invalid request_type/i, 'Invalid API type rejected at client');

#verify handling of 500
throws_ok( sub {
    $client->query({ 
        request_type => 'article', 
        query_args => { url => 'http://givemea500.com' }
    })
}, qr/The diffbot server returned: 500/i, 'A Server 500 is handled gracefully');

#verify handling bad JSON
throws_ok( sub {
    $client->query({ 
        request_type => 'article', 
        query_args => { url => 'http://badjson.com' }
    })
}, qr/Could not parse the diffbot response/i, 'Bad JSON is handled gracefully');

done_testing();

#########
# utility sub routines

sub get_a_simple_httpd {

    my $httpd = Test::Fake::HTTPD->new( timeout => 5);
    $httpd->run(sub {
        my $request = shift;
        my $url = $request->uri->as_string;

        my $method = $request->method;

        #a 500 is requested
        if ($method eq 'GET' && $url =~ /500/) {
            return [ 
                500,
                [ 'Content-Type' => 'application/json' ],
                [ "{ \"test\" : \"true\", \"fake_response\": \"output\", \"url\" : \"$url\" }" ]
            ];
        }
        elsif ($method eq 'GET' && $url =~ /badjson/) {
            return [ 
                200,
                [ 'Content-Type' => 'application/json' ],
                [ "{ \"json\" : { \"busted\" }" ]
            ];
        }
        elsif ($method eq 'POST') {
            my $content = $request->content;
            return [ 
                200,
                [ 'Content-Type' => 'application/json' ],
                [ "{ \"test\" : \"true\", \"fake_response\": \"output\", \"url\" : \"$url\", \"content\" : \"$content\" }" ]
            ];
        }
        else {
            return [ 
                200,
                [ 'Content-Type' => 'application/json' ],
                [ "{ \"test\" : \"true\", \"fake_response\": \"output\", \"url\" : \"$url\" }" ]
            ];
        }
    });

    return $httpd;
}
