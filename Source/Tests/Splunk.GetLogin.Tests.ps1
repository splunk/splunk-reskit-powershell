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


Describe "get-splunkLogin" {

	$local:fields = data {
		"AuthToken"
		"ComputerName"
		"TimeAccessed"
		"UserName"
	};							

	It "fetches logins using default parameters" {
		Get-SplunkLogin | verify-results -fields $local:fields | verify-all;
	}
	
	It "fetches specific login by name using default parameters" {
		$results = Get-SplunkLogin -Name $script:fixture.splunkUser;
		
		@($results).length -eq 1 -and ( $results | verify-results -fields $local:fields | verify-all )
	}
	
	It "fetches logins using custom splunk connection parameters" {
		Get-SplunkLogin -ComputerName $script:fixture.splunkServer `
			-port $script:fixture.splunkPort `
			-Credential $script:fixture.splunkAdminCredentials | 
			verify-results -fields $local:fields | 
			verify-all;
	}
	
	It "fetches specific login using custom splunk connection parameters" {
		Get-SplunkLogin -name $script:fixture.splunkUser `
			-ComputerName $script:fixture.splunkServer `
			-port $script:fixture.splunkPort `
			-Credential $script:fixture.splunkAdminCredentials | 
			verify-results -fields $local:fields | 
			verify-all;
	}
}