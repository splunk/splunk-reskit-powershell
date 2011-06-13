param( $fixture )

Describe "write-splunkmessage" {

	It "writes a message using default parameters" {
		$local:message = [Guid]::NewGuid().ToString();
		$result = Write-SplunkMessage -Message $local:message;
		
		$result.Index -and $result.Host -and $result.Source -and $result.SourceType;
	}
	
	It "writes a message using custom index" {
		$local:message = [Guid]::NewGuid().ToString();
		$result = Write-SplunkMessage -Index 'CustomIndex' -Message $local:message;
		
		$result.Index -and $result.Host -and $result.Source -and $result.SourceType;
	}
	
	It "writes a message using custom host" {
		$local:message = [Guid]::NewGuid().ToString();
		$result = Write-SplunkMessage -Message $local:message -Source "CustomHost";
		
		$result.Index -and $result.Host -and $result.Source -and $result.SourceType;
	}
	
	
	It "writes a message using custom source" {
		$local:message = [Guid]::NewGuid().ToString();
		$result = Write-SplunkMessage -Message $local:message -Source "splunk_unit_tests_source";
		
		$result.Index -and $result.Host -and $result.Source -and $result.SourceType;
	}
	
	It "writes a message using custom source type" {
		$local:message = [Guid]::NewGuid().ToString();
		$result = Write-SplunkMessage -Message $local:message -Source "splunk_unit_tests_source_type";
		
		$result.Index -and $result.Host -and $result.Source -and $result.SourceType;
	}
	
	It "writes a message using custom splunk connection parameters" {
		$local:message = [Guid]::NewGuid().ToString();
		
		$result = Write-SplunkMessage -Message $local:message `
			-ComputerName $script:fixture.splunkServer `
			-port $script:fixture.splunkPort `
			-Credential $script:fixture.splunkAdminCredentials;
		
		$result.Index -and $result.Host -and $result.Source -and $result.SourceType;
	}
	
}