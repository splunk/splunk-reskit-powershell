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

Describe 'set-splunkd' {

	#note: getting inconsistent behavior when adjusting ports - difficult to make the tests repeatible and automated
	
	$script:fields = @(
		'ServerName',
		'DefaultHostName',
		#'MangementPort',
		'SSOTrustedIP',
		#'WebPort',
		'SessionTimeout',
		#'IndexPath',
		'MinFreeSpace'
	)
	
	$script:testValues = @{
		'ServerName' = 'tempServerName';
		'DefaultHostName' = 'tmpHostName';
		#'MangementPort' = 9999;
		#'WebPort' = 8888;
		'SessionTimeout' = '7h';
		'MinFreeSpace' = 1500;
		'SSOTrustedIP' = '127.0.0.1';
	}
	
	
	$script:map = @{
		'ServerName' = 'ComputerName';
		'DefaultHostName' = 'DefaultHostName';
		'SessionTimeout' = 'SessionTimeout';
		'MinFreeSpace' = 'MinFreeSpace';
		'SSOTrustedIP' = 'TrustedIP';
	}
	
	$script:originalSettings = get-splunkd;
	
	$script:originalSettings | Write-Debug;
	
	function reset-data
	{
		Set-Splunkd -Force `
			-ServerName $script:originalSettings.ComputerName `
			-DefaultHostName $script:originalSettings.DefaultHostName `
			-MangementPort $script:originalSettings.MgmtPort `
			-WebPort $script:originalSettings.HTTPPort `
			-SessionTimeout $script:originalSettings.SessionTimeout `
			-MinFreeSpace $script:originalSettings.MinFreeSpace `
			-SSOTrustedIP $script:originalSettings.TrustedIP | 
		out-null;
	}
	
	if( -not $script:originalSettings )
	{
		throw 'unable to obtain current server settings';
	}

	$script:fields | foreach {
		
		It "can set $_" {
			$value = $script:testValues[$_];
			$ex = @"
write-debug 'executing set-splunked for $_';
`$results = set-splunkd -$_ $value -force;
`$key = `$script:map.'$_'
`$result = `$results."`$key"
`$setting = `$script:originalSettings."`$key"
write-debug "values: `$key; `$result ; `$setting ; $value"
( `$setting -ne `$result ) -and ( `$result.tostring() -eq "$value" );
"@;
			Write-Verbose "Evaluation expression [$ex]";
			
			try
			{
				Invoke-Expression $ex;
			}
			finally
			{
				reset-data;
			}			
		}
	}
}