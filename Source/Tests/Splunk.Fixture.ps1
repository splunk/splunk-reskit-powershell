
$local:fixture = @{
	# the name or IP of the splunk server
	splunkServer = 'indexer';
	
	# the splunk user name
	splunkUser = 'admin';
	
	# the splunk password
	splunkPassword = 'password';
	
	# splunk management port
	splunkPort = 8089
	
	#test license file
	licenseFilePath = $MyInvocation.MyCommand.Path | split-path -parent | Join-Path -ChildPath 'splunk.license';
	
	#------- you do not need to edit below this line ----------
	
	defaultConfigPath = get-module splunk | split-path | join-path -ChildPath "SplunkConnectionObject.xml";
};

$local:fixture.splunkAdminCredentials = New-Object System.Management.Automation.PSCredential( 
	$local:fixture.splunkUser, 
	( ConvertTo-SecureString -String $local:fixture.splunkPassword -AsPlainText -Force ) 
);

$local:fixture;
Write-Debug 'import of splunk.fixture.ps1 complete';