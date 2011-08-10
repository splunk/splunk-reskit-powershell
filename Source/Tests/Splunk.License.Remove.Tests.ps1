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

Describe "add-splunkLicenseFile" {


	$trialLicenseLabel = 'For Testing'

	It "adds license from file" {
		$pre = get-splunkLicenseFile -all | where{ $_.label -eq $trialLicenseLabel }

		if( $pre )
		{
			try
			{
				Write-Debug 'removing trial license file to test add-splunklicensefile'
				$pre.Hash | Remove-SplunkLicenseFile | out-null;
			}
			catch
			{
			}
		}
		
		$pre = get-splunkLicenseFile -all | where{ $_.label -eq $trialLicenseLabel }
		
		add-SplunkLicenseFile -Name $trialLicenseLabel -path $script:fixture.licenseFilePath | out-null;				
		
		$post = get-splunkLicenseFile -all | where{ $_.label -eq $trialLicenseLabel }
		
		$post -and -not $pre		
	}	
}

Describe "remove-splunkLicenseFile" {

	$trialLicenseLabel = 'For Testing'
		
	function reset-TrialLicense
	{
		if( get-splunkLicenseFile -all | where{ $_.label -eq $trialLicenseLabel } )
		{
			return;
		}

		Write-Debug 'Resetting trial license file because it does not exist'
		add-SplunkLicenseFile -Name $trialLicenseLabel -path $script:fixture.licenseFilePath | Out-Null;				
	}

	It "removes enterprise trial license" {
		try
		{
			reset-TrialLicense;
			
			$pre = get-splunkLicenseFile -all | where{ $_.label -eq $trialLicenseLabel }
			
			$pre.Hash | Remove-SplunkLicenseFile -force;
			
			$post = get-splunkLicenseFile -all | where{ $_.label -eq $trialLicenseLabel }
			
			$pre -and -not $post
		}
		finally
		{
			reset-TrialLicense;
		}
	}	
}

