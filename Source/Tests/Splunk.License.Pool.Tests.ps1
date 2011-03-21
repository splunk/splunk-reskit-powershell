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

Describe "add-splunkLicensePool" {

	function remove-testLicensePool( $name )
	{
		if( -not ( get-splunklicensepool $name ) )
		{
			Write-Verbose "no need to remove $name license pool because it does not exist"
			return;
		}
		
		remove-SplunkLicensePool -name $name;
	}
	
	It "adds new license pool with no quota or slaves" {
		$name = [Guid]::NewGuid().ToString('N')
		try
		{
			$pre = get-splunklicensepool $name;
			
			add-splunkLicensePool -name $name -description "just a test license pool" -quota 0mb -stack 'enterprise' | Out-Null
			
			$post = get-splunklicensepool -name $name;
			
			-not $pre -and $post;
		}
		finally
		{
			remove-splunkLicensePool -name $name
		}
	}	
	
	It "adds new license pool with no quota and one slave" {
		$name = [Guid]::NewGuid().ToString('N')
		try
		{
			$pre = get-splunklicensepool $name;
			$slave = get-splunkLicenseSlave | select -First 1;
			add-splunkLicensePool -name $name -description "just a test license pool" -quota 0mb -stack 'enterprise' -slave $slave.Label | Out-Null
			
			$post = get-splunklicensepool -name $name;
			
			-not $pre -and $post;
		}
		finally
		{
			remove-splunkLicensePool -name $name
		}
	}	
}

Describe "remove-splunkLicensePool" {

	It "removes an existing license pool by name" {
		$name = [Guid]::NewGuid().ToString('N')
				
		add-splunkLicensePool -name $name -description "just a test license pool" -quota 0mb -stack 'enterprise'| Out-Null
		$pre = get-splunklicensepool -name $name;
		
		remove-splunkLicensePool -name $name;
		
		$post = get-splunklicensepool -name $name;
		
		$pre -and -not $post;
	}	
}
