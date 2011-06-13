param( $fixture )

Describe "set-splunkdpassword" {
	
	$script:currentPassword = '';
	
	function reset-password
	{
		try
		{
			Write-Debug 'resetting password back to original value';
			
			Set-SplunkdPassword -force -Credential (new-credentials) -UserName $script:fixture.splunkUser -newpassword $script:fixture.splunkPassword | Out-Null;
			Write-Debug 'reset user password to original value';
		}
		catch
		{
			Write-Error $_;
		}
	}
	
	function new-credentials()
	{
		 New-Object System.Management.Automation.PSCredential( 
			$script:fixture.splunkUser, 
			( ConvertTo-SecureString -String $script:currentPassword -AsPlainText -Force ) 
		);
	}
	
	function verify-CanConnect()
	{
		$local:cred = new-credentials;

		$r = Connect-Splunk -ComputerName $script:fixture.splunkServer -Credentials $local:cred -passthru 		
		$r -and $r.authToken;
	}
	
	It "changes password with default connection" {
		$script:currentPassword = [Guid]::NewGuid().ToString('N');
		
		Write-Debug "new password: $script:currentPassword";
		
		try
		{
			Set-SplunkdPassword -force -UserName $script:fixture.splunkUser -NewPassword $script:currentPassword | Out-Null
			verify-canConnect;
		}
		finally
		{
			reset-password
		}
	}
		
}