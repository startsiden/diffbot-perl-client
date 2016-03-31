package Diffbot::Client;

use 5.012000;
use strict;
use warnings;

our $VERSION = '0.02';

use Carp;
use JSON;
use LWP::UserAgent;

my $DEFAULTS = {
    'diffbot_host' => 'http://api.diffbot.com',
};

my $PATHS = {
    'article'   => 'v3/article',
    'frontpage' => 'v2/frontpage',
    'image'     => 'v2/image',
    'product'   => 'v2/product',
    'analyze'   => 'v2/classifier',
    'classifier' => 'v2/classifier',
};

sub new {
    my ($class, $args) = @_;

    my $self = bless {}, $class;

    croak "Missing token" unless $args->{token};
    $self->{token} = $args->{token};
    
    #get diffbot URL, verify starts with http:// and strip trailing slash
    $self->{diffbot_host} = $args->{diffbot_host} || $DEFAULTS->{diffbot_host};
    $self->{diffbot_host} = 'http://' . $self->{diffbot_host} unless
        $self->{diffbot_host} =~ qr{^http://};
    $self->{diffbot_host} =~ s{/$}{};
  
    eval {
        if ($args->{ua}) { 
            $self->{ua} = $args->{ua};
        }
        else {
            $self->{ua} = LWP::UserAgent->new();
        }
    };
    if ($@) { 
        croak "Error initializing WWW client: $@";
    }

    return $self;
}

#This dynamically generates sub routines:
for my $api (sort keys %$PATHS) {

    # turn off strict refs so that we can
    # register a method in the symbol table
    no strict "refs";

    *$api = sub {
        my ($self, $query_args) = @_;
        
        return $self->query({ 
            request_type => $api, 
            query_args   => $query_args
        });
    };
}

sub query {
    my ($self, $args) = @_;

    croak "Missing request_type" unless $args->{request_type};
    my $request_type = $args->{request_type};
    croak "Invalid request_type" unless $PATHS->{$request_type};

    #query args must be present. 
    #It can be a scalar (just the URL) or a hashref of args
    croak "Missing query_args" unless $args->{query_args};
    my $query_args = (ref($args->{query_args}) eq 'HASH')
        ? $args->{query_args}
        : { url => $args->{query_args} };

    #XXX: Additional URL validation here ?
    croak "Missing url" unless $query_args->{url};

    croak "Invalid timeout. Must be positive integer number of milliseconds" 
        if defined $query_args->{timeout} && $query_args->{timeout} !~ /^\d+$/;

    #XXX: No validation of fields,mode, or stats params
    
    my ($request_url, $http_request, $http_response);
    eval {

        #strip content from query args (or it will end up in URL)
        my $content = $query_args->{content};
        delete($query_args->{content});
        
        $request_url = $self->_build_get_url($request_type,$query_args);

        #if content is present, this is a POST, else it is a GET
        if ($content) {
            $http_request = HTTP::Request->new( POST => $request_url );
            $http_request->header( 'Accept' => 'application/json' );
            $http_request->header( 'Content-Type' => 'text/html' );
            
            #XXX: Must handle encoding of non-ascii here
            $http_request->content($content);

        }
        else {
            $http_request = HTTP::Request->new( GET => $request_url );
            $http_request->header( 'Accept' => 'application/json' );
        }
    };
    if ($@) {
        croak "Error creating HTTP Request for url '" . 
            $request_url || '' . "' : $@";
    }

    eval {
        $http_response = $self->{ua}->request($http_request);
    };
    if ($@) {
        croak "Error making HTTP Request for url '" . 
            $request_url || '' . "' : $@";
    }

    # for debugging / when the client seems to be misbehaving
    if ($args->{return_http_response}) {
        return $http_response;
    }

    my $diffbot_response;
    if ($http_response && $http_response->is_success) {
        my $json_string = $http_response->decoded_content;
        eval {
            $diffbot_response = decode_json($json_string);
        };
        if ($@) {
            croak "Could not parse the diffbot response for url '" . 
                $request_url || '' . "' : $@";
        }
    }
    else {
        croak "The diffbot server returned: " . $http_response->status_line . 
            " for url '" . $request_url || '' . "' : $@";
    }

    return $diffbot_response;
}

sub _build_get_url {
    my ($self, $request_type, $query_args) = @_;

    $query_args->{token} = $self->{token};

    my $diffbot_url = 
        $self->{diffbot_host} . '/' . $PATHS->{$request_type} .  
        '?' . join('&', map { "$_=$query_args->{$_}" } sort keys %$query_args );

    return $diffbot_url;
}

1;
__END__

=head1 NAME

Diffbot::Client - perl client for the diffbot REST API.

=head1 SYNOPSIS

  use Diffbot::Client;
  
  my $client = Diffbot::Client->new({ token => $token });
  
  my $diffbot_article_response   = $client->article({ url => $target_url });
  my $diffbot_frontpage_response = $client->frontpage({ url => $target_url });
  my $diffbot_product_response   = $client->product({ url => $target_url });
  my $diffbot_image_response     = $client->image({ url => $target_url });
  my $diffbot_classifier_response = $client->classifier({ url => $target_url });

  #note: analyze is an alias for classifier
  my $diffbot_analyze_response = $client->analyze({ url => $target_url });

=head1 DESCRIPTION

This module provides a Perl client for the diffbot REST API. Details of the REST API can be found here : http://www.diffbot.com/. You will need a token from diffbot to use their service.

There are five exposed APIs: article, frontpage, product, image, and classifier.
Each API can be queried in two ways:

=over

=item Fetch and Analyze 

You provide a URL, and diffbot fetches the URL and analyzes the content

=item Just Analyze 

You fetch the URL and provide the content, and diffbot analyzes the content

=back

In all cases, the return value is a hashref containing the response. See the API documentation for the specific fields returned.

=head1 Constructor

$client = Diffbot::Client->new($args)

=head2 $args values

$args is a hashref that contains the following key value pairs:

=over

=item * token: Required. Request a token from http://www.diffbot.com/

=item * diffbot_host: Optional. Change the diffbot_server host from the default http://api.diffbot.com

=item * ua: Optonal. You may pass in a LWP::UserAgent if you need to customize HTTP interaction. If not provided, a LWP::UserAgent will be created.  

=back

=head2 Exceptions

=over

=item * Missing token

You must provide a valid token

=item * Error initializing WWW client:

This is an inernal error that was raised while creating the LWP::UserAgent. This indicates a missing dependancy or networking issue.

=back

=head1 Fetch and Analyze Functions

=over

=item $response = $client->article($args);

=item $response = $client->frontpage($args);

=item $response = $client->product($args);

=item $response = $client->image($args);

=item $response = $client->image($args);

=item $response = $client->classifier($args);

=item $response = $client->analyze($args);

=back

=head2 $args values

$args is a hashref that contains the following key value pairs:

=over

=item * url: Required. The URL to fetch (must include http://)

=item * fields: Optional. Specify which fields to include in the response

=item * timeout: Optional. The number of milliseconds before diffbot will terminate the response

=back

=head2 $response

The response is a hash reference containing keys. See the API doc for the specific keys returned. As an example to access the 'links' key or the response:

$links = $response->{links};

=head2 Exceptions

=over

=item * Missing query_args

You did not pass an $args variable to the sub routine

=item * Missing url

You did not include a 'url' key value pair in $args

=item * Invalid timeout. 

You passed an invalid timeout value to the sub routine. The timeout must be positive integer number of milliseconds

=item * Error creating HTTP Request for url / Error making HTTP Request for url

This is an internal error. Your URL is likely malormed or your environment is missing Perl dependancies.

=item * Could not parse the diffbot response for url

The diffbot server response was not well formed JSON.

=item * The diffbot server returned: 

The diffbot server did not respond with a HTTP 200 OK

=back

=head1 Just Analyze Functions

Not Implemented

=head1 Advanced / Diagnostic Functions

=head2 $repsone=query($args)

=head3 Example

    $response = query({
       request_type => 'article',
       query_args   => {
           url     => 'http://analyzethis.com',
           timeout => 30
       },
       return_http_response => 1 
    }); 

If you need to see what is happenning under the hood this function is useful. this is the internal function that actually does all the work. Note this is not 'public' so the author does not provide any backward compatability in the future if you choose to use this sub routine

=head3 $args values

=over

=item * request_type: Required. The API to use : (i.e., article, frontpage, product, image, analyze, classifier)

=item * query_args: This is the hashref documented above (url, timeout) in the Fetch and Analyze section.

=item * return_http_response: Optional. If set to true, the sub routine will return the full HTTP::Repsonse instead of just the diffbot response. The reponse also contains the HTTP::Request. Useful for debugging.

=back

=head3 Additional Exceptions

=over

=item * Missing request_type / Invalid request_type

You must provide a request_type key with a valid API name (i.e., article, frontpage, product, image, analyze, classifier)

=back

=head1 SEE ALSO

Refer to the documentation of the API on http://www.diffbot.com/.

=head1 AUTHOR

Kyle Zeeuwen, <lt>kyle.zeeuwen@gmailcom.com<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Diffbot

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.16.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
