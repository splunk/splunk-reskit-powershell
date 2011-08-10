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

[cmdletbinding(SupportsShouldProcess=$true)]
param()

process
{
$c = New-Object system.Net.WebClient
$credentials = Get-Credential;

$url = New-Object system.Collections.Stack
$url.push('https://vbox-xp:8089/services');
$done = @();

while( $url.Peek() )
{
	$u = $url.Pop();
	if( $done -contains $u )
	{
		continue;
	}

	$done += $u;
	
	if( -not( $pscmdlet.shouldprocess( $u ) ) )
	{
		continue;
	}
	
	Write-Host "fetching $u...";

	$c.Credentials = $credentials
	[xml]$d = $c.DownloadString( $u );
	
	$n = $d.feed.title;
	$d.save( "$pwd\$n.atom" )
	$d.feed.entry | select id | %{ $url.push($_.id) }	
}
}