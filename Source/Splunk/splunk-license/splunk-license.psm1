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

# Splunk License

#region Get-SplunkLicenseFile

function Get-SplunkLicenseFile
{

	<# .ExternalHelp ../Splunk-Help.xml #>
	
	[Cmdletbinding()]
    Param(
	
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
        [System.Management.Automation.PSCredential]$Credential = ( get-splunkconnectionobject ).Credential,
        
        [Parameter()]
        [SWITCH]$All
        
    )
	
	Begin
	{
		Write-Verbose " [Get-SplunkLicenseFile] :: Starting..."
	}
	Process
	{
		Write-Verbose " [Get-SplunkLicenseFile] :: Parameters"
		Write-Verbose " [Get-SplunkLicenseFile] ::  - ComputerName = $ComputerName"
		Write-Verbose " [Get-SplunkLicenseFile] ::  - Port         = $Port"
		Write-Verbose " [Get-SplunkLicenseFile] ::  - Protocol     = $Protocol"
		Write-Verbose " [Get-SplunkLicenseFile] ::  - Timeout      = $Timeout"
		Write-Verbose " [Get-SplunkLicenseFile] ::  - Credential   = $Credential"

        if($All)
        {
            $Endpoint = '/services/licenser/licenses'
        }
        else
        {
            $Endpoint = "/services/licenser/licenses?search={0}" -f [System.Web.HttpUtility]::UrlEncode('group_id=enterprise')
        }
        Write-Verbose " [Get-SplunkLicenseFile] ::  - Endpoint   = $Endpoint"
        
		Write-Verbose " [Get-SplunkLicenseFile] :: Setting up Invoke-APIRequest parameters"
		$InvokeAPIParams = @{
			ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
			Endpoint     = $Endpoint 
			Verbose      = $VerbosePreference -eq "Continue"
		}
			
		Write-Verbose " [Get-SplunkLicenseFile] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
		try
		{
			[XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams
			if($Results -and ($Results -is [System.Xml.XmlDocument]))
			{
				foreach($Entry in $Results.feed.Entry)
				{
					$MyObj = @{}
                    $MyObj.Add('ComputerName',$ComputerName)
					Write-Verbose " [Get-SplunkLicenseFile] :: Creating Hash Table to be used to create Splunk.SDK.Splunk.Licenser.License"
					switch ($Entry.content.dict.key)
					{
						{$_.name -eq "creation_time"} 	{$Myobj.Add("CreationTime", (ConvertFrom-UnixTime $_.'#text'));continue}
			        	{$_.name -eq "expiration_time"} {$Myobj.Add("Expiration", (ConvertFrom-UnixTime $_.'#text'));continue}
			        	{$_.name -eq "features"}	    {$Myobj.Add("Features",$_.list.item);continue}
						{$_.name -eq "group_id"}		{$Myobj.Add("GroupID",$_.'#text');continue}
				        {$_.name -eq "label"}			{$Myobj.Add("Label",$_.'#text');continue}
						{$_.name -eq "license_hash"}	{$Myobj.Add("Hash",$_.'#text');continue}
				        {$_.name -eq "max_violations"}	{$Myobj.Add("MaxViolations",$_.'#text');continue}
				        {$_.name -eq "quota"}			{$Myobj.Add("Quota",$_.'#text');continue}
				        {$_.name -eq "sourcetypes"}		{$Myobj.Add("SourceTypes",$_.'#text');continue}
				        {$_.name -eq "stack_id"}		{$Myobj.Add("StackID",$_.'#text');continue}
				        {$_.name -eq "status"}			{$Myobj.Add("Status",$_.'#text');continue}
				        {$_.name -eq "type"}			{$Myobj.Add("Type",$_.'#text');continue}
						{$_.name -eq "window_period"}	{$Myobj.Add("WindowPeriod",$_.'#text');continue}
					}
					
					# Creating Splunk.SDK.ServiceStatus
				    $obj = New-Object PSObject -Property $MyObj
				    $obj.PSTypeNames.Clear()
				    $obj.PSTypeNames.Add('Splunk.SDK.Splunk.Licenser.License')
				    $obj
				}
			}
			else
			{
				Write-Verbose " [Get-SplunkLicenseFile] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
			}
		}
		catch
		{
			Write-Verbose " [Get-SplunkLicenseFile] :: Invoke-SplunkAPIRequest threw an exception: $_"
            Write-Error $_
		}
	}
	End
	{
		Write-Verbose " [Get-SplunkLicenseFile] :: =========    End   ========="
	}
} # Get-SplunkLicenseFile

#endregion Get-SplunkLicenseFile

#region Add-SplunkLicenseFile

function Add-SplunkLicenseFile
{
	<# .ExternalHelp ../Splunk-Help.xml #>	
	[Cmdletbinding(SupportsShouldProcess=$true,ConfirmImpact="Low")]
    Param(
	
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
        [System.Management.Automation.PSCredential]$Credential = ( get-splunkconnectionobject ).Credential,
        
        [Parameter(Mandatory=$true)]
        [string]$Name,
		
		[Parameter(Mandatory=$true)]
        [string]$Path
    )
	
	Begin
	{
		Write-Verbose " [Add-SplunkLicenseFile] :: Starting..."
	}
	Process
	{
		Write-Verbose " [Add-SplunkLicenseFile] :: Parameters"
		Write-Verbose " [Add-SplunkLicenseFile] ::  - ParamSet	   = $($pscmdlet.ParameterSetName)"
		Write-Verbose " [Add-SplunkLicenseFile] ::  - ComputerName = $ComputerName"
		Write-Verbose " [Add-SplunkLicenseFile] ::  - Port         = $Port"
		Write-Verbose " [Add-SplunkLicenseFile] ::  - Protocol     = $Protocol"
		Write-Verbose " [Add-SplunkLicenseFile] ::  - Timeout      = $Timeout"
		Write-Verbose " [Add-SplunkLicenseFile] ::  - Credential   = $Credential"
		Write-Verbose " [Add-SplunkLicenseFile] ::  - Name         = $Name"
        Write-Verbose " [Add-SplunkLicenseFile] ::  - Path         = $Path"

        $Endpoint = '/services/licenser/licenses/'
        Write-Verbose " [Add-SplunkLicenseFile] ::  - Endpoint   = $Endpoint"

		if(-not $PSCmdlet.ShouldProcess($ComputerName,"Adding Splunk License $Name File from $Path"))
		{
			return;
		}

        if(Test-Path $Path)
        {
            $payload = Get-Content $Path | Out-String;
        }
        else
        {
            Write-Error "File ($Path) not found";
        }
		
		Write-Verbose " [Add-SplunkLicenseFile] :: Setting up Invoke-APIRequest parameters"
		$postArgs = @{
			'name' = $Name;
			'payload' = $payload;
		}
		
		$InvokeAPIParams = @{
			ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
			Endpoint     = $Endpoint 
			RequestType	 = 'POST'
			Arguments 	 = $postArgs
			Verbose      = $VerbosePreference -eq "Continue"
		}
			
		Write-Verbose " [Add-SplunkLicenseFile] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
		try
		{
			[XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams
			
			if($Results -and ($Results -is [System.Xml.XmlDocument]))
			{
				foreach($Entry in $Results.feed.Entry)
				{
					$MyObj = @{}
                    $MyObj.Add('ComputerName',$ComputerName)
					Write-Verbose " [Add-SplunkLicenseFile] :: Creating Hash Table to be used to create Splunk.SDK.Splunk.Licenser.License"
					switch ($Entry.content.dict.key)
					{
						{$_.name -eq "creation_time"} 	{$Myobj.Add("CreationTime", (ConvertFrom-UnixTime $_.'#text'));continue}
			        	{$_.name -eq "expiration_time"} {$Myobj.Add("Expiration", (ConvertFrom-UnixTime $_.'#text'));continue}
			        	{$_.name -eq "features"}	    {$Myobj.Add("Features",$_.list.item);continue}
						{$_.name -eq "group_id"}		{$Myobj.Add("GroupID",$_.'#text');continue}
				        {$_.name -eq "label"}			{$Myobj.Add("Label",$_.'#text');continue}
						{$_.name -eq "license_hash"}	{$Myobj.Add("Hash",$_.'#text');continue}
				        {$_.name -eq "max_violations"}	{$Myobj.Add("MaxViolations",$_.'#text');continue}
				        {$_.name -eq "quota"}			{$Myobj.Add("Quota",$_.'#text');continue}
				        {$_.name -eq "sourcetypes"}		{$Myobj.Add("SourceTypes",$_.'#text');continue}
				        {$_.name -eq "stack_id"}		{$Myobj.Add("StackID",$_.'#text');continue}
				        {$_.name -eq "status"}			{$Myobj.Add("Status",$_.'#text');continue}
				        {$_.name -eq "type"}			{$Myobj.Add("Type",$_.'#text');continue}
						{$_.name -eq "window_period"}	{$Myobj.Add("WindowPeriod",$_.'#text');continue}
					}
					
					# Creating Splunk.SDK.ServiceStatus
				    $obj = New-Object PSObject -Property $MyObj
				    $obj.PSTypeNames.Clear()
				    $obj.PSTypeNames.Add('Splunk.SDK.Splunk.Licenser.License')
				    $obj
				}
			}
			else
			{
				Write-Verbose " [Add-SplunkLicenseFile] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
			}
		}
		catch
		{
			Write-Verbose " [Add-SplunkLicenseFile] :: Invoke-SplunkAPIRequest threw an exception: $_"
            Write-Error $_
		}
	}
	End
	{
		Write-Verbose " [Add-SplunkLicenseFile] :: =========    End   ========="
	}
} # Add-SplunkLicenseFile

#endregion Add-SplunkLicenseFile

#region Remove-SplunkLicenseFile

function Remove-SplunkLicenseFile
{
	<# .ExternalHelp ../Splunk-Help.xml #>	
	[Cmdletbinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
    Param(
    
        [Alias("Name")]
		[Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true, Mandatory=$true)]
        [String]$HASH,
	
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [String]$ComputerName = ( get-splunkconnectionobject ).ComputerName,
        
        [Parameter()]
        [int]$Port            = ( get-splunkconnectionobject ).Port,
        
        [Parameter()]
		[ValidateSet("http", "https")]
        [STRING]$Protocol     = ( get-splunkconnectionobject ).Protocol,
        
        [Parameter()]
        [int]$Timeout         = ( get-splunkconnectionobject ).Timeout,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential = ( get-splunkconnectionobject ).Credential,
		
		[Parameter()]
        [SWITCH]$Force
    )
	
	Begin
	{
		Write-Verbose " [Remove-SplunkLicenseFile] :: Starting..."
	}
	Process
	{
		Write-Verbose " [Remove-SplunkLicenseFile] :: Parameters"
		Write-Verbose " [Remove-SplunkLicenseFile] ::  - Name = $Name"
		Write-Verbose " [Remove-SplunkLicenseFile] ::  - ComputerName = $ComputerName"
		Write-Verbose " [Remove-SplunkLicenseFile] ::  - Port         = $Port"
		Write-Verbose " [Remove-SplunkLicenseFile] ::  - Protocol     = $Protocol"
		Write-Verbose " [Remove-SplunkLicenseFile] ::  - Timeout      = $Timeout"
		Write-Verbose " [Remove-SplunkLicenseFile] ::  - Credential   = $Credential"

        $Endpoint = '/services/licenser/licenses/{0}' -f $HASH;
        Write-Verbose " [Remove-SplunkLicenseFile] ::  - Endpoint   = $Endpoint"
        
		if($Force -or $PSCmdlet.ShouldProcess($HASH,"Removing License File From [$ComputerName]"))
		{
			Write-Verbose " [Remove-SplunkLicenseFile] :: Setting up Invoke-APIRequest parameters"		
			$InvokeAPIParams = @{
				ComputerName = $ComputerName
				Port         = $Port
				Protocol     = $Protocol
				Timeout      = $Timeout
				Credential   = $Credential
				Endpoint     = $Endpoint 
				RequestType	 = 'DELETE'
				Verbose      = $VerbosePreference -eq "Continue"
			}
				
			Write-Verbose " [Remove-SplunkLicenseFile] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
			try
			{
				[XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams
				
				if($Results -and ($Results -is [System.Xml.XmlDocument]))
				{
                    # What to add here?
				}
				else
				{
					Write-Verbose " [Remove-SplunkLicenseFile] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
				}
			}
			catch
			{
				Write-Verbose " [Remove-SplunkLicenseFile] :: Invoke-SplunkAPIRequest threw an exception: $_"
	            Write-Error $_
			}
		}
	}
	End
	{
		Write-Verbose " [Remove-SplunkLicenseFile] :: =========    End   ========="
	}
} # Remove-SplunkLicenseFile

#endregion Remove-SplunkLicenseFile

#region Get-SplunkLicenseMessage

function Get-SplunkLicenseMessage
{
	<# .ExternalHelp ../Splunk-Help.xml #>

	[Cmdletbinding()]
    Param(

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
        [System.Management.Automation.PSCredential]$Credential = ( get-splunkconnectionobject ).Credential
        
    )
    Begin
	{
		Write-Verbose " [Get-SplunkLicenseMessage] :: Starting..."
	}
	Process
	{
		Write-Verbose " [Get-SplunkLicenseMessage] :: Parameters"
		Write-Verbose " [Get-SplunkLicenseMessage] ::  - ComputerName = $ComputerName"
		Write-Verbose " [Get-SplunkLicenseMessage] ::  - Port         = $Port"
		Write-Verbose " [Get-SplunkLicenseMessage] ::  - Protocol     = $Protocol"
		Write-Verbose " [Get-SplunkLicenseMessage] ::  - Timeout      = $Timeout"
		Write-Verbose " [Get-SplunkLicenseMessage] ::  - Credential   = $Credential"

		Write-Verbose " [Get-SplunkLicenseMessage] :: Setting up Invoke-APIRequest parameters"
		$InvokeAPIParams = @{
			ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
			Endpoint     = '/services/licenser/messages' 
			Verbose      = $VerbosePreference -eq "Continue"
		}
			
		Write-Verbose " [Get-SplunkLicenseMessage] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
		try
		{
			[XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams
        }
        catch
		{
			Write-Verbose " [Get-SplunkLicenseMessage] :: Invoke-SplunkAPIRequest threw an exception: $_"
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
        				Write-Verbose " [Get-SplunkLicenseMessage] :: Creating Hash Table to be used to create Splunk.SDK.License.Message"
        				switch ($Entry.content.dict.key)
        				{
        		        	{$_.name -eq "category"}	{ $Myobj.Add("Category",$_.'#text')     ; continue }
        					{$_.name -eq "create_time"}	{ $Myobj.Add("CreateTime",(ConvertFrom-UnixTime $_.'#text'))   ; continue }
        			        {$_.name -eq "pool_id"}	    { $Myobj.Add("PoolID",$_.'#text')       ; continue }
                            {$_.name -eq "severity"}    { $Myobj.Add("Severity",$_.'#text')     ; continue }
                            {$_.name -eq "slave_id"}	{ $Myobj.Add("SlaveID",$_.'#text')      ; continue }
                            {$_.name -eq "stack_id"}	{ $Myobj.Add("StackID",$_.'#text')      ; continue }
                            {$_.name -eq "description"}	{ $Myobj.Add("Message",$_.'#text')      ; continue }
        				}
        				
        				# Creating Splunk.SDK.ServiceStatus
        			    $obj = New-Object PSObject -Property $MyObj
        			    $obj.PSTypeNames.Clear()
        			    $obj.PSTypeNames.Add('Splunk.SDK.License.Message')
        			    $obj 
                    }
                }
                else
                {
                    Write-Verbose " [Get-SplunkLicenseMessage] :: No Messages Found"
                }
                
			}
			else
			{
				Write-Verbose " [Get-SplunkLicenseMessage] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
			}
		}
		catch
		{
			Write-Verbose " [Get-SplunkLicenseMessage] :: Get-SplunkDeploymentClient threw an exception: $_"
            Write-Error $_
		}
	}
	End
	{
		Write-Verbose " [Get-SplunkLicenseMessage] :: =========    End   ========="
	}

}    # Get-SplunkLicenseMessage

#endregion Get-SplunkLicenseMessage

#region Get-SplunkLicenseGroup

function Get-SplunkLicenseGroup
{
	<# .ExternalHelp ../Splunk-Help.xml #>
    [Cmdletbinding(DefaultParameterSetName="byFilter")]
    Param(

        [Parameter(Position=0,ParameterSetName="byFilter")]
        [STRING]$Filter = '.*',
	
		[Parameter(Position=0,ParameterSetName="byName")]
		[STRING]$Name,

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
        [SWITCH]$Active,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential = ( get-splunkconnectionobject ).Credential
        
    )
    Begin
	{
		Write-Verbose " [Get-SplunkLicenseGroup] :: Starting..."
        
        $ParamSetName = $pscmdlet.ParameterSetName
        switch ($ParamSetName)
        {
            "byFilter"  { $WhereFilter = { $_.GroupName -match $Filter } } 
            "byName"    { $WhereFilter = { $_.GroupName -ceq   $Name } }
        }
        
	}
	Process
	{
		Write-Verbose " [Get-SplunkLicenseGroup] :: Parameters"
        Write-Verbose " [Get-SplunkLicenseGroup] ::  - ParameterSet = $ParamSetName"
		Write-Verbose " [Get-SplunkLicenseGroup] ::  - ComputerName = $ComputerName"
		Write-Verbose " [Get-SplunkLicenseGroup] ::  - Port         = $Port"
		Write-Verbose " [Get-SplunkLicenseGroup] ::  - Protocol     = $Protocol"
		Write-Verbose " [Get-SplunkLicenseGroup] ::  - Timeout      = $Timeout"
		Write-Verbose " [Get-SplunkLicenseGroup] ::  - Credential   = $Credential"
        Write-Verbose " [Get-SplunkLicenseGroup] ::  - WhereFilter  = $WhereFilter"

		Write-Verbose " [Get-SplunkLicenseGroup] :: Setting up Invoke-APIRequest parameters"
		$InvokeAPIParams = @{
			ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
			Endpoint     = '/services/licenser/groups' 
			Verbose      = $VerbosePreference -eq "Continue"
		}
			
		Write-Verbose " [Get-SplunkLicenseGroup] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
		try
		{
			[XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams
        }
        catch
		{
			Write-Verbose " [Get-SplunkLicenseGroup] :: Invoke-SplunkAPIRequest threw an exception: $_"
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
                            GroupName    = $Entry.title
                            ID           = $Entry.link | Where-Object {$_.rel -eq "edit"} | Select-Object -expand href
                        }
        				Write-Verbose " [Get-SplunkLicenseGroup] :: Creating Hash Table to be used to create Splunk.SDK.License.Group"
        				switch ($Entry.content.dict.key)
        				{
        		        	{$_.name -eq "is_active"}	{ $Myobj.Add("IsActive",[bool]([int]$_.'#text'))  ; continue }
                            {$_.name -eq "stack_ids"}	{ $Myobj.Add("StackIDs",$_.list.item)        ; continue }
        				}
        				
        				# Creating Splunk.SDK.ServiceStatus
        			    $obj = New-Object PSObject -Property $MyObj
        			    $obj.PSTypeNames.Clear()
        			    $obj.PSTypeNames.Add('Splunk.SDK.License.Group')
        			    $obj | Where-Object $WhereFilter | Where-Object { -not( $Active ) -or $_.IsActive }						
                    }
                }
                else
                {
                    Write-Verbose " [Get-SplunkLicenseGroup] :: No Messages Found"
                }
                
			}
			else
			{
				Write-Verbose " [Get-SplunkLicenseGroup] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
			}
		}
		catch
		{
			Write-Verbose " [Get-SplunkLicenseGroup] :: Get-SplunkDeploymentClient threw an exception: $_"
            Write-Error $_
		}
	}
	End
	{
		Write-Verbose " [Get-SplunkLicenseGroup] :: =========    End   ========="
	}

}    # Get-SplunkLicenseGroup

#endregion Get-SplunkLicenseGroup

#region Get-SplunkLicenseStack

function Get-SplunkLicenseStack
{
	<# .ExternalHelp ../Splunk-Help.xml #>

    [Cmdletbinding(DefaultParameterSetName="byFilter")]
    Param(

        [Parameter(Position=0,ParameterSetName="byFilter")]
        [STRING]$Filter = '.*',
	
		[Parameter(Position=0,ParameterSetName="byName")]
		[STRING]$Name,

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
        [System.Management.Automation.PSCredential]$Credential = ( get-splunkconnectionobject ).Credential
        
    )
    Begin
	{
		Write-Verbose " [Get-SplunkLicenseStack] :: Starting..."
        
        $ParamSetName = $pscmdlet.ParameterSetName
        switch ($ParamSetName)
        {
            "byFilter"  { $WhereFilter = { $_.StackName -match $Filter } } 
            "byName"    { $WhereFilter = { $_.StackName -ceq   $Name } }
        }
        
	}
	Process
	{
		Write-Verbose " [Get-SplunkLicenseStack] :: Parameters"
        Write-Verbose " [Get-SplunkLicenseStack] ::  - ParameterSet = $ParamSetName"
		Write-Verbose " [Get-SplunkLicenseStack] ::  - ComputerName = $ComputerName"
		Write-Verbose " [Get-SplunkLicenseStack] ::  - Port         = $Port"
		Write-Verbose " [Get-SplunkLicenseStack] ::  - Protocol     = $Protocol"
		Write-Verbose " [Get-SplunkLicenseStack] ::  - Timeout      = $Timeout"
		Write-Verbose " [Get-SplunkLicenseStack] ::  - Credential   = $Credential"
        Write-Verbose " [Get-SplunkLicenseStack] ::  - WhereFilter  = $WhereFilter"

		Write-Verbose " [Get-SplunkLicenseStack] :: Setting up Invoke-APIRequest parameters"
		$InvokeAPIParams = @{
			ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
			Endpoint     = '/services/licenser/stacks' 
			Verbose      = $VerbosePreference -eq "Continue"
		}
			
		Write-Verbose " [Get-SplunkLicenseStack] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
		try
		{
			[XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams
        }
        catch
		{
			Write-Verbose " [Get-SplunkLicenseStack] :: Invoke-SplunkAPIRequest threw an exception: $_"
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
                            StackName    = $Entry.title
                            ID           = $Entry.link | Where-Object {$_.rel -eq "list"} | Select-Object -expand href
                        }
        				Write-Verbose " [Get-SplunkLicenseStack] :: Creating Hash Table to be used to create Splunk.SDK.License.Stack"
        				switch ($Entry.content.dict.key)
        				{
        		        	{$_.name -eq "label"}	{ $Myobj.Add("Label",$_.'#text') ; continue }
                            {$_.name -eq "quota"}	{ $Myobj.Add("Quota",$_.'#text') ; continue }
                            {$_.name -eq "type"}	{ $Myobj.Add("Type",$_.'#text')  ; continue }
        				}
        				
        				# Creating Splunk.SDK.License.Stack
        			    $obj = New-Object PSObject -Property $MyObj
        			    $obj.PSTypeNames.Clear()
        			    $obj.PSTypeNames.Add('Splunk.SDK.License.Stack')
        			    $obj | Where-Object $WhereFilter
                    }
                }
                else
                {
                    Write-Verbose " [Get-SplunkLicenseStack] :: No Messages Found"
                }
                
			}
			else
			{
				Write-Verbose " [Get-SplunkLicenseStack] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
			}
		}
		catch
		{
			Write-Verbose " [Get-SplunkLicenseStack] :: Get-SplunkLicenseStack threw an exception: $_"
            Write-Error $_
		}
	}
	End
	{
		Write-Verbose " [Get-SplunkLicenseStack] :: =========    End   ========="
	}

}    # Get-SplunkLicenseStack

#endregion Get-SplunkLicenseStack

#region Get-SplunkLicensePool

function Get-SplunkLicensePool
{
	<# .ExternalHelp ../Splunk-Help.xml #>

    [Cmdletbinding(DefaultParameterSetName="byFilter")]
    Param(

        [Parameter(Position=0,ParameterSetName="byFilter")]
        [STRING]$Filter = '.*',
    
        [Alias('Name')]
        [Parameter(Position=0,ParameterSetName="byName")]
        [STRING]$PoolName,

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
        [System.Management.Automation.PSCredential]$Credential = ( get-splunkconnectionobject ).Credential
        
    )
    Begin 
    {

        Write-Verbose " [Get-SplunkLicensePool] :: Starting..."
        
        $ParamSetName = $pscmdlet.ParameterSetName
        switch ($ParamSetName)
        {
            "byFilter"  { $WhereFilter = { $_.PoolName -match $Filter } } 
            "byName"    { $WhereFilter = { $_.PoolName -ceq   $PoolName } }
        }

    }
    Process 
    {

            Write-Verbose " [Get-SplunkLicensePool] :: Parameters"
            Write-Verbose " [Get-SplunkLicensePool] ::  - ParameterSet = $ParamSetName"
            Write-Verbose " [Get-SplunkLicensePool] ::  - ComputerName = $ComputerName"
            Write-Verbose " [Get-SplunkLicensePool] ::  - Port         = $Port"
            Write-Verbose " [Get-SplunkLicensePool] ::  - Protocol     = $Protocol"
            Write-Verbose " [Get-SplunkLicensePool] ::  - Timeout      = $Timeout"
            Write-Verbose " [Get-SplunkLicensePool] ::  - Credential   = $Credential"
            Write-Verbose " [Get-SplunkLicensePool] ::  - WhereFilter  = $WhereFilter"

            Write-Verbose " [Get-SplunkLicensePool] :: Setting up Invoke-APIRequest parameters"
            $InvokeAPIParams = @{
                ComputerName = $ComputerName
                Port         = $Port
                Protocol     = $Protocol
                Timeout      = $Timeout
                Credential   = $Credential
                Endpoint     = '/services/licenser/pools' 
                Verbose      = $VerbosePreference -eq "Continue"
            }
                
            Write-Verbose " [Get-SplunkLicensePool] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
            
            try
            {
                [XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams
            }
            catch
            {
                Write-Verbose " [Get-SplunkLicensePool] :: Invoke-SplunkAPIRequest threw an exception: $_"
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
                                PoolName     = $Entry.title
                                ID           = $Entry.link | Where-Object {$_.rel -eq "edit"} | Select-Object -expand href
                            }
                            Write-Verbose " [Get-SplunkLicensePool] :: Creating Hash Table to be used to create Splunk.SDK.License.Pool"
                            switch ($Entry.content.dict.key)
                            {
                                {$_.name -eq "description"}           { $Myobj.Add("Description",$_.'#text')        ; continue }
                                {$_.name -eq "slaves_usage_bytes"}    { 
                                                                        $MySlaves = @()
                                                                        if($_.dict)
                                                                        {
                                                                            $MySlaves = @()
                                                                            foreach($Item in $_.dict.key)
                                                                            {
                                                                                $MySlaveObject = @{}
                                                                                $MySlaveObject.Add("ComputerName",$ComputerName)
                                                                                $MySlaveObject.Add("SlaveID",$Item.Name)
                                                                                $MySlaveObject.Add("BytesUsed",$Item.'#text')
                                                                                # Creating Splunk.SDK.License.PoolSlave
                                                                                $Slaveobj = New-Object PSObject -Property $MySlaveObject
                                                                                $Slaveobj.PSTypeNames.Clear()
                                                                                $Slaveobj.PSTypeNames.Add('Splunk.SDK.License.PoolSlave')
                                                                                $MySlaves += $Slaveobj
                                                                            }
                                                                        }
                                                                        $Myobj.Add("Slaves",$MySlaves)
                                                                        continue
                                                                      }
                                {$_.name -eq "stack_id"}              { $Myobj.Add("StackID",$_.'#text')            ; continue }
                                {$_.name -eq "used_bytes"}            { $Myobj.Add("UsedBytes",$_.'#text')          ; continue }
                                {$_.name -eq "quota"}                 { $Myobj.Add("Quota",$_.'#text')              ; continue }
                            }
                            
                            # Creating Splunk.SDK.License.Pool
                            $obj = New-Object PSObject -Property $MyObj
                            $obj.PSTypeNames.Clear()
                            $obj.PSTypeNames.Add('Splunk.SDK.License.Pool')
                            $obj | Where-Object $WhereFilter
                        }
                    }
                    else
                    {
                        Write-Verbose " [Get-SplunkLicensePool] :: No Messages Found"
                    }
                    
                }
                else
                {
                    Write-Verbose " [Get-SplunkLicensePool] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
                }
            }
            catch
            {
                Write-Verbose " [Get-SplunkLicensePool] :: Get-SplunkLicensePool threw an exception: $_"
                Write-Error $_
			}
    
    }
    End 
    {
        Write-Verbose " [Get-SplunkLicensePool] :: =========    End   ========="
    }
    
}   # Get-SplunkLicensePool

#endregion Get-SplunkLicensePool

#region Remove-SplunkLicensePool

function Remove-SplunkLicensePool
{
	<# .ExternalHelp ../Splunk-Help.xml #>
    [Cmdletbinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
    Param(

        [Alias('Name')]
        [Parameter(ValueFromPipeline=$true,Position=0,Mandatory=$true)]
        [STRING]$PoolName,

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [String]$ComputerName = ( get-splunkconnectionobject ).ComputerName,
        
        [Parameter()]
        [int]$Port            = ( get-splunkconnectionobject ).Port,
        
        [Parameter()]
        [ValidateSet("http", "https")]
        [STRING]$Protocol     = ( get-splunkconnectionobject ).Protocol,
        
        [Parameter()]
        [int]$Timeout         = ( get-splunkconnectionobject ).Timeout,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential = ( get-splunkconnectionobject ).Credential,
		
		[Parameter()]
        [SWITCH]$Force
        
    )
    Begin 
    {

        Write-Verbose " [Remove-SplunkLicensePool] :: Starting..."        
    }
    Process 
    {
        Write-Verbose " [Remove-SplunkLicensePool] :: Parameters"
        Write-Verbose " [Remove-SplunkLicensePool] ::  - ParameterSet = $ParamSetName"
        Write-Verbose " [Remove-SplunkLicensePool] ::  - ComputerName = $ComputerName"
        Write-Verbose " [Remove-SplunkLicensePool] ::  - Port         = $Port"
        Write-Verbose " [Remove-SplunkLicensePool] ::  - Protocol     = $Protocol"
        Write-Verbose " [Remove-SplunkLicensePool] ::  - Timeout      = $Timeout"
        Write-Verbose " [Remove-SplunkLicensePool] ::  - Credential   = $Credential"
        Write-Verbose " [Remove-SplunkLicensePool] ::  - WhereFilter  = $WhereFilter"

		$Endpoint = '/services/licenser/pools/{0}' -f $PoolName;
		Write-Verbose " [Remove-SplunkLicensePool] ::  - Endpoint  = $Endpoint"
					
		if(-not( $Force -or $PSCmdlet.ShouldProcess($ComputerName,"Remove Splunk License Pool $PoolName")) )
		{
			return;
		}

			$Endpoint = '/services/licenser/pools/{0}' -f $PoolName;
			Write-Verbose " [Remove-SplunkLicensePool] ::  - Endpoint  = $Endpoint"
						
            Write-Verbose " [Remove-SplunkLicensePool] :: Setting up Invoke-APIRequest parameters"
            $InvokeAPIParams = @{
                ComputerName = $ComputerName
                Port         = $Port
				RequestType	 = 'DELETE'
                Protocol     = $Protocol
                Timeout      = $Timeout
                Credential   = $Credential
                Endpoint     = $Endpoint 
                Verbose      = $VerbosePreference -eq "Continue"
            }
                
            Write-Verbose " [Remove-SplunkLicensePool] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
		Write-Verbose " [Remove-SplunkLicensePool] :: Setting up Invoke-APIRequest parameters"
        $InvokeAPIParams = @{
            ComputerName = $ComputerName
            Port         = $Port
			RequestType	 = 'DELETE'
            Protocol     = $Protocol
            Timeout      = $Timeout
            Credential   = $Credential
            Endpoint     = $Endpoint 
            Verbose      = $VerbosePreference -eq "Continue"
        }
            
        Write-Verbose " [Remove-SplunkLicensePool] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
        
        try
        {
            [XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams
        }
        catch
        {
            Write-Verbose " [Remove-SplunkLicensePool] :: Invoke-SplunkAPIRequest threw an exception: $_"
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
                            PoolName     = $Entry.title
                            ID           = $Entry.link | Where-Object {$_.rel -eq "edit"} | Select-Object -expand href
                        }
                        Write-Verbose " [Remove-SplunkLicensePool] :: Creating Hash Table to be used to create Splunk.SDK.License.Pool"
                        switch ($Entry.content.dict.key)
                        {
                            {$_.name -eq "description"}           { $Myobj.Add("Description",$_.'#text')        ; continue }
                            {$_.name -eq "slaves_usage_bytes"}    { $Myobj.Add("SlavesUsageBytes",$_.'#text')   ; continue }
                            {$_.name -eq "stack_id"}              { $Myobj.Add("StackID",$_.'#text')            ; continue }
                            {$_.name -eq "used_bytes"}            { $Myobj.Add("UsedBytes",$_.'#text')          ; continue }
                        }
                        
                        # Creating Splunk.SDK.License.Pool
                        $obj = New-Object PSObject -Property $MyObj
                        $obj.PSTypeNames.Clear()
                        $obj.PSTypeNames.Add('Splunk.SDK.License.Pool')
                        $obj | Where-Object $WhereFilter
                    }
                }
                else
                {
                    Write-Verbose " [Remove-SplunkLicensePool] :: No Messages Found"
                }
                
            }
            else
            {
                Write-Verbose " [Remove-SplunkLicensePool] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
            }
        }
        catch
        {
            Write-Verbose " [Remove-SplunkLicensePool] :: Remove-SplunkLicensePool threw an exception: $_"
            Write-Error $_
		}
    
    }
    End 
    {
        Write-Verbose " [Remove-SplunkLicensePool] :: =========    End   ========="
    }
    
}   # Remove-SplunkLicensePool

#endregion Remove-SplunkLicensePool

#region Add-SplunkLicensePool

function Add-SplunkLicensePool
{
	<# .ExternalHelp ../Splunk-Help.xml #>
    [Cmdletbinding(SupportsShouldProcess=$true,ConfirmImpact='Low')]
    Param(

        [Alias('Name')]
        [Parameter(Mandatory=$true, Position=0)]
        [STRING]$PoolName,
		
		[Parameter(Mandatory=$true, Position=1)]
        [int]$Quota,
		
		[Parameter(Mandatory=$true, Position=2)]
		[ValidateSet('download-trial','enterprise','forwarder','free')]
        [string]$StackID,
		
		[Parameter()]
        [STRING]$Description,

		[Parameter()]
        [STRING[]]$Slave = $null,
		
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
        [System.Management.Automation.PSCredential]$Credential = ( get-splunkconnectionobject ).Credential,
        
        [Parameter()]
        [SWITCH]$Force
        
    )
    Begin 
    {

        Write-Verbose " [Add-SplunkLicensePool] :: Starting..."
    }
    Process 
    {

        Write-Verbose " [Add-SplunkLicensePool] :: Parameters"
        Write-Verbose " [Add-SplunkLicensePool] ::  - ComputerName = $ComputerName"
        Write-Verbose " [Add-SplunkLicensePool] ::  - Port         = $Port"
        Write-Verbose " [Add-SplunkLicensePool] ::  - Protocol     = $Protocol"
        Write-Verbose " [Add-SplunkLicensePool] ::  - Timeout      = $Timeout"
        Write-Verbose " [Add-SplunkLicensePool] ::  - Credential   = $Credential"
		Write-Verbose " [Add-SplunkLicensePool] ::  - PoolName	   = $PoolName"
		Write-Verbose " [Add-SplunkLicensePool] ::  - Quota		   = $Quota"
		Write-Verbose " [Add-SplunkLicensePool] ::  - Slaves	   = $Slaves"
		Write-Verbose " [Add-SplunkLicensePool] ::  - Description  = $Description"

		if($Force -or $PSCmdlet.ShouldProcess($ComputerName,"Adding Splunk License Pool $PoolName"))
		{
            Write-Verbose " [Add-SplunkLicensePool] :: Setting up Invoke-APIRequest parameters"
			
			$postArgs = @{
				name = $PoolName
				quota = $Quota
				stack_id = $StackID
			}
						
			if( $Slave )
			{
				$i = 0;
				$Slave | ForEach-Object { $postArgs.Add( "slaves",$_ ); ++$i }
			}
			
            $InvokeAPIParams = @{
                ComputerName = $ComputerName
                Port         = $Port
                Protocol     = $Protocol
                Timeout      = $Timeout
                Credential   = $Credential
				RequestType	 = 'POST'
				Arguments 	 = $postArgs
                Endpoint     = '/services/licenser/pools' 
                Verbose      = $VerbosePreference -eq "Continue"
            }
                
            Write-Verbose " [Add-SplunkLicensePool] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
            
            try
            {
                [XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams
            }
            catch
            {
                Write-Verbose " [Add-SplunkLicensePool] :: Invoke-SplunkAPIRequest threw an exception: $_"
                Write-Error $_
			}
            try
            {
				
                if($Results -and ($Results -is [System.Xml.XmlDocument]))
                {
                    Get-SplunkLicensePool -Poolname $PoolName
                    
                }
                else
                {
                    Write-Verbose " [Add-SplunkLicensePool] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
                }
            }
            catch
            {
                Write-Verbose " [Add-SplunkLicensePool] :: Add-SplunkLicensePool threw an exception: $_"
                Write-Error $_
			}
        }
    }
    End 
    {
        Write-Verbose " [Add-SplunkLicensePool] :: =========    End   ========="
    }
    
}   # Add-SplunkLicensePool

#endregion Add-SplunkLicensePool

#region Set-SplunkLicensePool

function Set-SplunkLicensePool
{
	<# .ExternalHelp ../Splunk-Help.xml #>
    [Cmdletbinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
    Param(
    
        [Alias('Name')]
		[Parameter(ValueFromPipelineByPropertyName=$true,Mandatory=$True)]
		[STRING]$PoolName,

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
        [INT64]$Quota,
        
        [Parameter()]
        [String]$Description,
        
        [Parameter()]
        [String]$Slaves,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential = ( get-splunkconnectionobject ).Credential,
        
        [Parameter()]
        [SWITCH]$Append,
        
        [Parameter()]
        [SWITCH]$Force
        
    )
    Begin
	{
		Write-Verbose " [Set-SplunkLicensePool] :: Starting..."
        
        $SetSplunkLicensePool = @{}
        
        switch -exact ($PSBoundParameters.Keys)
		{
			"Description"	{ $SetSplunkLicensePool.Add('description',$Description) }
			"Quota"	        { $SetSplunkLicensePool.Add('quota',$Quota) }
			"Slaves"		{ $SetSplunkLicensePool.Add('slaves',$Slaves) }
            "Append"		{ $SetSplunkLicensePool.Add('append_slaves',$Append) }
        }
	}
	Process
	{
		Write-Verbose " [Set-SplunkLicensePool] :: Parameters"
		Write-Verbose " [Set-SplunkLicensePool] ::  - ComputerName = $ComputerName"
		Write-Verbose " [Set-SplunkLicensePool] ::  - Port         = $Port"
		Write-Verbose " [Set-SplunkLicensePool] ::  - Protocol     = $Protocol"
		Write-Verbose " [Set-SplunkLicensePool] ::  - Timeout      = $Timeout"
		Write-Verbose " [Set-SplunkLicensePool] ::  - Credential   = $Credential"
        
        $EndPoint = "/services/licenser/pools/${PoolName}"
        Write-Verbose " [Set-SplunkLicensePool] ::  - Endpoint     = $EndPoint"
        
		Write-Verbose " [Set-SplunkLicensePool] :: Setting up Invoke-APIRequest parameters"
		$InvokeAPIParams = @{
			ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
			Endpoint     = $EndPoint
			Verbose      = $VerbosePreference -eq "Continue"
		}
        
        
		Write-Verbose " [Set-SplunkLicensePool] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
		try
		{
            if($Force -or $PSCmdlet.ShouldProcess($ComputerName,"Setting changes on $PoolName"))
			{
			    [XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams -Arguments $SetSplunkLicensePool -RequestType POST
            }
        }
        catch
		{
			Write-Verbose " [Set-SplunkLicensePool] :: Invoke-SplunkAPIRequest threw an exception: $_"
            Write-Error $_
		}
        try
        {
			if($Results -and ($Results -is [System.Xml.XmlDocument]))
			{
                Get-SplunkLicensePool -Name $PoolName
			}
			else
			{
				Write-Verbose " [Set-SplunkLicensePool] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
			}
		}
		catch
		{
			Write-Verbose " [Set-SplunkLicensePool] :: Set-SplunkLicensePool threw an exception: $_"
            Write-Error $_
		}
	}
	End
	{
		Write-Verbose " [Set-SplunkLicensePool] :: =========    End   ========="
	}

}    # Set-SplunkLicensePool

#endregion Set-SplunkLicensePool

#region Enable-SplunkLicenseGroup

function Enable-SplunkLicenseGroup
{
	<# .ExternalHelp ../Splunk-Help.xml #>	
    [Cmdletbinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
    Param(

		[Parameter(ValueFromPipelineByPropertyName=$true,Mandatory=$True)]
		[STRING]
		# the name of the group
		$GroupName,

        [Parameter()]
        [SWITCH]
		# specify to bypass standard PowerShell confirmation processes
		$Force,

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
		Write-Verbose " [Enable-SplunkLicenseGroup] :: Starting..."
	}
	Process
	{
		Write-Verbose " [Enable-SplunkLicenseGroup] :: Parameters"
		Write-Verbose " [Enable-SplunkLicenseGroup] ::  - ComputerName = $ComputerName"
		Write-Verbose " [Enable-SplunkLicenseGroup] ::  - Port         = $Port"
		Write-Verbose " [Enable-SplunkLicenseGroup] ::  - Protocol     = $Protocol"
		Write-Verbose " [Enable-SplunkLicenseGroup] ::  - Timeout      = $Timeout"
		Write-Verbose " [Enable-SplunkLicenseGroup] ::  - Credential   = $Credential"

		if(-not( $Force -or $PSCmdlet.ShouldProcess($ComputerName,"Setting active Splunk License Group to $GroupName")) )
		{
			return;
		}

		Write-Verbose " [Enable-SplunkLicenseGroup] :: Setting up Invoke-APIRequest parameters"
		$InvokeAPIParams = @{
			ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
			Endpoint     = "/services/licenser/groups/${GroupName}"
			Verbose      = $VerbosePreference -eq "Continue"
		}
        
        $GroupPostParam = @{
            is_active = 1
        }
        
		Write-Verbose " [Enable-SplunkLicenseGroup] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
		try
		{
            if($Force -or $PSCmdlet.ShouldProcess($ComputerName,"Setting Active Group to [$GroupName]"))
			{
			    [XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams -Arguments $GroupPostParam -RequestType POST
            }
        }
        catch
		{
			Write-Verbose " [Enable-SplunkLicenseGroup] :: Invoke-SplunkAPIRequest threw an exception: $_"
            Write-Error $_
		}
        try
        {
			if($Results -and ($Results -is [System.Xml.XmlDocument]))
			{
                Write-Host " [Enable-SplunkLicenseGroup] :: Please restart Splunkd"
                Get-SplunkLicenseGroup -Name $GroupName
			}
			else
			{
				Write-Verbose " [Enable-SplunkLicenseGroup] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
			}
		}
		catch
		{
			Write-Verbose " [Enable-SplunkLicenseGroup] :: Enable-SplunkLicenseGroup threw an exception: $_"
            Write-Error $_
		}
	}
	End
	{
		Write-Verbose " [Enable-SplunkLicenseGroup] :: =========    End   ========="
	}

}    # Enable-SplunkLicenseGroup

#endregion Enable-SplunkLicenseGroup

#region Get-SplunkLicenseSlave

function Get-SplunkLicenseSlave
{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[Cmdletbinding()]
    Param(
	
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
        [System.Management.Automation.PSCredential]$Credential = ( get-splunkconnectionobject ).Credential        
    )
	
	Begin
	{
		Write-Verbose " [Get-SplunkLicenseSlave] :: Starting..."
	}
	Process
	{
		Write-Verbose " [Get-SplunkLicenseSlave] :: Parameters"
		Write-Verbose " [Get-SplunkLicenseSlave] ::  - ComputerName = $ComputerName"
		Write-Verbose " [Get-SplunkLicenseSlave] ::  - Port         = $Port"
		Write-Verbose " [Get-SplunkLicenseSlave] ::  - Protocol     = $Protocol"
		Write-Verbose " [Get-SplunkLicenseSlave] ::  - Timeout      = $Timeout"
		Write-Verbose " [Get-SplunkLicenseSlave] ::  - Credential   = $Credential"

		$Endpoint = '/services/licenser/slaves'
        Write-Verbose " [Get-SplunkLicenseSlave] ::  - Endpoint   = $Endpoint"
        
		Write-Verbose " [Get-SplunkLicenseSlave] :: Setting up Invoke-APIRequest parameters"
		$InvokeAPIParams = @{
			ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
			Endpoint     = $Endpoint 
			Verbose      = $VerbosePreference -eq "Continue"
		}
			
		Write-Verbose " [Get-SplunkLicenseSlave] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
		try
		{
			[XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams
			if($Results -and ($Results -is [System.Xml.XmlDocument]))
			{
				foreach($Entry in $Results.feed.Entry)
				{
					$MyObj = @{}
                    $MyObj.Add('ComputerName',$ComputerName)
					$MyObj.Add('ID',$Entry.title)
					
					Write-Verbose " [Get-SplunkLicenseSlave] :: Creating Hash Table to be used to create Splunk.SDK.Splunk.Licenser.Slave"
					switch ($Entry.content.dict.key)
					{
			        	{$_.name -eq "pool_ids"}	    {$Myobj.Add("PoolIDs",$_.list.item);continue}
						{$_.name -eq "stack_ids"}	    {$Myobj.Add("StackIDs",$_.list.item);continue}
				        {$_.name -eq "label"}			{$Myobj.Add("SlaveName",$_.'#text');continue}
                        {$_.name -eq "warning_count"}	{$Myobj.Add("WarningCount",$_.'#text');continue}
					}
					
					# Creating Splunk.SDK.ServiceStatus
				    $obj = New-Object PSObject -Property $MyObj
				    $obj.PSTypeNames.Clear()
				    $obj.PSTypeNames.Add('Splunk.SDK.Splunk.Licenser.Slave')
				    $obj
				}
			}
			else
			{
				Write-Verbose " [Get-SplunkLicenseSlave] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
			}
		}
		catch
		{
			Write-Verbose " [Get-SplunkLicenseSlave] :: Invoke-SplunkAPIRequest threw an exception: $_"
            Write-Error $_
		}
	}
	End
	{
		Write-Verbose " [Get-SplunkLicenseSlave] :: =========    End   ========="
	}
} # Get-SplunkLicenseSlave

#endregion Get-SplunkLicenseSlave

#region Set-SplunkLicenseMaster

function Set-SplunkLicenseMaster
{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[Cmdletbinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
    Param(

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
        [System.Management.Automation.PSCredential]$Credential = ( get-splunkconnectionobject ).Credential,
        
        [Parameter()]
        [SWITCH]$Force
        
    )
    Begin
	{
		Write-Verbose " [Set-SplunkLicenseMaster] :: Starting..."
	}
	Process
	{		
		Write-Verbose " [Set-SplunkLicenseMaster] :: Parameters"
		Write-Verbose " [Set-SplunkLicenseMaster] ::  - ComputerName = $ComputerName"
		Write-Verbose " [Set-SplunkLicenseMaster] ::  - Port         = $Port"
		Write-Verbose " [Set-SplunkLicenseMaster] ::  - Protocol     = $Protocol"
		Write-Verbose " [Set-SplunkLicenseMaster] ::  - Timeout      = $Timeout"
		Write-Verbose " [Set-SplunkLicenseMaster] ::  - Credential   = $Credential"

		if(-not( $Force -or $PSCmdlet.ShouldProcess($ComputerName,"Setting Splunk License Master")) )
		{
			return;
		}

		Write-Verbose " [Set-SplunkLicenseMaster] :: Setting up Invoke-APIRequest parameters"
		$InvokeAPIParams = @{
			ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
			RequestType	 = 'POST'
			Arguments	 = @{ master_uri = 'self' }
			Endpoint     = "/services/licenser/localslave/license"
			Verbose      = $VerbosePreference -eq "Continue"
		}            
	
		Write-Verbose " [Set-SplunkLicenseMaster] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
		try
		{
        	[XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams 			
        }
        catch
		{
			Write-Verbose " [Set-SplunkLicenseMaster] :: Invoke-SplunkAPIRequest threw an exception: $_"
            Write-Error $_
		}
        try
        {
			if($Results -and ($Results -is [System.Xml.XmlDocument]))
			{
                Write-Host " [Set-SplunkLicenseMaster] :: Please restart Splunkd"                
			}
			else
			{
				Write-Verbose " [Set-SplunkLicenseMaster] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
			}
		}
		catch
		{
			Write-Verbose " [Set-SplunkLicenseMaster] :: Set-SplunkLicenseMaster threw an exception: $_"
            Write-Error $_
		}
	}
	End
	{
		Write-Verbose " [Set-SplunkLicenseMaster] :: =========    End   ========="
	}

}    # Set-SplunkLicenseMaster

#endregion Set-SplunkLicenseMaster

#region Get-SplunkLicenseMaster

function Get-SplunkLicenseMaster
{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[Cmdletbinding()]
    Param(
	
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
        [System.Management.Automation.PSCredential]$Credential = ( get-splunkconnectionobject ).Credential        
    )
	
	Begin
	{
		Write-Verbose " [Get-SplunkLicenseMaster] :: Starting..."
	}
	Process
	{
		Write-Verbose " [Get-SplunkLicenseMaster] :: Parameters"
		Write-Verbose " [Get-SplunkLicenseMaster] ::  - ComputerName = $ComputerName"
		Write-Verbose " [Get-SplunkLicenseMaster] ::  - Port         = $Port"
		Write-Verbose " [Get-SplunkLicenseMaster] ::  - Protocol     = $Protocol"
		Write-Verbose " [Get-SplunkLicenseMaster] ::  - Timeout      = $Timeout"
		Write-Verbose " [Get-SplunkLicenseMaster] ::  - Credential   = $Credential"

		$Endpoint = '/services/licenser/localslave'
        Write-Verbose " [Get-SplunkLicenseMaster] ::  - Endpoint   = $Endpoint"
        
		Write-Verbose " [Get-SplunkLicenseMaster] :: Setting up Invoke-APIRequest parameters"
		$InvokeAPIParams = @{
			ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
			Endpoint     = $Endpoint 
			Verbose      = $VerbosePreference -eq "Continue"
		}
			
		Write-Verbose " [Get-SplunkLicenseMaster] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
		try
		{
			[XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams
			#$Results.outerxml | out-host
			if($Results -and ($Results -is [System.Xml.XmlDocument]))
			{
				foreach($Entry in $Results.feed.Entry)
				{
					$MyObj = @{}
                    $MyObj.Add('ComputerName',$ComputerName)
					$MyObj.Add('ID',$Entry.title)
					$MyObj.Add('Title',$Entry.title)
					
					Write-Verbose " [Get-SplunkLicenseMaster] :: Creating Hash Table to be used to create Splunk.SDK.Splunk.Licenser.LocalSlave"
					switch ($Entry.content.dict.key)
					{
			        	{$_.name -eq "last_master_contact_attempt_time"}	{$Myobj.Add("LastContactAttempt",(ConvertFrom-UnixTime $_.'#text'));continue}
						{$_.name -eq "last_master_contact_success_time"}	{$Myobj.Add("LastContactSuccess",(ConvertFrom-UnixTime $_.'#text'));continue}
				        {$_.name -eq "master_guid"}		                    {$Myobj.Add("MasterGUID",$_.'#text');continue}
						{$_.name -eq "master_uri"}			                {$Myobj.Add("MasterURI",$_.'#text');continue}
                        {$_.name -eq "license_keys"}			            {$Myobj.Add("LicenseKeys",$_.list.item);continue}
                        {$_.name -eq "receive_timeout"}			            {$Myobj.Add("ReceiveTimeout",$_.'#text');continue}
                        {$_.name -eq "send_timeout"}			            {$Myobj.Add("SendTimeout",$_.'#text');continue}
                        {$_.name -eq "slave_id"}			                {$Myobj.Add("SlaveID",$_.'#text');continue}
                        {$_.name -eq "slave_label"}			                {$Myobj.Add("SlaveName",$_.'#text');continue}
                        {$_.name -eq "last_trackerdb_service_time"}		    {$Myobj.Add("LastTrackerDBServiceTime",$_.'#text');continue}
					}
					
					# Creating Splunk.SDK.ServiceStatus
				    $obj = New-Object PSObject -Property $MyObj
				    $obj.PSTypeNames.Clear()
				    $obj.PSTypeNames.Add('Splunk.SDK.Splunk.Licenser.LocalSlave')
				    $obj
				}
			}
			else
			{
				Write-Verbose " [Get-SplunkLicenseMaster] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
			}
		}
		catch
		{
			Write-Verbose " [Get-SplunkLicenseMaster] :: Invoke-SplunkAPIRequest threw an exception: $_"
            Write-Error $_
		}
	}
	End
	{
		Write-Verbose " [Get-SplunkLicenseMaster] :: =========    End   ========="
	}
} # Get-SplunkLicenseMaster

#endregion Splunk License




