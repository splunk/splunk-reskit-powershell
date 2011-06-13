param( $fixture )

Describe "get-splunkd" {
	
	$fields = data {
		"ComputerName"                                                                   
		"DefaultHostName"                                                                
		"EnableWeb"                                                                      
		"EnableWebSSL"                                                                   
		"HTTPPort"                                                                       
		"MgmtPort"                                                                       
		"MinFreeSpace"                                                                   
		"SessionTimeout"                                                                 
		"Splunk_DB"                                                                      
		"Splunk_Home"                                                                    
		"TrustedIP"                                                                      
		};
			
	It "yields results with default parameters" {
		$results = Get-Splunkd;
		verify-results $results -fields $fields;	
	}
	
	It "yields results with custom credentials" {
		$results = Get-Splunkd -Credential $script:fixture.splunkAdminCredentials;
		verify-results $results -fields $fields;	
	}
	
	It "yields results with custom server name" {
		$results = Get-Splunkd -Computer $script:fixture.splunkServer;
		verify-results $results -fields $fields;	
	}
	
	It "yields results with custom protocol" {
		$results = Get-Splunkd -protocol 'https';
		verify-results $results -fields $fields;	
	}
	
	It "yields results with custom port" {
		$results = Get-Splunkd -Port $script:fixture.splunkPort;
		verify-results $results -fields $fields;	
	}
}

Describe 'test-splunkd' {

	function new-credentials( $username, $password )
	{
		 New-Object System.Management.Automation.PSCredential( 
			$username, 
			( ConvertTo-SecureString -String $password -AsPlainText -Force ) 
		);
	}

	It "passes for available credentials" {
		Test-Splunkd | verify-all;
	}
	
	It "fails for unavailable server" {
		Test-Splunkd -ComputerName 'idonotexist' | verify-all $false;
	}

	It "fails for unknown user" {
		Test-Splunkd -credential (new-credentials 'unknownuser' 'secretpassword' ) | verify-all $false;
	}
	
	It "fails for invalid password" {
		Test-Splunkd -credential (new-credentials $script:fixture.splunkUser 'secretpassword')  | verify-all $false;
	}
	
	It "passes for custom splunk connection parameters" {
		Test-Splunkd -ComputerName $script:fixture.splunkServer `
			-port $script:fixture.splunkPort `
			-Credential $script:fixture.splunkAdminCredentials | 
			verify-all;
	}
}