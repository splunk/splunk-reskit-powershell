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


#region General functions

#region Get-SplunkMessage

function Get-SplunkMessage
{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[Cmdletbinding()]
    Param(

 [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]
        # Name of the Splunk instance (Default is ( get-splunkconnectionobject ).ComputerName).
		$ComputerName = ( get-splunkconnectionobject ).ComputerName,
        
        [Parameter()]
        [int]
		# Port of the REST Instance (i.e. 8089) (Default is ( get-splunkconnectionobject ).Port).
		$Port            = ( get-splunkconnectionobject ).Port,
        
        [Parameter()]
        [ValidateSet("http", "https")]
        [STRING]
        # Protocol to use to access the REST API must be 'http' or 'https' (Default is ( get-splunkconnectionobject ).Protocol).
		$Protocol     = ( get-splunkconnectionobject ).Protocol,
        
        [Parameter()]
        [int]
        # How long to wait for the REST API to respond (Default is ( get-splunkconnectionobject ).Timeout).
		$Timeout         = ( get-splunkconnectionobject ).Timeout,

        [Parameter()]
        [System.Management.Automation.PSCredential]        
		# Credential object with the user name and password used to access the REST API.	
		$Credential = ( get-splunkconnectionobject ).Credential       
    )
    Begin
	{
		Write-Verbose " [Get-SplunkMessage] :: Starting..."
	}
	Process
	{
		Write-Verbose " [Get-SplunkMessage] :: Parameters"
		Write-Verbose " [Get-SplunkMessage] ::  - ComputerName = $ComputerName"
		Write-Verbose " [Get-SplunkMessage] ::  - Port         = $Port"
		Write-Verbose " [Get-SplunkMessage] ::  - Protocol     = $Protocol"
		Write-Verbose " [Get-SplunkMessage] ::  - Timeout      = $Timeout"
		Write-Verbose " [Get-SplunkMessage] ::  - Credential   = $Credential"

		Write-Verbose " [Get-SplunkMessage] :: Setting up Invoke-APIRequest parameters"
		$InvokeAPIParams = @{
			ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
			Endpoint     = '/services/messages' 
			Verbose      = $VerbosePreference -eq "Continue"
		}
			
		Write-Verbose " [Get-SplunkMessage] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
		try
		{
			[XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams
        }
        catch
		{
			Write-Verbose " [Get-SplunkMessage] :: Invoke-SplunkAPIRequest threw an exception: $_"
            Write-Error $_
		}
        try
        {
			if($Results -and ($Results -is [System.Xml.XmlDocument]))
			{
                if($Results.feed.entry)
                {
                    foreach($Entry in $Results.feed.entry)
                    {
        				$MyObj = @{
                            ComputerName = $ComputerName
                        }
                        
                        $MyObj.Add("Name",$Entry.Title)
        				Write-Verbose " [Get-SplunkMessage] :: Creating Hash Table to be used to create Splunk.SDK.Message"
        				switch ($Entry.content.dict.key)
        				{
        		        	{$_.name -ne "eai:acl"}	{ $Myobj.Add("Message",$_.'#text')     ; continue }
        				}
        				
        				$obj = New-Object PSObject -Property $MyObj
        			    $obj.PSTypeNames.Clear()
        			    $obj.PSTypeNames.Add('Splunk.SDK.Message')
        			    $obj 
                    }
                }
                else
                {
                    Write-Verbose " [Get-SplunkMessage] :: No Messages Found"
                }
                
			}
			else
			{
				Write-Verbose " [Get-SplunkMessage] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
			}
		}
		catch
		{
			Write-Verbose " [Get-SplunkMessage] :: Get-SplunkDeploymentClient threw an exception: $_"
            Write-Error $_
		}
	}
	End
	{
		Write-Verbose " [Get-SplunkMessage] :: =========    End   ========="
	}

}    # Get-SplunkMessage

#endregion Get-SplunkMessage

#region Out-Splunk

function Out-Splunk {
<#
    .Notes
     NAME: Out-Splunk
     AUTHOR: Tome Tanasovski
     Version: 1.1
     CREATED: 7/11/2012
     LASTEDIT: 
     7/11/2012 1.0
        Initial Release
     8/9/2013 1.1
        Modified to work with latest from Git

    .Synopsis
     Writes data to Splunk from PowerShell
     
    .Description
     This cmdlet allows you to write a single-level object or set of objects directly to a Splunk indexer.  The objects will be converted to a format that will allow
     Splunk to properly index and create appropriate extract fields.  The cmdlet can also be used to send arbirary strings of text to a Splunk indexer.
     
    .Parameter InputObject
     The set of objects that will be sent to Splunk

    .Parameter DateProperty
     The property of the objects in the pipeline that should be indexed by Splunk in the _time field.  If you do not specify a value, the current Date/Time will be used.
     
     Note: Date fields will be picked up as separators by Splunk. Each object should only have one date field or splunk will break up the object into multiple events.  This
      will cause data to be indexed incorrectly.  You can workaround this by creating your own custom sourcetype with a transforms/props (in Splunk), and use the InputText
      property to format the data exactly as you want it to be presented to the Splunk indexer.
      
    .Parameter WriteCount
     This is the number of objects that should be grouped together into a single upload to the Splunk indexer.  By default this is set to 1.  This means that every object
     initiates a new connection to the server.
     
    .Parameter InputText
     This parameter allows you to specify a string of text data to send to Splunk.  It does not format the data in any way or add any fields that will be indexed under _time.
     
    .Parameter ComputerName
     This is the name of the Splunk indexer you would like to send dat to.
     
    .Parameter Port
     This parameter allows you to specify a port to send data to.  This module utilizes the REST API for Splunk.  You must ensure that you are specifying the management port.     
     
    .Parameter Protocol
     This parameter allows you to specify whether to use 'http' or 'https' as the protocol to transmit data.
     
    .Parameter Timeout
     This parameter controls the timeout value to use.  This defaults to 1000.
    
    .Parameter Index
     This parameter allows you to specify the name of the index in Splunk to send data to. If no index is specified, data will be sent to the index named main on the Splunk server.
    
    .Parameter Hostname
     This parameter allows you to specify a value to use for Splunk's indexed host field.  If no host is specified, this will default to the name of the computer that is running Out-Splunk.
    
    .Parameter Source
     This parameter allows you to specify a value to use for Splunk's indexed Source field.  If no source is specified, this will default to 'Out-Splunk'
    
    .Parameter SourceType
     This parameter allows you to specify a value to use for Splunk's indexed SourceType field. If no sourcetype is specified, this will default to 'Splunk_PowerShell_ResourceKit'. There is no default definition
     for 'Out-Splunk' in Splunk.  This sourcetype will use the default transforms/props that comes with Splunk.  Out-Splunk with -InputObject will ensure that it submits the data in
     a format that will have extract fields for each property.
     
    .Parameter Credential
     This allows you to specify a username and password.       
    
    .Inputs
     PSObject or String Data
     
    .Outputs
     This cmdlet has no output
    
    .Example
     dir |select LastWriteTime, Length, Fullname |Out-Splunk -DateProperty LastWriteTime -Computername 'izvm2db4' -Credential (Get-Credential)
     
     This will populate the main index on izvm2db4 with a record for every file and directory in the current directory.  The LastWriteTime property for each file/directory will be
     indexed as the _time field.  Each record will have its SourceType named 'Splunk_PowerShell_ResourceKit' and its Source will be named 'Out-Splunk'. You will be prompted to enter credentials.
    
    .Example
     Import-CSV data.csv |Out-Splunk -DateProperty DateTime -Computername 'adwas09' -Index CSVData -Source data.csv -SourceType Data -Credential (get-credential) -WriteCount 10
     
     This will populate the pre-existing CSVData index on adwas09 with a record for every row in the file data.csv. The columne entitled DateTime will be used as the indexed _time field for each row.  Each 
     record will have its SourceType named 'data.csv' and its source named 'CSVData'. The user will be prompted to specify a username and password when the command is run. The data will be sent 10 rows/events
     at a time.
     
    .Example
     $data = @"
        $(Get-Date)
        This=That
        Me=You
        
     "@
     Out-MSSplunk -InputText $data
     
     This will send the contents of $data to the main index on a splunk server that was connected to via Connect-Splunk.  The source will be Out-Splunk and the sourcetype will be Splunk_PowerShell_ResourceKit.
     
    .Example
     Out-Splunk -InputText (get-content c:\file.log) -Source 'c:\file.log'
     
     This will send the contents of c:\file.log to the main index of the Splunk server that was connected to via Connect-Splunk.  The source will be 'c:\file.log' and the sourcetype will be 'Splunk_PowerShell_ResourceKit'.
     
    .LINK
     http://powershell

#>
    param(
        [Parameter(Mandatory=$false)]
        [string]$Computername=( get-splunkconnectionobject ).ComputerName,
        
        [Parameter(Mandatory=$false)]
        [ValidatePattern('^\d+$')]
        [string]$Port = ( get-splunkconnectionobject ).Port,
        
        [Parameter(Mandatory=$false)]
        [ValidateRange('http','https')]
        [string]$Protocol=( get-splunkconnectionobject ).Protocol,
        
        [Parameter(Mandatory=$false)]
        [int]$Timeout = ( get-splunkconnectionobject ).Timeout,
        
        [Parameter(Mandatory=$false)]
        [string]$Index = 'main',
        
        [Parameter(Mandatory=$false)]
        [string]$Hostname = $env:COMPUTERNAME,
        
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ParameterSetName='Object')]
        [psobject[]]$InputObject,
        
        [Parameter(Mandatory=$false,ParameterSetName='Object')]
        [string]$DateProperty=$null,
        
        [Parameter(Mandatory=$false,ParameterSetName='Object')]
        [ValidateScript({$_ -gt 0})]
        [int]$WriteCount = 1,
        
        [Parameter(Mandatory=$true,ParameterSetName='Text')]
        [string]$InputText,
        
        [Parameter(Mandatory=$false)]
        [string]$Source='Out-Splunk',
        
        [Parameter(Mandatory=$false)]
        [string]$SourceType='Splunk_PowerShell_ResourceKit',
        
        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential] $Credential = ( get-splunkconnectionobject ).Credential        
    )
    BEGIN {
        $InvokeAPIParams = @{
            ComputerName = $computername
            Port = $port
            Protocol = $protocol
            Timeout = $Timeout
            Credential   = $Credential            
            Endpoint = '/services/receivers/simple'            
            Verbose = $VerbosePreference -eq "Continue"            
        }
        
        Write-Verbose " [Out-Splunk] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
                
        $MyParam = 'host={0}&source={1}&sourcetype={2}&index={3}' -f $hostname,$source,$sourcetype,$index
        
        Write-Verbose " [Out-Splunk] :: Url: $myparam"
        $currentobject = 1
        if (!$InputText) {
            $InputText = ""
        }
        $Results = $null
        
        # Create a non-exported helper function that will reuse the bit of code where data is sent and received
        function SendReceiveFunction {
            Write-Verbose " [Out-Splunk] :: Message: $InputText"
            try {
                [XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams -PostMessage $InputText -URLParam $MyParam -RequestType SIMPLEPOST
            }
            catch {
            	Write-Verbose " [Write-SplunkMessage] :: Invoke-SplunkAPIRequest threw an exception: $_"
                Write-Error $_
    		            }
            try {
                Write-Verbose " [Out-Splunk] :: Checking return results from the server"    
                if($Results -and ($Results -is [System.Xml.XmlDocument])) {
                    $Myobj = @{}
                    foreach($key in $Results.response.results.result.field) {
                        $data = $key.Value.Text
                        switch -exact ($Key.k)
                        {
                            "_index"       {$Myobj.Add("Index",$data);continue}
                            "host"         {$Myobj.Add("Host",$data);continue}
                            "source"       {$Myobj.Add("Source",$data);continue} 
                            "sourcetype"   {$Myobj.Add("Sourcetype",$data);continue}
                        }
                    }                    
                    $obj = New-Object PSObject -Property $myobj
                    $obj
    	        }
            }
    		catch
    		{
    			Write-Verbose " [Out-Splunk] :: Get-Splunkd threw an exception: $_"
                Write-Error $_
    		}
        }
    }
    PROCESS {
        if ($pscmdlet.parametersetname -eq 'Object') {
            Write-Verbose " [Out-Splunk] :: Object(s) detected"
            foreach ($object in $InputObject) {
                Write-Verbose " [Out-Splunk] :: ObjectCount: $currentobject"
                # If the dateproperty is specified, it will be the first thing in the new message
                if ($DateProperty) {
                    $date = [datetime]$object.($DateProperty)
                }
                else {
                    $date = Get-Date
                }
                $InputText += "`r`n$date "                
                $InputText += $object.psobject.properties |%{
                    if (!$dateproperty -or ($_.name -notmatch $DateProperty)) {
                        '{0}="{1}" ' -f $_.name, $object.($_.name)
                    }
                }
                $InputText += "`r`n"
                if ($currentobject -eq $WriteCount) {
                    # Hit the writecount limit - send all of the messages to splunk as a single message
                    Write-Verbose " [Out-Splunk] :: WriteCount limit reached of $writecount - Preparing to send message"
                    SendReceiveFunction
                    $InputText = ""
                    $currentobject = 1
                }
                else {
                    $currentobject++
                }
            }            
        } else {
            # This is not an object, just send up what is in $InputText
            SendReceiveFunction
        }
    }
    END {
        if ($pscmdlet.parametersetname -eq 'Object') {
            # One final message for the remainder of the data to be sent
            if (($currentobect -le $writecount) -and ($writecount -ne 1)) {
                SendReceiveFunction
            }
        }
    }
}

#endregion Out-Splunk

#region Write-SplunkMessage

function Write-SplunkMessage
{
	<# .ExternalHelp ../Splunk-Help.xml #>

    [Cmdletbinding()]
    Param(
    
        [Parameter(Mandatory=$True)]           
        [String]$Message,       

        [Parameter()]           
        [String]$HostName     = $Env:COMPUTERNAME,
        
        [Parameter()]           
        [String]$Source       = "Powershell_Script",
        
        [Parameter()]           
        [String]$SourceType   = "Splunk_PowerShell_ResourceKit",
        
        [Parameter()]           
        [String]$Index        = "main",
		
		[Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]
        # Name of the Splunk instance (Default is ( get-splunkconnectionobject ).ComputerName).
		$ComputerName = ( get-splunkconnectionobject ).ComputerName,
        
        [Parameter()]
        [int]
		# Port of the REST Instance (i.e. 8089) (Default is ( get-splunkconnectionobject ).Port).
		$Port            = ( get-splunkconnectionobject ).Port,
        
        [Parameter()]
        [ValidateSet("http", "https")]
        [STRING]
        # Protocol to use to access the REST API must be 'http' or 'https' (Default is ( get-splunkconnectionobject ).Protocol).
		$Protocol     = ( get-splunkconnectionobject ).Protocol,
        
        [Parameter()]
        [int]
        # How long to wait for the REST API to respond (Default is ( get-splunkconnectionobject ).Timeout).
		$Timeout         = ( get-splunkconnectionobject ).Timeout,

        [Parameter()]
        [System.Management.Automation.PSCredential]        
		# Credential object with the user name and password used to access the REST API.	
		$Credential = ( get-splunkconnectionobject ).Credential
        
    )

	Begin
	{
		Write-Verbose " [Write-SplunkMessage] :: Starting..."
        $Stack = Get-PSCallStack
        $CallingScope = $Stack[$Stack.Count-2]
	}
	Process
	{
		Write-Verbose " [Write-SplunkMessage] :: Parameters"
		Write-Verbose " [Write-SplunkMessage] ::  - ComputerName = $ComputerName"
		Write-Verbose " [Write-SplunkMessage] ::  - Port         = $Port"
		Write-Verbose " [Write-SplunkMessage] ::  - Protocol     = $Protocol"
		Write-Verbose " [Write-SplunkMessage] ::  - Timeout      = $Timeout"
		Write-Verbose " [Write-SplunkMessage] ::  - Credential   = $Credential"

		Write-Verbose " [Write-SplunkMessage] :: Setting up Invoke-APIRequest parameters"
		$InvokeAPIParams = @{
			ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
			Endpoint     = '/services/receivers/simple' 
			Verbose      = $VerbosePreference -eq "Continue"
		}
                   
		Write-Verbose " [Write-SplunkMessage] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
		try
		{
            Write-Verbose " [Write-SplunkMessage] :: Creating POST message"
            $LogMessage = "{0} :: Caller={1} Message={2}" -f (Get-Date),$CallingScope.Command,$Message
            
            $MyParam = "host=${HostName}&source=${source}&sourcetype=${sourcetype}&index=$Index"
            Write-Verbose " [Write-SplunkMessage] :: URL Parameters [$MyParam]"
            
            Write-Verbose " [Write-SplunkMessage] :: Sending LogMessage - $LogMessage"
			[XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams -PostMessage $LogMessage -URLParam $MyParam -RequestType SIMPLEPOST
        }
        catch
		{
			Write-Verbose " [Write-SplunkMessage] :: Invoke-SplunkAPIRequest threw an exception: $_"
            Write-Error $_
		}
        try
        {
			if($Results -and ($Results -is [System.Xml.XmlDocument]))
			{
                $Myobj = @{}

                foreach($key in $Results.response.results.result.field)
                {
                    $data = $key.Value.Text
                    switch -exact ($Key.k)
                    {
                        "_index"       {$Myobj.Add("Index",$data);continue}
                        "host"         {$Myobj.Add("Host",$data);continue}
                        "source"       {$Myobj.Add("Source",$data);continue} 
                        "sourcetype"   {$Myobj.Add("Sourcetype",$data);continue}
                    }
                }
                
                $obj = New-Object PSObject -Property $myobj
                $obj.PSTypeNames.Clear()
                $obj.PSTypeNames.Add('Splunk.SDK.MessageResult')
                $obj
			}
			else
			{
				Write-Verbose " [Write-SplunkMessage] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
			}
		}
		catch
		{
			Write-Verbose " [Write-SplunkMessage] :: Get-Splunkd threw an exception: $_"
            Write-Error $_
		}
	}
	End
	{
		Write-Verbose " [Write-SplunkMessage] :: =========    End   ========="
	}
    
}    # Write-SplunkMessage

#endregion Write-SplunkMessage

#endregion General functions

