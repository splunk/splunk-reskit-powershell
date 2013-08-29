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

#region Search

#region Search-Splunk

function Search-Splunk
{

	<# .ExternalHelp ../Splunk-Help.xml #>
	
	[Cmdletbinding(SupportsShouldProcess=$true)]
    Param(
	
		[Parameter(Mandatory=$True)]
		[STRING]$Search,
	
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]$ComputerName = ( get-splunkconnectionobject ).ComputerName,
        
        [Parameter()]
        [int]$Port            = ( get-splunkconnectionobject ).Port,
        
        [Parameter()]
		[ValidateSet("http", "https")]
        [STRING]$Protocol     = ( get-splunkconnectionobject ).Protocol,
        
        [Parameter()]
        [int]$Timeout         = ( get-splunkconnectionobject ).Timeout,

        [Parameter()]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()] $Credential = ( get-splunkconnectionobject ).Credential,
		
		[Parameter()]           # earliest_time
        [String]$StartTime,
        
        [Parameter()]           # latest_time
        [String]$EndTime,
        
        [Parameter()]           # auto_finalize_ec = int
        [int]$MaxReturnCount,
        
        [Parameter()]           # max_time = int
        [int]$MaxTime,
		
		[Parameter()]
		[STRING[]]$RequiredFields
        
    )
	
	Begin
	{
		function ConvertFrom-SplunkSearchResultTime
		{
			[cmdletbinding()]
			Param($ResultTime)
			$Format = "yyyy-MM-ddTHH:mm:ss"
			try
			{
				[DateTime]::ParseExact($ResultTime.Split(".")[0],$Format,$null)
			}
			catch
			{
				Write-Verbose " [ConvertFrom-SplunkSearchResultTime] :: Unable to convert date."
				$ResultTime
			}
		}
		Write-Verbose " [Search-Splunk] :: Starting..."
		
		Write-Verbose " [Search-Splunk] :: Building Search Arguments"
		$SearchParams = @{}
		$SearchParams.Add("search","search $Search")
		$SearchParams.Add("exec_mode","oneshot")
		switch -exact ($PSBoundParameters.Keys)
		{
			"StartTime"			{ $SearchParams.Add('earliest_time',$StartTime) 		; continue }
			"EndTime"			{ $SearchParams.Add('latest_time',$EndTime)     		    ; continue }
			"MaxReturnCount"	{ 
									$SearchParams.Add('auto_finalize_ec',$MaxReturnCount)
									$SearchParams.Add('count',$MaxReturnCount)
									continue
								}
			"MaxTime"			{ $SearchParams.Add('max_time',$WebPort)              		; continue }
			"RequiredFields"	{ $SearchParams.Add('required_field_list',$RequiredFields)	; continue }
		}
	}
	Process
	{
		Write-Verbose " [Search-Splunk] :: Parameters"
		Write-Verbose " [Search-Splunk] ::  - ComputerName = $ComputerName"
		Write-Verbose " [Search-Splunk] ::  - Port         = $Port"
		Write-Verbose " [Search-Splunk] ::  - Protocol     = $Protocol"
		Write-Verbose " [Search-Splunk] ::  - Timeout      = $Timeout"
		Write-Verbose " [Search-Splunk] ::  - Credential   = $Credential"

		if( -not $pscmdlet.ShouldProcess( $ComputerName, "Executing search for '$Search'" ) )
		{
			return;
		}

		Write-Verbose " [Search-Splunk] :: Setting up Invoke-APIRequest parameters"
		$InvokeAPIParams = @{
			ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
			Endpoint     = "/services/search/jobs" 
			Verbose      = $VerbosePreference -eq "Continue"
		}
			
		Write-Verbose " [Search-Splunk] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
		try
		{
			[XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams -RequestType POST -Arguments $SearchParams						
			
			if($Results -and ($Results -is [System.Xml.XmlDocument]))
			{
				foreach($Entry in $Results.results.result)
				{					
					$MyObj = @{}
					switch ($Entry.field)
					{
			        	{$_.k -eq "host"}		    { $Myobj.Add("Host",$_.value.text);continue }
			        	{$_.k -eq "source"}		    { $Myobj.Add("Source",$_.value.text);continue }
						{$_.k -eq "sourcetype"}		{ $Myobj.Add("SourceType",$_.value.text);continue }
				        {$_.k -eq "splunk_server"}	{ $Myobj.Add("SplunkServer",$_.value.text);continue }
						{$_.k -eq "_raw"}			{ $Myobj.Add("raw",$_.v.'#text');continue}
				        {$_.k -eq "_time"}			{ $Myobj.Add("Date",(ConvertFrom-SplunkSearchResultTime $_.value.text));continue}
						Default						{ $Myobj.Add($_.k,$_.value.text);continue}
				    }
					
					# Creating Splunk.SDK.ServiceStatus
				    $obj = New-Object PSObject -Property $MyObj
				    $obj.PSTypeNames.Clear()
				    $obj.PSTypeNames.Add('Splunk.SDK.Search.OneshotResult')
				    $obj
				}
			}
			else
			{
				Write-Verbose " [Search-Splunk] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
			}
		}
		catch
		{
			Write-Verbose " [Search-Splunk] :: Invoke-SplunkAPIRequest threw an exception: $_"
            Write-Error $_
		}
	}
	End
	{
		Write-Verbose " [Search-Splunk] :: =========    End   ========="
	}
	
}    # Search-Splunk

#endregion Search-Splunk

#endregion Search

