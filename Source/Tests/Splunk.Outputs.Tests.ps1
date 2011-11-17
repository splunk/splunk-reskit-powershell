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


Describe "new-SplunkOutputSyslog" {
	It "creates new forwarder config" {
		$n = new-guid;
		$result = new-splunkOutputSyslog -name $n 
		
		($result -ne $null) -and ($result.name -eq $n);
	}
}

Describe "get-SplunkOutputSyslog" {
	It "retrieves forwarder config" {
		
		$result = get-splunkOutputSyslog | select -Last 1
		$result -ne $null;
	}
}

Describe "remove-SplunkOutputSyslog" {
	It "removes existing output syslog" {
		$n = new-guid;
		$newresult = new-splunkOutputSyslog -name $n 

		remove-splunkOutputSyslog -name $n -force | Out-Null

		$getresult = get-splunkOutputSyslog -name $n -erroraction 'silentlycontinue'
		
		(($newresult -ne $null) -and (-not $getresult));
	}
}
return
Describe "set-SplunkOutputServer" {
	It "updates existing output server" {
		$n = "$(new-guid):8989";
		try
		{
			$result = new-splunkOutputServer -name $n -initialBackoff 30 -timeout 50000
			$result2 = set-splunkOutputServer -name $n -initialBackoff 35 -timeout 50000
			( $result.maxQueueSize -eq 30 ) -and ( $result2.maxQueueSize -eq 35 )
		}
		finally
		{
			remove-splunkOutputServer -name $n -force | Out-Null;
		}
	}
}
return;
Describe "get-SplunkOutputServer" {
	It "retrieves output server" {
		
		$result = get-splunkOutputServer -timeout 500000 | select -Last 1;
		$result -ne $null;
	}
}

Describe "new-SplunkOutputServer" {
	It "creates new output server" {
		$n = "$(new-guid):8989";
		$result = new-splunkOutputServer -name $n -timeout 500000
		
		($result -ne $null) -and ($result.name -eq $n);
	}
}

Describe "remove-SplunkOutputServer" {
	It "removes existing output server" {
		$n = "$(new-guid):8989";
		$newresult = new-splunkOutputserver -name $n -timeout 50000

		remove-splunkOutputServer -name $n -force | Out-Null

		$getresult = get-splunkOutputServer -name $n -erroraction 'silentlycontinue'-timeout 50000
		
		(($newresult -ne $null) -and (-not $getresult));
	}
}

Describe "set-SplunkOutputServer" {
	It "updates existing output server" {
		$n = "$(new-guid):8989";
		try
		{
			$result = new-splunkOutputServer -name $n -initialBackoff 30 -timeout 50000
			$result2 = set-splunkOutputServer -name $n -initialBackoff 35 -timeout 50000
			( $result.maxQueueSize -eq 30 ) -and ( $result2.maxQueueSize -eq 35 )
		}
		finally
		{
			remove-splunkOutputServer -name $n -force | Out-Null;
		}
	}
}
return;
Describe "enable/disable-SplunkOutputDefault" {

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

Describe "get-SplunkOutputGroup" {
	It "retrieves output groups" {
		
		$result = get-splunkOutputGroup | select -Last 1;
		$result -ne $null;
	}
}

Describe "new-SplunkOutputGroup" {
	It "creates new output groups" {
		$n = new-guid;
		$result = new-splunkOutputGroup -name $n -servers 'vbox-xp2:8989' -disabled -maxQueue 126MB;
		
		$result -ne $null;
	}
}

Describe "remove-SplunkOutputGroup" {
	It "removes existing output group" {
		$n = new-guid;
		$newresult = new-splunkOutputGroup -name $n -servers "tmp:8989"

		remove-splunkOutputGroup -name $n -force | Out-Null

		$getresult = get-splunkOutputGroup -name $n -erroraction 'silentlycontinue'
		
		(($newresult -ne $null) -and (-not $getresult));
	}
}

Describe "set-SplunkOutputGroup" {
	It "updates existing output group" {
		$n = new-guid;
		try
		{
			$result = new-splunkOutputGroup -name $n -servers 'vbox-xp2:8989' -disabled -maxQueue 126MB;
			$result2 = set-splunkOutputGroup -name $n -maxQueue 501KB -servers 'vbox-xp3:8989'
			( $result.maxQueueSize -eq '126MB' ) -and ( $result2.maxQueueSize -eq '501KB' )
		}
		finally
		{
			remove-splunkOutputGroup -name $n -force | Out-Null;
		}
	}
}

return;
Describe "new-SplunkInputWinPerfmon" {

	It "creates input" {
		$n = new-guid;
		$result = new-SplunkInputWinPerfMon -name $n -interval 30 -object 'process' -counters 'elapsed time' -instances *
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

