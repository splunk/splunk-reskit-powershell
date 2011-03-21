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

function remove-TempFile( $configPath )
{
	Write-Debug "checking for presence of $configPath";
	if( Test-Path $configPath )
	{
		Remove-Item $configPath | Out-Null;
	}
}
	

Describe 'Export-SplunkConnectionObject' {

	It 'outputs config file to the specified path' {
		$configPath = [System.IO.Path]::GetRandomFileName();
		try
		{
			remove-tempfile $configPath;
			Export-SplunkConnectionObject $configPath | out-null;
			Test-Path $configPath;
		}
		finally
		{
			remove-tempfile $configPath;
		}
	}
	
 	It 'outputs config file to default path' {
		try
		{
			remove-tempfile $script:fixture.defaultConfigPath;
			Export-SplunkConnectionObject | Out-Null;
			Test-Path $script:fixture.defaultConfigPath;
		}
		finally
		{
			remove-tempfile $script:fixture.defaultConfigPath;
		}
	}
	
	It 'raises exception when supplied invalid path string' {
		try
		{
			Export-SplunkConnectionObject 'c:<thispathisinvalid|>!^&';
		}
		catch
		{
			( $_ | new-testresult ).should.match('illegal characters in path');
		}
	}
	
	It 'raises exception when supplied nonexistent path' {
		try
		{
			Export-SplunkConnectionObject './doesnotexist/config.xml';
		}
		catch
		{
			( $_ | new-testresult ).should.match('could not find a part of the path');
		}
	}
}

Describe "Import-SplunkConnectionObject" {

	Write-Debug 'creating default splunk object using connect-splunk';
	Disable-CertificateValidation;
	$script:currentConnection = Connect-Splunk -ComputerName $script:fixture.splunkServer -Credentials $script:fixture.splunkAdminCredentials;

	It 'loads a valid configuration file from default location' {
		
		Write-Debug 'exporting splunk config to default location';
		Export-SplunkConnectionObject | Out-Null;
		
		if( -not( Test-Path $script:fixture.defaultConfigPath ) )
		{
			return $false;
		}
		
		reset-moduleState $script:fixture;
		Import-SplunkConnectionObject;
		$result = get-splunkconnectionobject;
		
		$properties = $result | Get-Member -MemberType Properties | select name;
		$results = ( $properties | foreach{ $result."$_" -eq $script:currentConnection."$_" } );
		
		$results -notcontains $false;
	}
	
	It 'loads a valid configuration file from a specified path' {
		
		$local:configPath = [System.IO.Path]::GetRandomFileName();
		try
		{
			Write-Debug 'exporting splunk config to default location';
			Export-SplunkConnectionObject $local:configPath | Out-Null;
			
			if( -not( Test-Path $local:configPath ) )
			{
				return $false;
			}
			
			reset-moduleState $script:fixture;
			Import-SplunkConnectionObject $local:configPath;		
			$result = get-splunkconnectionobject;
			
			$properties = $result | Get-Member -MemberType Properties | select name;
			$results = ( $properties | foreach{ $result."$_" -eq $script:currentConnection."$_" } );
			
			$results -notcontains $false;
		}
		finally
		{
			remove-tempfile $local:configPath | Out-Null;
		}

	}	
}