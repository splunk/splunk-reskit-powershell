param( $fixture )

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