#!/usr/bin/perl

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
#use warnings; FIXME - Bug 2505

use CGI qw ( -utf8 );

use C4::Auth;
use C4::Koha;
use C4::Output;
use JSON;
use Encode qw( encode is_utf8);
use WWW::Curl::Easy;
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

my $PluginDir = dirname(abs_path($0));

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
my $userid;

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

if (defined $query->param("q") && defined $query->param("l"))
{
	require C4::Members;
	$userid = $query->param("q");
	my $base_url = $oaconnectionurl;
        #"https://login.openathens.net/api/v1/".scope."/organisation/".orgid."/local-auth/session";
	my $api_key = $oaapikey;

	#Get Koha borrower details according to params specified
	my @params_arr = split /,/, $params;
	my $attrib_json = {};
	if (scalar @params_arr > 0)
    	{
        	my $borrow = C4::Members::GetMember( borrowernumber => $borrowernumber );
    		while (my $element = shift(@params_arr))
    		{
			given($element){
                        when('surname'){
					my $surname = $borrow->{surname};
					$attrib_json->{"surname"} = $surname;
				}
			when('category'){
					my $categorycode = $borrow->{categorycode};
					my $category = Koha::Template::Plugin::Categories->GetName($categorycode);
					$attrib_json->{"category"} = $category;
				}
			when('firstname'){
					my $firstname = $borrow->{firstname};
					$attrib_json->{"firstname"} = $firstname;
				}
			when('email'){
					my $email = $borrow->{email};
					$attrib_json->{"email"} = $email;
				}
			when('cardnumber'){
					my $cardnumber = $borrow->{cardnumber};
					$attrib_json->{"cardnumber"} = $cardnumber;
				}
			when('branchcode'){
					my $branchcode = $borrow->{branchcode};
					$attrib_json->{"branchcode"} = $branchcode;
				}

                        }
    		}
    	}

        my $return_url;
        if ($oareturnurl == '-' || $oareturnurl == '')
        {
		$return_url = uri_unescape($query->param("l"));
        }
        else
	{
		$return_url = $oareturnurl;
        }
	#Connect to OA
    	my %post_json = ("connectionID"=>$oaconnectionid,"uniqueUserIdentifier"=>$userid,"displayName"=>$userid,"returnUrl"=>$return_url,"attributes"=>$attrib_json);
    	my $headers = ['Content-Type:application/vnd.eduserv.iam.auth.localAccountSessionRequest+json','Authorization: OAApiKey '.$api_key];
	
	my $req = HTTP::Request->new( 'POST', $base_url );
	$req->header( 'Content-Type' => 'application/vnd.eduserv.iam.auth.localAccountSessionRequest+json' );
	$req->header( 'Authorization' => 'OAApiKey '.$api_key);
	$req->content( encode_json \%post_json );
	my $lwp = LWP::UserAgent->new;
	my $response = $lwp->request( $req );
        $response = $response->decoded_content(charset => 'none');
        my %response_json; 
	try
        {
        	$response = JSON->new->utf8->decode($response);
        	if (defined $response->{sessionInitiatorUrl})
		{
			%response_json = ("oaResponse"=>"Success","sessionUrl"=>$response->{sessionInitiatorUrl});
		}
		else
		{
			%response_json = ("oaResponse"=>"Fail","data"=>$response);
		}
	}
	catch
	{
             %response_json = ("oaResponse"=>"Fail","error"=>"LWP  Request error");
	};
        $api_response = encode_json \%response_json;
}

$template->param(
api_response	=> $api_response,
);

output_html_with_http_headers $query, $cookie, $template->output, undef, { force_no_caching => 1 };
