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

$local:fields = data {
	"Blacklist"
	"ComputerName"
	"ContinueMatching"
	"Disabled"
	"Endpoint"
	"FilterType"
	"MachineTypes"
	"Name"
	"RepositoryLocation"
	"RestartSplunkd"
	"RestartSplunkWeb"
	"StateOnClient"
	"TargetRepositoryLocation"
	"TmpFolder"
	"Whitelist"
};
			
Describe "get-splunkServerClass" {


	It "fetches the server class using default parameters" {
		Get-SplunkServerClass | verify-results -fields $local:fields | verify-all;
	}
	
	It "fetches the server class using default parameters" {
		Get-SplunkServerClass -ComputerName $script:fixture.splunkServer `
			-port $script:fixture.splunkPort `
			-Credential $script:fixture.splunkAdminCredentials |
			verify-results -fields $local:fields | 
			verify-all;
	}
	
	It "can filter server class by name" {
		$local:classes = Get-SplunkServerClass;
		
		$result = get-SplunkServerClass -filter $local:classes[0].name
		$result -and @($result).length -eq 1;
	}
	
	It "can find server class by name" {
		$local:classes = Get-SplunkServerClass;
		
		$result = get-SplunkServerClass -name $local:classes[0].name;
		$result -and @($result).length -eq 1;
	}

}

Describe "new-splunkServerClass" {

	function new-serverclassname
	{
		[System.IO.Path]::GetRandomFileName().Replace(".","");
	}
	
	function compare-serverclass( $a, $b )
	{
		Write-Debug "[compare-serverclass] $a $b";
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
	
	function new-serverlist( $c )
	{
		$i = Get-Random -Minimum 1 -Maximum 50
		
		1..$c | foreach{ "SERVER_$_" }
	}
	
	It "creates a new server class with only a name" {
		$local:name = new-serverclassname;
		
		$local:sc = New-SplunkServerClass -Name $local:name;
		$results = @( $local:sc | verify-results -fields $local:fields );
		
		$local:scc = Get-SplunkServerClass -Name $local:name;
		$results += compare-serverclass $local:sc $local:scc;
		$results | verify-all;
	}
	
	It "creates a new server class with a whitelist" {
		$local:name = new-serverclassname;
		$local:list = new-serverlist 5;
		
		$local:sc = New-SplunkServerClass -Name $local:name -Whitelist $local:list;
		$results = @( $local:sc | verify-results -fields $local:fields );
		
		$local:scc = Get-SplunkServerClass -Name $local:name;
		$results += $local:scc -and $local:scc.whitelist -and $local:scc.whitelist.length
		$results += compare-serverclass $local:sc $local:scc;
		
		$results | verify-all;
	}
	
	It "creates a new server class with a blacklist" {
		$local:name = new-serverclassname;
		$local:list = new-serverlist 5;
					
		$local:sc = New-SplunkServerClass -Name $local:name -Blacklist $local:list;
		$results = @( $local:sc | verify-results -fields $local:fields );
		
		$local:scc = Get-SplunkServerClass -Name $local:name;
		$results += $local:scc -and $local:scc.Blacklist -and $local:scc.blacklist.length
		$results += compare-serverclass $local:sc $local:scc;
		
		$results | verify-all;
	}
	
	
	It "creates a new server class with custom endpoint" {
		$local:name = new-serverclassname;
				
		$local:sc = New-SplunkServerClass -Name $local:name -endpoint 'myEndpoint';
		$local:sc | Write-Debug;
		$results = @( $local:sc -ne $null -and ( $local:sc | verify-results -fields $local:fields ) );
		
		$local:scc = Get-SplunkServerClass -Name $local:name;
		$results += $local:scc -and $local:scc.endpoint -and ($local:sc.endpoint  -eq $local:scc.endpoint );
		$results += compare-serverclass $local:sc $local:scc;
		
		$results | verify-all;
	}

	It "creates a new server class with custom filtertype" {
		$local:name = new-serverclassname;
				
		$local:sc = New-SplunkServerClass -Name $local:name -filtertype 'whitelist' -whitelist (new-serverlist 3);
		$results = @( $local:sc -ne $null -and ( $local:sc | verify-results -fields $local:fields ) );
		
		$local:scc = Get-SplunkServerClass -Name $local:name;
		$results += $local:scc -and $local:scc.filtertype -and ($local:sc.filtertype -eq $local:scc.filtertype );
		$results += compare-serverclass $local:sc $local:scc;
		
		$results | verify-all;
	}
	
	It "creates a new server class with custom tmpfolder" {
		$local:name = new-serverclassname;
				
		$local:sc = New-SplunkServerClass -Name $local:name -tmpfolder 'tmpfoldername';
		$results = @( $local:sc -ne $null -and ( $local:sc | verify-results -fields $local:fields ) );
		
		$local:scc = Get-SplunkServerClass -Name $local:name;
		$results += $local:scc -and $local:scc.tmpfolder -and ($local:sc.tmpfolder -eq $local:scc.tmpfolder );
		$results += compare-serverclass $local:sc $local:scc;
		
		$results | verify-all;
	}
	
	It "creates a new server class with custom repository location" {
		$local:name = new-serverclassname;
				
		#note: not sure 
		$local:sc = New-SplunkServerClass -Name $local:name -RepositoryLocation 'c:\data';
		$results = @( $local:sc -ne $null -and ( $local:sc | verify-results -fields $local:fields ) );
		
		$local:scc = Get-SplunkServerClass -Name $local:name;
		$results += $local:scc -and $local:scc.repositorylocation -and ($local:sc.repositorylocation -eq $local:scc.repositorylocation );
		$results += compare-serverclass $local:sc $local:scc;
		
		$results | verify-all;
	}
	
	It "creates a new server class with custom target repository location" {
		$local:name = new-serverclassname;
				
		#note: not sure 
		$local:sc = New-SplunkServerClass -Name $local:name -TargetRepositoryLocation '$SPLUNK_HOME/etc/myTargetRepoLocation';
		$results = @( $local:sc -ne $null -and ( $local:sc | verify-results -fields $local:fields ) );
		
		$local:scc = Get-SplunkServerClass -Name $local:name;
		$results += $local:scc -and $local:scc.targetrepositorylocation -and ($local:sc.targetrepositorylocation -eq $local:scc.targetrepositorylocation );
		$results += compare-serverclass $local:sc $local:scc;
		
		$results | verify-all;
	}
}
