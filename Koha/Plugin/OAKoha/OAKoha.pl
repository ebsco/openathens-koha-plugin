#!/usr/bin/perl -w

# This file is part of Koha.
# parts copyright 2010 BibLibre
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.


use strict;
use warnings;

use CGI qw ( -utf8 );

use Koha::Patrons;

use C4::Auth qw/get_template_and_user/;
use C4::Koha;
use C4::Output qw/output_html_with_http_headers/;
use JSON;
use Encode qw( encode is_utf8);
use MIME::Base64;
use JSON;
use Cwd qw( abs_path );
use File::Basename qw( dirname );
use Koha::Template::Plugin::Categories;
use feature qw(switch);
use LWP;
use URI::Escape;
use Try::Tiny;
use Net::IP;

my $query = new CGI;
my $dbh = C4::Context->dbh;

my $PluginClass='Koha::Plugin::OAKoha';
my $table='plugin_data';

my $sql = "SELECT plugin_key, plugin_value FROM plugin_data WHERE plugin_class = ? ";
my $sth = $dbh->prepare($sql);
$sth->execute( $PluginClass );
$sth->execute();

my $PluginDir = C4::Context->config("pluginsdir");
$PluginDir = $PluginDir.'/Koha/Plugin/OAKoha';

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => $PluginDir."/opac-oa.tt",
        query           => $query,
        type            => "opac",
        is_plugin       => 1,
        authnotrequired => 0,
        debug           => 1,
    }
);

my $api_response = "";

#Commenting cookie check to support Callback URL functionality
=head1
if($query->cookie('oasession')==1){ # exit if OASession cookie exists.
	if( defined $query->param("oaurl")){
		my $return_url = uri_unescape($query->param("oaurl")); 
		print $query->redirect($return_url);
	}
	use Data::Dumper; die Dumper $query->cookie('oasession');
}
=cut

#Get Configuration settings
my ( $oaconnectionurl, $oareturnurl, $oaapikey, $oaconnectionid, $params) = "";

while ( my $r = $sth->fetchrow_hashref() ) {
	given($r->{plugin_key}){
		when('oaconnectionurl') {$oaconnectionurl=$r->{plugin_value};}
		when('oareturnurl') {$oareturnurl=$r->{plugin_value};}
		when('oaapikey') {$oaapikey=$r->{plugin_value};}
                when('oaconnectionid') {$oaconnectionid=$r->{plugin_value};}
                when('params') {$params=$r->{plugin_value};}
	}
}
	my $base_url = $oaconnectionurl;
	my $api_key = $oaapikey;

	#Get Koha borrower details according to params specified
	#Borrower details are obtained in context of a logged in user.
	my @params_arr = split /,/, $params;
	my $attrib_json = {};

	my $borrow = Koha::Patrons->find( $borrowernumber )->unblessed;
	if (defined $query->param("borrower")){use Data::Dumper; die Dumper $borrow;}
	
	if (scalar @params_arr > 0){
    		while (my $element = shift(@params_arr)){ #Build Attributes
			given($element){
			when('category') {  $attrib_json->{"category"} = Koha::Template::Plugin::Categories->GetName($borrow->{"categorycode"});
					     }
			default {     $attrib_json->{$element} = $borrow->{$element};
				}
			}
    		}
    	}
        my $return_url;
        if ($oareturnurl == '-' || $oareturnurl == '')
        {
			if( defined $query->param("l")){
				$return_url = uri_unescape($query->param("l"));
			}elsif( defined $query->param("oaurl")){
				$return_url = uri_unescape($query->param("oaurl"));
			}else{
				$return_url = $ENV{'REQUEST_SCHEME'}.'://'.$ENV{'HTTP_HOST'}.'/cgi-bin/koha/opac-user.pl';
			}
        }else{$return_url = $oareturnurl;}
		
		#Connect to OA
	my %post_json;
	if (defined $query->param("returnData")){
		my $returnData = $query->param("returnData");
		%post_json = ("connectionID"=> $oaconnectionid,
				"uniqueUserIdentifier"=> $borrow->{userid},
				"displayName"=> $borrow->{userid},
				"returnData"=> $returnData,
				"attributes"=> $attrib_json);
	}
	else{

    		%post_json = ("connectionID"=> $oaconnectionid,
				"uniqueUserIdentifier"=> $borrow->{userid},
				"displayName"=> $borrow->{userid},
				"returnUrl"=> $return_url,
				"attributes"=> $attrib_json);
	}
		
	if (defined $query->param("request")){use Data::Dumper; die Dumper %post_json;}
	
	my $req = HTTP::Request->new( 'POST', $base_url );
	$req->header( 'Content-Type' => 'application/json' );
	$req->header( 'Authorization' => 'OAApiKey '.$api_key);
	$req->content( encode_json \%post_json );
	
	my $lwp = LWP::UserAgent->new;
	my $response = $lwp->request( $req );
	$response = $response->decoded_content(charset => 'none');
	
	my %response_json; 
	if (defined $query->param("response")){use Data::Dumper; die Dumper $response;}
		
	try{
		$response = JSON->new->utf8->decode($response);
		if (defined $response->{sessionInitiatorUrl}){
			%response_json = ("oaResponse"=>"Success","sessionUrl"=>$response->{sessionInitiatorUrl});
		}else{
			%response_json = ("oaResponse"=>"Fail","data"=>$response);
		}
	}catch{ %response_json = ("oaResponse"=>"Fail","error"=>"$_"); };
	 
	$api_response = encode_json \%response_json;
	
	if(not defined $query->param("l")){
		$api_response = '<script>window.location.href="'.$response->{sessionInitiatorUrl}.'"</script>';
	}
	
	
my $OASession = $query->cookie(
                            -name => 'oasession',
                            -value => 1
                );
				 
$cookie = [$cookie, $OASession];				

$template->param(
api_response	=> $api_response,
);

output_html_with_http_headers $query, $cookie, $template->output, undef, { force_no_caching => 1 };
