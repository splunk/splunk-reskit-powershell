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

Describe "get-splunkduser" {
	
	$fields = data {
		"ComputerName"
		"DefaultApp"
		"defaultAppSourceRole"
		"Email"
		"FullName"
		"password"
		"roles"
		"Splunk_Home"
		"Type"
		"UserName"
	};
			
	It "yields results with default parameters" {
		$results = Get-SplunkdUser;
		verify-results $results $fields;	
	}
	
	It "yields results with custom credentials" {
		$results = Get-SplunkdUser -Credential $script:fixture.splunkAdminCredentials;
		verify-results $results $fields;	
	}
	
	It "yields results with custom server name" {
		$results = Get-SplunkdUser -Computer $script:fixture.splunkServer;
		verify-results $results $fields;	
	}
	
	It "yields results with custom protocol" {
		$results = Get-SplunkdUser -protocol 'https';
		verify-results $results $fields;	
	}
	
	It "yields results with custom port" {
		$results = Get-SplunkdUser -Port $script:fixture.splunkPort;
		verify-results $results $fields;	
	}
}