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

Describe 'test-splunkd' {

	function new-credentials( $username, $password )
	{
		 New-Object System.Management.Automation.PSCredential( 
			$username, 
			( ConvertTo-SecureString -String $password -AsPlainText -Force ) 
		);
	}

	It "passes for available credentials" {
		Test-Splunkd | verify-all;
	}
	
	It "fails for unavailable server" {
		Test-Splunkd -ComputerName 'idonotexist' | verify-all $false;
	}

	It "fails for unknown user" {
		Test-Splunkd -credential (new-credentials 'unknownuser' 'secretpassword' ) | verify-all $false;
	}
	
	It "fails for invalid password" {
		Test-Splunkd -credential (new-credentials $script:fixture.splunkUser 'secretpassword')  | verify-all $false;
	}
	
	It "passes for custom splunk connection parameters" {
		Test-Splunkd -ComputerName $script:fixture.splunkServer `
			-port $script:fixture.splunkPort `
			-Credential $script:fixture.splunkAdminCredentials | 
			verify-all;
	}
}