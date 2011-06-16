param( $fixture )

Describe "search-splunk" {
	
	It "returns results on a valid search using default connection parameters" {
		$results = search-splunk -search "s"
		
		return [bool]$results;
	}	

	It "does not raise exception when empty set is returned" {
		$e = @();
		search-splunk -search "thisshouldreturnanemptyset" -erroraction 'silentlycontinue' -errorvariable e
		$e | Write-Host;
		return -not $e;
	}	
}
