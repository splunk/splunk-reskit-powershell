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


Describe "new-SplunkApplication" {

	It "can create named application" {
		$name = (new-guid)
		$result = new-SplunkApplication -Name $name -Timeout 30000
		write-verbose "Result: $result"
		$name -eq $result.name;
	}
}
Describe "remove-SplunkApplication" {

	It "can remove named application" {
		$name = (new-guid)
		$result = new-SplunkApplication -Name $name -Timeout 30000
		write-verbose "Result: $result"
		
		remove-SplunkApplication -Name $name -Force;
		[bool]-not(get-splunkApplication -filter $Name) | verify-all;
	}
}

Describe "set-SplunkApplication" {

	It "can update named application" {
		$name = (new-guid)
		$result = new-SplunkApplication -Name $name -timeout 30000
		$result2 = set-SplunkApplication -Name $name -description 'desc123'
		write-verbose "Result: $result; set Result: $result2"
		( ( $result2.name -eq $result.name ) -and ( $result2.description -eq 'desc123' ) -and ( $result.description -ne 'desc123' ) );
	}
}


Describe "get-SplunkApplication" {

	$script:fields = data {
		"author"
		"check_for_updates"
		"configured"
		"description"
		"disabled"
		"label"
		"manageable"
		"Name"
		"state_change_requires_restart"
		"version"
		"visible"
	};

	
	It "fetches expected fields" {
		Write-Verbose "local fields: $script:fields"
		get-SplunkApplication -search 'gettingstarted' | select -First 1 | verify-results -fields $script:fields | verify-all;
	}
	
	It "fetches nothing for empty search" {
		$result = get-SplunkApplication -search 'kuurggblafflarg6';
		
		[bool]-not($result) | verify-all;
	}

	It "fetches application by name" {
		$result = get-SplunkApplication -name 'gettingstarted';
		
		[bool]$result | verify-all;
	}

	It "fetches all applications for search" {
		$result = get-SplunkApplication -search 'gettingstarted';
		
		[bool]$result | verify-all;
	}
	
	It "raises error for nonexistent application" {
		get-SplunkApplication -name 'this does not exist' -errorVariable er -errorAction 'silentlycontinue'
		[bool]$er
	}

	
	It "fetches count of applications" {
		$result = get-SplunkApplication -count 2;
		2 -eq $result.count;
	}
	
	It "fetches at a specific offset" {
		$result1 = get-SplunkApplication -count 2;
		$result2 = get-SplunkApplication -count 2 -offset 1;
		( ( $result2[0].ServiceEndpoint -eq $result1[1].ServiceEndpoint ) -and ( $result2[1].ServiceEndpoint -ne $result1[1].ServiceEndpoint ) );
		
	}
	
	It "can sort results ascending and descending" {
		$result1 = get-SplunkApplication -sortkey serviceendpoint -sortdirection asc;
		$result2 = get-SplunkApplication -sortkey serviceendpoint -sortdirection desc;
		( $result2[-1].ServiceEndpoint -eq $result1[0].ServiceEndpoint )		
		$result2[-1].ServiceEndpoint, $result1[0].ServiceEndpoint | Write-Verbose;
	}
}

