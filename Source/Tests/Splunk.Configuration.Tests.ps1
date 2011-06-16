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