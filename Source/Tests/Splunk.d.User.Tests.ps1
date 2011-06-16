param( $fixture )

Describe "get-splunkduser" {
	
	$fields = data {
		"ComputerName"
		"DefaultApp"
		"defaultAppSourceRole"
		"Email"
		"FullName"
		"password"
		"roles"
		"Splunk_Home"
		"Type"
		"UserName"
	};
			
	It "yields results with default parameters" {
		$results = Get-SplunkdUser;
		verify-results $results $fields;	
	}
	
	It "yields results with custom credentials" {
		$results = Get-SplunkdUser -Credential $script:fixture.splunkAdminCredentials;
		verify-results $results $fields;	
	}
	
	It "yields results with custom server name" {
		$results = Get-SplunkdUser -Computer $script:fixture.splunkServer;
		verify-results $results $fields;	
	}
	
	It "yields results with custom protocol" {
		$results = Get-SplunkdUser -protocol 'https';
		verify-results $results $fields;	
	}
	
	It "yields results with custom port" {
		$results = Get-SplunkdUser -Port $script:fixture.splunkPort;
		verify-results $results $fields;	
	}
}