
$local:fixture = @{
	# the name or IP of the splunk server
	splunkServer = '192.168.56.101';
	
	# the splunk user name
	splunkUser = 'admin';
	
	# the splunk password
	splunkPassword = 'password';
	
	# splunk management port
	splunkPort = 8089
	#------- you do not need to edit below this line ----------
	
	defaultConfigPath = get-module splunk | split-path | join-path -ChildPath "SplunkConnectionObject.xml";
};

$local:fixture.splunkAdminCredentials = New-Object System.Management.Automation.PSCredential( 
	$local:fixture.splunkUser, 
	( ConvertTo-SecureString -String $local:fixture.splunkPassword -AsPlainText -Force ) 
);

$local:fixture;
Write-Debug 'import of splunk.fixture.ps1 complete';