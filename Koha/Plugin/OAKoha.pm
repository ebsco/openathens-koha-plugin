package Koha::Plugin::OAKoha;

use Modern::Perl; 
use base qw(Koha::Plugins::Base);
use C4::Context;
use C4::Members;
use C4::Auth;
use Koha::Libraries;
use Cwd            qw( abs_path );
use File::Basename qw( dirname );
use JSON qw/decode_json encode_json/;



my $PluginDir = C4::Context->config("pluginsdir");
$PluginDir = $PluginDir.'/Koha/Plugin/OAKoha';

## Here we set our plugin version
our $VERSION = 16.1104;

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name   => 'OpenAthens',
    author => 'KM - kmukhopadhyay@ebsco.com',
    description =>
'This plugin integrates Open Athens(OA) in Koha.<p>Go to Actions:Configure to set the API connection then go to the Actions:Run to configure attributes.</p>',
    date_authored   => '2017-03-28',
    date_updated    => '2017-05-11',
    minimum_version => '16.11',
    maximum_version => '',
    version         => $VERSION,
};

## This is the minimum code required for a plugin's 'new' method
## More can be added, but none should be removed
sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    return $self;
}

sub tool {
    my ( $self, $args ) = @_;

    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('submitted') ) {
        $self->SetupTool();
    }

}

## Logic for configure method
sub configure {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('save') ) {
        my $template = $self->get_template({ file => 'configure.tt' });

        ## Grab the values we already have for our settings, if any exist
        $template->param(
			oaconnectionurl 	=> $self->retrieve_data('oaconnectionurl'),
			oareturnurl			=> $self->retrieve_data('oareturnurl'),
			oaapikey 			=> $self->retrieve_data('oaapikey'),
			oaconnectionid 		=> $self->retrieve_data('oaconnectionid'),
			placeholder         => "",
        );

        print $cgi->header();
        print $template->output();
    }
    else {
		
		$self->store_data(
				{
					oaconnectionurl 	=> ($cgi->param('oaconnectionurl')?$cgi->param('oaconnectionurl'):"-"),
					oareturnurl 		=> ($cgi->param('oareturnurl')?$cgi->param('oareturnurl'):"-"),
					oaapikey 			=> ($cgi->param('oaapikey')?$cgi->param('oaapikey'):"-"),
					oaconnectionid 		=> ($cgi->param('oaconnectionid')?$cgi->param('oaconnectionid'):"-"),
				}
			);
		
        $self->go_home();
    }
}


sub SetupTool {
	my ( $self, $args ) = @_;
	my $cgi = $self->{'cgi'};
	
		#Get OpacUserJS Data
		my $OpacUserJS = C4::Context->preference("OpacUserJS");

        unless ( $cgi->param('save') ) {
        	my $template = $self->get_template({ file => 'setuptool.tt' });
		#Get Borrower Fields
		my $dbh = C4::Context->dbh;
		my $sql = "DESCRIBE borrowers";
		my $sth = $dbh->prepare($sql);
		$sth->execute();
		my @borrower_fields;
		while ( my $r = $sth->fetchrow_hashref() ) 
		{ 
			given($r->{Field}){
			when('categorycode') {  $r->{Field} = 'category';
						push @borrower_fields, $r->{Field};
					     }
			default {     push @borrower_fields, $r->{Field};
				}
			}
		}
		#Print Borrower fields
		#use Data::Dumper; die Dumper @borrower_fields;
		
		my $enableOA = 0;
		if($OpacUserJS =~m/\/\*oa{\*\/.*\/\*\}oa\*\//){$enableOA=1;}
				
				
				
				
		$template->param(
			params 		=> $self->retrieve_data('params'),
			borrower_fields => \@borrower_fields,
			enableOA => $enableOA,
		);
		print $cgi->header();
		print $template->output();
	}
	else {
	my $oaEnableSetting = $cgi->param('oaenabled');
	my $oaJS = '/*oa{*/var oas=document.createElement( "script" );oas.type = "text/javascript";oas.src="/plugin/Koha/Plugin/OAKoha/OAKoha.js";document.body.appendChild(oas);/*}oa*/';

	if($oaEnableSetting==1){
		if($OpacUserJS =~m/\/\*oa{\*\/.*\/\*\}oa\*\//){}else{
			$OpacUserJS = $OpacUserJS.$oaJS;
		}
	}else{
		if($OpacUserJS =~m/\/\*oa{\*\/.*\/\*\}oa\*\//){
			$OpacUserJS=~s/\/\*oa{\*\/.*\/\*\}oa\*\///g;
		}
	}

	my $enableOAQuery = C4::Context->dbh->do("UPDATE `systempreferences` SET `value`='".$OpacUserJS."' WHERE `variable`='OpacUserJS'");

	
		$self->store_data(
				{
					params 		=> ($cgi->param('params')?$cgi->param('params'):"-"),
				}
		);
		$self->go_home();
	}
}


sub install() {
    my ( $self, $args ) = @_;
	
	my $pluginSQL = C4::Context->dbh->do("INSERT INTO `plugin_data` (`plugin_class`, `plugin_key`, `plugin_value`) VALUES ('OA::Plugin', 'installedversion', '".$VERSION."')");
}




sub uninstall() {
    my ( $self, $args ) = @_;

	my $enableOA = C4::Context->dbh->do("INSERT INTO `systempreferences` (`variable`, `value`, `explanation`, `type`) VALUES ('OAEnabled', '1', 'If ON, enables OA Authentication on Koha login.', 'YesNo') ON DUPLICATE KEY UPDATE `variable`='OAEnabled', `value`=1, `explanation`='If ON, enables OA Authentication on Koha login.', `type`='YesNo'");
	
	
	my $enableOAUpdate = C4::Context->dbh->do("UPDATE `systempreferences` SET `value`='1' WHERE `variable`='OAEnabled'");
}
1;
