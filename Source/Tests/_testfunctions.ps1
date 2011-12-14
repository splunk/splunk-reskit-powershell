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

function global:new-guid()
{
	return [Guid]::NewGuid().ToString('N');
}

function global:reset-connection( $fixture )
{
	Write-Debug 'creating default splunk object using connect-splunk';
	Disable-CertificateValidation;
	Connect-Splunk -ComputerName $fixture.splunkServer -Credential $fixture.splunkAdminCredentials;
}

function global:reset-moduleState( $fixture )
{
	if( get-module Splunk )
	{
		Write-Debug "removing Splunk module"
		Remove-Module Splunk
	}
	
	Import-Module ../Splunk;
	reset-connection $fixture;
}

function global:verify-all( $value = $true )
{
	begin
	{
		$local:a = @();
	}
	process
	{
		$local:a += $input;
	}	
	end
	{
		if( $value -and -not $local:a )
		{
			return $false;
		}
		
		foreach( $aa in $local:a )
		{
			if( $aa -ne $value )
			{
				return $false;
			}
		}
		return $true;
	}
}

function global:verify-results
{
	[CmdletBinding()]
	param(
		[Parameter(ValueFromPipeline=$true)] $results, 
		[Parameter()]
		[String[]] $fields
	);
	
	process
	{
		if( -not $results )
		{
			Write-Debug 'no results to process';
			return $false;
		}
		
		Write-Verbose "expected fields: $fields"
		
		$local:resultFields = $results | Get-Member -membertype properties | foreach{ $_.name };
		
		Write-Verbose "actual fields: $local:resultFields"
		
		$missing = $fields | where{ $local:resultFields -notcontains $_ };
		if( $missing )
		{
			Write-Verbose "Missing Fields: $missing";
			return $false;
		}
		
		return $true;
	}
}

function global:compare-objectProperties( $a, $b )
{
	if( -not( $a -and $b ) )
	{
		return $false;
	}
	
	$local:scNames = $a | get-member -membertype Properties | foreach{ $_.Name };
	$local:scNames | Write-Debug;
	
	$b | Get-Member -MemberType Properties | foreach {
		$local:key = $_.name;
		Write-Debug "processing $($_.name)";
		$local:result = $local:scNames -contains $local:key; 
		if( -not $local:result )
		{
			Write-Debug "$local:key is not in list of property names";
			$false;
		}
		else
		{
			write-debug ($b."$local:key" -eq $a."$local:key")
			$b."$local:key" -eq $a."$local:key";
		}
	};
}