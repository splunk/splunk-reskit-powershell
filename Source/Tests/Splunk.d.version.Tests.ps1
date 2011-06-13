param( $fixture )

Describe "get-splunkdVersion" {

	$local:fields = data {
		'Build'
		'ComputerName'
		'CPU_Arch'
		'GUID'
		'IsFree'
		'IsTrial'
		'Mode'
		'OSBuild'
		'OSName'
		'OSVersion'
		'Version'
	};							

	It "fetches logins using default parameters" {
		Get-SplunkDVersion | verify-results -fields $local:fields | verify-all;
	}
	
	It "fetches logins using custom splunk connection parameters" {
		Get-SplunkDVersion -ComputerName $script:fixture.splunkServer `
			-port $script:fixture.splunkPort `
			-Credential $script:fixture.splunkAdminCredentials | 
			verify-results -fields $local:fields | 
			verify-all;
	}	
}