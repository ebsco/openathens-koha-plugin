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
use Encode;
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
my ( $oaorgid, $oascope, $oaapikey,$oaconnectionid,$params) = "";

while ( my $r = $sth->fetchrow_hashref() ) {
	given($r->{plugin_key}){
		when('oaorgid') {$oaorgid=$r->{plugin_value};}
		when('oascope') {$oascope=$r->{plugin_value};}
		when('oaapikey') {$oaapikey=$r->{plugin_value};}
                when('oaconnectionid') {$oaconnectionid=$r->{plugin_value};}
                when('params') {$params=$r->{plugin_value};}
}
}

if (defined $query->param("q"))
{
	require C4::Members;
	$userid = $query->param("q");
	my $base_url = "https://login.openathens.net/api/v1/".$oascope."/organisation/".$oaorgid."/local-auth/session";
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

        #Connect to OA
    	my %post_json = ("connectionID"=>$oaconnectionid,"uniqueUserIdentifier"=>$userid,"displayName"=>$userid,"returnUrl"=>"http://".$ENV{'HTTP_HOST'}."/cgi-bin/koha/opac-user.pl","attributes"=>$attrib_json);
    	my $headers = ['Content-Type:application/vnd.eduserv.iam.auth.localAccountSessionRequest+json','Authorization: OAApiKey '.$api_key];
    	my $curl = WWW::Curl::Easy->new;
    	$curl->setopt(CURLOPT_HEADER,1);
    	$curl->setopt(CURLOPT_URL, $base_url);
    	$curl->setopt(CURLOPT_HTTPHEADER, $headers);
    	$curl->setopt(CURLOPT_POST(),1);
    	$curl->setopt(CURLOPT_POSTFIELDS(),encode_json \%post_json);
    	my $response_body;
    	$curl->setopt(CURLOPT_WRITEDATA,\$response_body);
    	my $retcode = $curl->perform;
    	my %response_json;
    	if ($retcode == 0){
        	my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);
        	my $response_sessn;
        	if ($response_code == '200')
        	{
            		my @response_conv = split /{/, $response_body, 2;
            		$response_sessn = '{'.$response_conv[1];
            		my $response_sessn_json = JSON->new->utf8->decode($response_sessn);
            		my $response_session_url = $response_sessn_json->{sessionInitiatorUrl};
            		%response_json = ("oaResponse"=>"Success","sessionUrl"=>$response_session_url);
            		$api_response = encode_json \%response_json;
        	}
        	else
        	{
             		%response_json = ("oaResponse"=>"Fail","data"=>$response_body);
             		$api_response = encode_json \%response_json;
        	}
    	}
    	else{
         	%response_json = ("oaResponse"=>"Fail","error"=> $curl->errbuf);
         	$api_response = encode_json \%response_json;
    	}    
}

$template->param(
api_response	=> $api_response,
);

output_html_with_http_headers $query, $cookie, $template->output, undef, { force_no_caching => 1 };
