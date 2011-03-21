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

[CmdletBinding()]
param( 
	[Parameter(ValueFromPipeline=$true)] 
	[string]
	# the path to a test fixture data file; defaults to ./splunk.fixture.ps1
	$fixtureFilePath = './splunk.fixture.ps1',
	
	[Parameter()] 
	[string]
	# the pattern of fixtures to run
	$filter = "*.Tests.*"
	
)

Import-Module Pester;
Import-Module ../Splunk;

try
{
	$local:root = $MyInvocation.myCommand.Path | Split-Path;
	. "$local:root/_testfunctions.ps1";

	if( Test-Path $fixtureFilePath )
	{
		$script:fixture = & $fixtureFilePath;
	}

	reset-connection $script:fixture;
	Invoke-Pester -fixture $script:fixture -filepattern $filter 
}
finally
{
	remove-Module Pester;
	remove-Module Splunk;
}