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

$epochZero = New-Object DateTime( 1970, 1, 1, 0, 0, 0, 0 );

function Get-DateTimeWithZeroMilliseconds( $now = (Get-Date) )
{
	New-Object DateTime( $now.Year, $now.Month, $now.Day, $now.hour, $now.minute, $now.second, 0 );
}

Describe "convertfrom-unixtime" {
	
	It "converts 0 as jan 1 1970" {
		$result = convertfrom-unixtime 0 | new-testresult;
		$result.should.be( $epochZero );
	}
	
	It "converts unixtime now to datetime now" {
		$now = get-dateTimeWithZeroMilliseconds;
		$unixtime =  ($now - $epochZero).TotalSeconds;
		
		$result = convertfrom-unixtime $unixtime | new-testresult;
		$result.should.be( $now );
	}
}

Describe "convertfrom-splunktime" {

	function test-splunktimeconversion( $f )
	{
		$now = Get-DateTimeWithZeroMilliseconds;
		
		$result = convertfrom-splunktime ($now.toString($f) ) | new-testresult; 
		$result.should.be($now);
	}

	It "converts ddd MMM dd HH:mm:ss yyyy format" {
		test-splunktimeconversion 'ddd MMM dd HH:mm:ss yyyy';		
	}
	
	It "converts ddd MMM  d HH:mm:ss yyyy format" {
		test-splunkTimeConversion 'ddd MMM  d HH:mm:ss yyyy';
	}

	It "returns null on invalid datetime format" {
		$result = convertfrom-splunktime "asdf" | new-testresult;
		$result.should.be($null);
	}	
}

Describe "get-splunk" {

	function verify-commands( $moduleCommands, $splunkCommands )
	{
		$splunkCommands = ( $splunkCommands | select name ).Values;
		$results = $moduleCommands | foreach{ $splunkCommands -contains $_.Name } 
		$results -notcontains $false;
	}
	
	It "returns all public splunk module commands" {
		$local:moduleCommands = Get-Command -Module splunk | %{ $_.name };
		$local:splunkCommands = Get-Splunk | %{ $_.name };
		
		verify-commands -module $local:moduleCommands -splunk $local:splunkCommands;
	}
	
	
	It "returns list of commands filtered by verb" {
		$local:moduleCommands = Get-Command -Module splunk -Verb get | %{ $_.name };
		$local:splunkCommands = Get-Splunk -Verb get | %{ $_.name };
		
		verify-commands -module $local:moduleCommands -splunk $local:splunkCommands;
	}
	
	
	It "returns list of commands filtered by noun" {
		$local:moduleCommands = Get-Command -Module splunk -Noun splunkd | %{ $_.name };
		$local:splunkCommands = Get-Splunk -Noun splunkd | %{ $_.name };
		
		verify-commands -module $local:moduleCommands -splunk $local:splunkCommands;
	}
	
	It "returns list of commands filtered by noun and verb" {
		$local:moduleCommands = Get-Command -Module splunk -Verb get -Noun splunkd | %{ $_.name };
		$local:splunkCommands = Get-Splunk -Verb get -Noun splunkd | %{ $_.name };
		
		verify-commands -module $local:moduleCommands -splunk $local:splunkCommands;
	}
	
	It "returns nothing when filtered with unused verb" {
		$result = Get-Command -Module splunk -Verb kenooter | new-testresult;
		$result.should.be($null);
	}
	
	It "returns nothing when filtered with unused noun" {
		$result = Get-Command -Module splunk -noun kenooter | new-testresult;
		$result.should.be($null);
	}
}