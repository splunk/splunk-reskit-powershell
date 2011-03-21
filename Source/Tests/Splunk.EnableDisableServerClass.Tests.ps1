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

Describe "enable-splunkServerClass" {

	function get-disabledServerClass
	{
		$local:sc = Get-SplunkServerClass | where {$_.disabled};
		if( -not $local:sc )
		{
			$local:sc = Get-SplunkServerClass;
		}
		
		$local:sc = @($local:sc)[ @($local:sc).length - 1 ];
		
		if( -not $local:sc.disabled )
		{
			$local:sc = $local:sc | Disable-SplunkServerClass;
		}
		$local:sc;
	}
	
	It "accepts server class object as pipeline input" {
		$local:sc = get-disabledServerClass;	
		$local:sc = $local:sc | enable-SplunkServerClass;
		return -not $local:sc.disabled;
	}
	
	It "accepts server class object by name" {
		$local:sc = get-disabledServerClass;	
		$local:sc = enable-SplunkServerClass -Name $local:sc.Name;
		return -not $local:sc.disabled;
	}
	
	It "accepts filter of server class object" {
		$local:sc = get-disabledServerClass;	
		$local:sc = enable-SplunkServerClass -Filter $local:sc.Name
		return -not $local:sc.disabled;
	}

}

Describe "disable-splunkServerClass" {

	function get-enabledServerClass
	{
		$local:sc = Get-SplunkServerClass | where { -not $_.disabled };
		if( -not $local:sc )
		{
			$local:sc = Get-SplunkServerClass;
		}
		
		$local:sc = @($local:sc)[ @($local:sc).length - 1 ];
		
		if( $local:sc.disabled )
		{
			$local:sc = $local:sc | enable-SplunkServerClass;
		}
		$local:sc;
	}
	
	It "accepts server class object as pipeline input" {
		$local:sc = get-enabledServerClass;	
		$local:sc = $local:sc | disable-SplunkServerClass;
		return $local:sc.disabled;
	}
	
	It "accepts server class object by name" {
		$local:sc = get-enabledServerClass;	
		$local:sc = disable-SplunkServerClass -Name $local:sc.Name;
		return $local:sc.disabled;
	}
	
	It "accepts filter of server class object" {
		$local:sc = get-enabledServerClass;	
		$local:sc = disable-SplunkServerClass -Filter $local:sc.Name
		return $local:sc.disabled;
	}

}