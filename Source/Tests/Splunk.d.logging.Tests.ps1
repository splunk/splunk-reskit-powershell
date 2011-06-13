param( $fixture )

Describe "get-splunkdLogging" {

	$local:fields = data {
		'ComputerName'
		'Level'
		'Name'
		'ServiceURL'
	};							

	It "fetches loggers using default parameters" {
		Get-SplunkdLogging | verify-results -fields $local:fields | verify-all;
	}
	
	It "filters loggers by name using default parameters" {
		$loggers = Get-SplunkdLogging;
		if( -not $loggers )
		{
			return $false;
		}
		
		$results = Get-SplunkdLogging -Filter $loggers[0];		
		@($results).length -eq 1 -and $results | verify-results -fields $local:fields | verify-all
	}

	It "returns an empty set when the filter matches no logger" {
		$loggers = Get-SplunkdLogging -Filter "this logger does not exist";
		-not $loggers;
	}

	It "fetches loggers using custom splunk connection parameters" {
		Get-SplunkdLogging -ComputerName $script:fixture.splunkServer `
			-port $script:fixture.splunkPort `
			-Credential $script:fixture.splunkAdminCredentials | 
			verify-results -fields $local:fields | 
			verify-all;
	}	
	
	It "filters loggers by name using custom splunk connection parameters" {
		$loggers = Get-SplunkdLogging -ComputerName $script:fixture.splunkServer `
			-port $script:fixture.splunkPort `
			-Credential $script:fixture.splunkAdminCredentials;
		if( -not $loggers )
		{
			return $false;
		}
		
		$results = Get-SplunkdLogging -Filter $loggers[0];		
		@($results).length -eq 1 -and $results | verify-results -fields $local:fields | verify-all
	}	
}

$script:levels = @("WARN" , "DEBUG" , "INFO" , "CRIT" , "ERROR" , "FATAL");
Describe "set-splunkdLogging" {

	$local:fields = data {
		'ComputerName'
		'Level'
		'Name'
		'ServiceURL'
	};		
	
	It "sets logger level by logger name using default parameters" {
		$logger = Get-SplunkdLogging | select -First 1;
		if( -not $logger )
		{
			return $false;
		}
		
		$level = $script:levels | Get-Random -Count 1;
		$results = set-SplunkdLogging -Name $logger.Name -newlevel $level;
		
		( $results.Level -eq $level ) -and ( $results | verify-results -fields $local:fields | verify-all )
	}
	
	It "sets logger level from pipeline using default parameters" {
		$logger = Get-SplunkdLogging | select -First 1;
		if( -not $logger )
		{
			return $false;
		}

		$level = $script:levels | Get-Random -Count 1;
		$results = $logger | set-SplunkdLogging -newlevel $level;
		
		$results.Level -eq $level
	}
	
	It "sets loggers that match a filter" {
		$loggers = Get-SplunkdLogging -Filter '^C';
		if( -not $loggers )
		{
			return $false;
		}
		
		$level = $script:levels | Get-Random -Count 1;
		$results = set-SplunkdLogging -Filter '^C' -NewLevel $level;		
		$results | foreach { $_.level -eq $level;  } | verify-all;
	}

	It "sets logger level by logger name using custom connection parameters" {
		$logger = Get-SplunkdLogging | select -First 1;
		if( -not $logger )
		{
			return $false;
		}
		
		$level = $script:levels | Get-Random -Count 1;
		$results = set-SplunkdLogging -Name $logger.Name `
			-newlevel $level `
			-ComputerName $script:fixture.splunkServer `
			-port $script:fixture.splunkPort `
			-Credential $script:fixture.splunkAdminCredentials ;
		
		( $results.Level -eq $level ) -and ( $results | verify-results -fields $local:fields | verify-all )
	}

	It "sets logger level from pipeline using default parameters" {
		$logger = Get-SplunkdLogging | select -First 1;
		if( -not $logger )
		{
			return $false;
		}

		$level = $script:levels | Get-Random -Count 1;
		$results = $logger | set-SplunkdLogging -newlevel $level `
			-ComputerName $script:fixture.splunkServer `
			-port $script:fixture.splunkPort `
			-Credential $script:fixture.splunkAdminCredentials;
		
		$results.Level -eq $level
	}
	
	It "sets loggers that match a filter" {
		$loggers = Get-SplunkdLogging -Filter '^C';
		if( -not $loggers )
		{
			return $false;
		}
		
		$level = $script:levels | Get-Random -Count 1;
		$results = set-SplunkdLogging -Filter '^C' -NewLevel $level `
			-ComputerName $script:fixture.splunkServer `
			-port $script:fixture.splunkPort `
			-Credential $script:fixture.splunkAdminCredentials ;		
		$results | foreach { $_.level -eq $level;  } | verify-all;
	}
}