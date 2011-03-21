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

Describe "get-splunkdVersion" {

	$local:fields = data {
		'Build'
		'ComputerName'
		'CPU_Arch'
		'GUID'
		'IsFree'
		'IsTrial'
		'Mode'
		'OSBuild'
		'OSName'
		'OSVersion'
		'Version'
	};							

	It "fetches logins using default parameters" {
		Get-SplunkDVersion | verify-results -fields $local:fields | verify-all;
	}
	
	It "fetches logins using custom splunk connection parameters" {
		Get-SplunkDVersion -ComputerName $script:fixture.splunkServer `
			-port $script:fixture.splunkPort `
			-Credential $script:fixture.splunkAdminCredentials | 
			verify-results -fields $local:fields | 
			verify-all;
	}	
}