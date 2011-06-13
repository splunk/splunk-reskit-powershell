param( $fixture )

function remove-TempFile( $configPath )
{
	Write-Debug "checking for presence of $configPath";
	if( Test-Path $configPath )
	{
		Remove-Item $configPath;
	}
}
	

Describe 'export-splunkmoduleconfiguration' {

	It 'outputs config file to the specified path' {
		$configPath = [System.IO.Path]::GetRandomFileName();
		try
		{
			remove-tempfile $configPath;
			export-splunkmoduleconfiguration $configPath;
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
			export-splunkmoduleconfiguration;
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
			export-splunkModuleConfiguration 'c:<thispathisinvalid|>!^&';
		}
		catch
		{
			( $_ | new-testresult ).should.match('illegal characters in path');
		}
	}
	
	It 'raises exception when supplied nonexistent path' {
		try
		{
			export-splunkModuleConfiguration './doesnotexist/config.xml';
		}
		catch
		{
			( $_ | new-testresult ).should.match('could not find a part of the path');
		}
	}
}

Describe "import-splunkmoduleconfiguration" {

	Write-Debug 'creating default splunk object using connect-splunk';
	Disable-CertificateValidation;
	$global:SplunkDefaultObject = Connect-Splunk -ComputerName $script:fixture.splunkServer -Credentials $script:fixture.splunkAdminCredentials;

	It 'loads a valid configuration file' {
		
		Write-Debug 'exporting splunk config to default location';
		export-SplunkModuleConfiguration;
		
		if( -not( Test-Path $script:fixture.defaultConfigPath ) )
		{
			return $false;
		}
		
		$result = import-splunkModuleConfiguration;		
		$properties = $result | Get-Member -MemberType Properties | select name;
		$results = ( $properties | foreach{ $result."$_" -eq $global:SplunkDefaultObject."$_" } );
		
		$results -notcontains $false;
	}
	
	It 'loads a valid configuration file from a specified path' {
		
		$local:configPath = [System.IO.Path]::GetRandomFileName();
		try
		{
			Write-Debug 'exporting splunk config to default location';
			export-SplunkModuleConfiguration $local:configPath;
			
			if( -not( Test-Path $local:configPath ) )
			{
				return $false;
			}
			
			$result = import-splunkModuleConfiguration $local:configPath;		
			$properties = $result | Get-Member -MemberType Properties | select name;
			$results = ( $properties | foreach{ $result."$_" -eq $global:SplunkDefaultObject."$_" } );
			
			$results -notcontains $false;
		}
		finally
		{
			remove-tempfile $local:configPath;
		}

	}
}