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

$local:fixture = @{
	# the name or IP of the splunk server
	splunkServer = 'talon-xp';
	
	# the splunk user name
	splunkUser = 'admin';
	
	# the splunk password
	splunkPassword = 'password';
	
	# splunk management port
	splunkPort = 8089;
	
	# path to test license file
	licenseFilePath = "C:\Users\beefarino\Documents\Project\splunk-reskit-powershell\_local\Splunk.license";
	
	# path to tar.gz app bundle
	appTarPath = "C:\Temp\maps.tar.gz";

	#------- you do not need to edit below this line ----------
	
	defaultConfigPath = get-module splunk | split-path | join-path -ChildPath "SplunkConnectionObject.xml";
};

$local:fixture.splunkAdminCredentials = New-Object System.Management.Automation.PSCredential( 
	$local:fixture.splunkUser, 
	( ConvertTo-SecureString -String $local:fixture.splunkPassword -AsPlainText -Force ) 
);

$local:fixture;
Write-Debug 'import of splunk.fixture.ps1 complete';