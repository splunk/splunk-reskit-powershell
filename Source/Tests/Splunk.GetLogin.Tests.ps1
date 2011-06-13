param( $fixture )


Describe "get-splunkLogin" {

	$local:fields = data {
		"AuthToken"
		"ComputerName"
		"TimeAccessed"
		"UserName"
	};							

	It "fetches logins using default parameters" {
		Get-SplunkLogin | verify-results -fields $local:fields | verify-all;
	}
	
	It "fetches specific login by name using default parameters" {
		$results = Get-SplunkLogin -Name $script:fixture.splunkUser;
		
		@($results).length -eq 1 -and ( $results | verify-results -fields $local:fields | verify-all )
	}
	
	It "fetches logins using custom splunk connection parameters" {
		Get-SplunkLogin -ComputerName $script:fixture.splunkServer `
			-port $script:fixture.splunkPort `
			-Credential $script:fixture.splunkAdminCredentials | 
			verify-results -fields $local:fields | 
			verify-all;
	}
	
	It "fetches specific login using custom splunk connection parameters" {
		Get-SplunkLogin -name $script:fixture.splunkUser `
			-ComputerName $script:fixture.splunkServer `
			-port $script:fixture.splunkPort `
			-Credential $script:fixture.splunkAdminCredentials | 
			verify-results -fields $local:fields | 
			verify-all;
	}
}