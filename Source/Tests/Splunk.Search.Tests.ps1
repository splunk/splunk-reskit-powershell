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
