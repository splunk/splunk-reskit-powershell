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

Describe "enable-splunkIndex" {

	It "can enable disabled index" {
		$name = (new-guid)
		$result = new-splunkIndex -Name $name
		$result = disable-splunkIndex -Name $name;				
		if( ! [bool]($result.disabled) )
		{
			throw "index is not disabled"
		}
		
		$result = enable-splunkIndex -Name $name;
		write-verbose "Result: $result"
		[bool]-not($result.disabled);
	}
return
	It "can enable enabled index" {
		$name = (new-guid)
		$result = new-splunkIndex -Name $name
				
		$result = enable-splunkIndex -Name $name;
		write-verbose "Result: $result"
		[bool]-not($result.disabled);
	}
}

Describe "disable-splunkIndex" {

	It "can disable enabled index" {
		$name = (new-guid)
		$result = new-splunkIndex -Name $name
				
		$result = disable-splunkIndex -Name $name;
		write-verbose "Result: $result"
		[bool]($result.disabled);
	}

	It "can disable disabled index" {
		$name = (new-guid)
		$result = new-splunkIndex -Name $name				
		$result = disable-splunkIndex -Name $name;
		
		$result = disable-splunkIndex -Name $name;
		write-verbose "Result: $result"
		[bool]($result.disabled);
	}
}

return;
Describe "set-splunkIndex" {

	It "can update named index" {
		$name = (new-guid)
		$result = new-splunkIndex -Name $name
		$result2 = set-splunkIndex -Name $name -maxWarmDBCount 500
		write-verbose "Result: $result; set Result: $result2"
		( ( $result2.name -eq $result.name ) -and ( $result2.maxWarmDBCount -eq 500 ) -and ( $result.maxWarmDBCount -ne 500 ) );
	}
}

Describe "new-splunkIndex" {

	It "can create named index" {
		$name = (new-guid)
		$result = new-splunkIndex -Name $name
		write-verbose "Result: $result"
		$name -eq $result.name;
	}
}


Describe "get-splunkIndex" {

	$script:fields = data {
		'blockSignSize'
		'minRawFileSyncSecs'
		'maxWarmDBCount'
		'coldToFrozenDir'
		'maxHotBuckets'
		'maxTime'
		'serviceMetaPeriod'
		'partialServiceMetaPeriod'
		'suppressBannerList'
		'quarantinePastSecs'
		'maxHotSpanSecs'
		'sync'
		'maxHotIdleSecs'
		'assureUTF8'
		'totalEventCount'
		'currentDBSizeMB'
		'syncMeta'
		'coldPath_expanded'
		'coldPath'
		'rotatePeriodInSecs'
		'thawedPath'
		'enableRealtimeSearch'
		'maxDataSize'
		'maxMetaEntries'
		'maxConcurrentOptimizes'
		'Name'
		'maxTotalDataSizeMB'
		'memPoolMB'
		'computerName'
		'maxRunningProcessGroups'
		'coldToFrozenScript'
		'compressRawdata'
		'homePath'
		'thawedPath_expanded'
		'disabled'
		'ServiceEndpoint'
		'rawChunkSizeBytes'
		'homePath_expanded'
		'frozenTimePeriodInSecs'
		'throttleCheckPeriod'
		'minTime'
		'indexThreads'
		'lastInitTime'
		'isInternal'
		'maxMemMB'
		'defaultDatabase'
		'blockSignatureDatabase'
	};

	
	It "fetches expected fields" {
		Write-Verbose "local fields: $script:fields"
		get-splunkIndex -search 'main' | select -First 1 | verify-results -fields $script:fields | verify-all;
	}
	
	It "fetches nothing for empty search" {
		$result = get-splunkIndex -search 'kuurggblafflarg6';
		
		[bool]-not($result) | verify-all;
	}

	It "fetches index by name" {
		$result = get-splunkIndex -name 'main';
		
		[bool]$result | verify-all;
	}

	It "fetches all index results for search" {
		$result = get-splunkIndex -search 'main';
		
		[bool]$result | verify-all;
	}
	
	It "raises error for nonexistent index" {
		get-splunkIndex -name 'this does not exist' -errorVariable er -errorAction 'silentlycontinue'
		[bool]$er
	}

	
	It "fetches count of indexes" {
		$result = get-splunkIndex -count 2;
		Write-Host $result.count
		2 -eq $result.count;
	}
	
	It "fetches at a specific offset" {
		$result1 = get-splunkIndex -count 2;
		$result2 = get-splunkIndex -count 2 -offset 1;
		( ( $result2[0].ServiceEndpoint -eq $result1[1].ServiceEndpoint ) -and ( $result2[1].ServiceEndpoint -ne $result1[1].ServiceEndpoint ) );
		
	}
	
	It "can sort results ascending and descending" {
		$result1 = get-splunkIndex -search 'main' -sortkey serviceendpoint -sortdirection asc;
		$result2 = get-splunkIndex -search 'main' -sortkey serviceendpoint -sortdirection desc;
		( $result2[-1].ServiceEndpoint -eq $result1[0].ServiceEndpoint )		
		$result2[-1].ServiceEndpoint, $result1[0].ServiceEndpoint | Write-Verbose;
	}
		
	It "can summarize" {
		$results = get-splunkIndex -summarize;
		[bool]$results;
	}	
}
