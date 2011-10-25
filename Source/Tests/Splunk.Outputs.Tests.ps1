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

Describe "enabledisable-SplunkOutputDefault" {

	It "toggles output default settings disabled property" {
		try
		{
			enable-SplunkOutputDefault
			
			$result = get-SplunkOutputDefault 
			$wasDisabled = $result.disabled;
			disable-SplunkOutputDefault;
			$result = get-SplunkOutputDefault 
			$isDisabled = $result.disabled;
			
			$isDisabled -and -not -$wasDisabled
		}
		finally
		{
			enable-SplunkOutputDefault
		}
	}

}

Describe "get-SplunkOutputDefault" {

	It "retrieves output default settings" {
		$result = get-SplunkOutputDefault
		$result -ne $null;
	}
}
Describe "set-SplunkOutputDefault" {


	It "sets output default settings" {
		$r = Get-Random -Maximum 500 -Minimum 100
		$result = set-SplunkOutputDefault -maxqueuesize "${r}MB"
		$result.maxQueueSize -eq "${r}MB"
	}
}


return;
Describe "new-SplunkInputWinPerfmon" {

	It "creates input" {
		$name = new-guid;
		$result = new-SplunkInputWinPerfMon -name $name -interval 30 -object 'process' -counters 'elapsed time' -instances *
		Write-Verbose "Result: $result"
		[bool]$result | verify-all;
	}
}

Describe "get-SplunkInputRegistry" {

	It "fetches nothing for empty search" {
		$result = get-SplunkInputRegistry -search 'kuurggblafflarg6';
		
		[bool]-not($result) | verify-all;
	}

	It "fetches input by name" {
		$result = get-SplunkInputRegistry -name 'User keys';
		
		[bool]$result | verify-all;
	}

	It "fetches all inputs" {
		$result = get-SplunkInputRegistry ;
		
		[bool]$result | verify-all;
	}
}

Describe "get-SplunkInputMonitor" {

	It "fetches nothing for empty search" {
		$result = get-SplunkInputMonitor -search 'kuurggblafflarg6';
		
		[bool]-not($result) | verify-all;
	}

	It "fetches input by filter" {
		$result = get-SplunkInputMonitor -filter '\$SPLUNK_HOME\\etc\\splunk\.version';
		
		[bool]$result | verify-all;
	}

	It "fetches all inputs" {
		$result = get-SplunkInputMonitor ;
		
		[bool]$result | verify-all;
	}

	It "raises error for nonexistent input" {
		get-SplunkInputMonitor -name 'this does not exist' -errorVariable er -errorAction 'silentlycontinue'
		[bool]$er
	}

	
	It "fetches count of inputs" {
		$result = get-SplunkInputMonitor -count 2;
		2 -eq $result.count;
	}
	
	It "fetches at a specific offset" {
		$result1 = get-SplunkInputMonitor -count 2;
		$result2 = get-SplunkInputMonitor -count 2 -offset 1;
		( ( $result2[0].ServiceEndpoint -eq $result1[1].ServiceEndpoint ) -and ( $result2[1].ServiceEndpoint -ne $result1[1].ServiceEndpoint ) );
		
	}
	
	It "can sort results ascending and descending" {
		$result1 = get-SplunkInputMonitor -sortkey serviceendpoint -sortdirection asc;
		$result2 = get-SplunkInputMonitor -sortkey serviceendpoint -sortdirection desc;
		( $result2[-1].ServiceEndpoint -eq $result1[0].ServiceEndpoint )		
		$result2[-1].ServiceEndpoint, $result1[0].ServiceEndpoint | Write-Verbose;
	}
}

