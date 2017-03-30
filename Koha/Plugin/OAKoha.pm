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
our $VERSION = 0.1;

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name   => 'Koha OA LA API Integration',
    author => 'KM - kmukhopadhyay@ebsco.com',
    description =>
'This plugin integrates Open Athens(OA) in Koha.<p>Go to Run tool (left) for setup instructions and then Configure(right) to configure the API Plugin.</p>',
    date_authored   => '2016-3-28',
    date_updated    => '',
    minimum_version => '',
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
			oaorgid 		=> $self->retrieve_data('oaorgid'),
			oascope 		=> $self->retrieve_data('oascope'),
			oaapikey 		=> $self->retrieve_data('oaapikey'),
			oaconnectionid 		=> $self->retrieve_data('oaconnectionid'),
			params  		=> $self->retrieve_data('params'),
			
        );

        print $cgi->header();
        print $template->output();
    }
    else {
		
		$self->store_data(
				{
					oaorgid 		=> ($cgi->param('oaorgid')?$cgi->param('oaorgid'):"-"),
					oascope 		=> ($cgi->param('oascope')?$cgi->param('oascope'):"-"),
					oaapikey 		=> ($cgi->param('oaapikey')?$cgi->param('oaapikey'):"-"),
					oaconnectionid 		=> ($cgi->param('oaconnectionid')?$cgi->param('oaconnectionid'):"-"),
					params  		=> ($cgi->param('params')?$cgi->param('params'):"-"),
				}
			);
		
        $self->go_home();
    }
}


sub install() {
    my ( $self, $args ) = @_;
##Leaving this code incase this plugin needs its own table in the future
#    my $table = $self->get_qualified_table_name('config');

#    return C4::Context->dbh->do( "
#		CREATE TABLE $table (
#		`oaid` INT NOT NULL AUTO_INCREMENT,
#		`oakey` VARCHAR(100) NOT NULL,
#		PRIMARY KEY (`oaid`)) ENGINE = INNODB;
#    " ); 

	
	
	my $enableOA = C4::Context->dbh->do("INSERT INTO `systempreferences` (`variable`, `value`, `explanation`, `type`) VALUES ('OAEnabled', '1', 'If ON, enables OA Authentication on Koha login.', 'YesNo') ON DUPLICATE KEY UPDATE `variable`='OAEnabled', `value`=1, `explanation`='If ON, enables OA Authentication on Koha login.', `type`='YesNo'");
	
	
	my $enableOAUpdate = C4::Context->dbh->do("UPDATE `systempreferences` SET `value`='1' WHERE `variable`='OAEnabled'");
	
	my $pluginSQL = C4::Context->dbh->do("INSERT INTO `plugin_data` (`plugin_class`, `plugin_key`, `plugin_value`) VALUES ('OA::Plugin', 'installedversion', '".$VERSION."')");
	#use Data::Dumper; die Dumper $pluginSQL;		
}




sub uninstall() {
    my ( $self, $args ) = @_;
##Leaving this code incase this plugin needs its own table in the future
#    my $table = $self->get_qualified_table_name('config');

#    return C4::Context->dbh->do("DROP TABLE $table");
	my $enableOA = C4::Context->dbh->do("INSERT INTO `systempreferences` (`variable`, `value`, `explanation`, `type`) VALUES ('OAEnabled', '1', 'If ON, enables OA Authentication on Koha login.', 'YesNo') ON DUPLICATE KEY UPDATE `variable`='OAEnabled', `value`=1, `explanation`='If ON, enables OA Authentication on Koha login.', `type`='YesNo'");
	
	
	my $enableOAUpdate = C4::Context->dbh->do("UPDATE `systempreferences` SET `value`='1' WHERE `variable`='OAEnabled'");
}

sub SetupTool {
	my ( $self, $args ) = @_;
	my $cgi = $self->{'cgi'};

	my $template = $self->get_template({ file => 'setuptool.tt' });

	print $cgi->header();
	print $template->output();
}
1;

