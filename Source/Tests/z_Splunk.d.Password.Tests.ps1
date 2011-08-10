# Copyright 2011 Splunk, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License"): you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

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