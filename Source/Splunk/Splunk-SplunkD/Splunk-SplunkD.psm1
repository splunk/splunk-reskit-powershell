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

#region SplunkD

#region Get-Splunkd

function Get-Splunkd
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
		Write-Verbose " [Get-Splunkd] :: Starting..."
	}
	Process
	{
		Write-Verbose " [Get-Splunkd] :: Parameters"
		Write-Verbose " [Get-Splunkd] ::  - ComputerName = $ComputerName"
		Write-Verbose " [Get-Splunkd] ::  - Port         = $Port"
		Write-Verbose " [Get-Splunkd] ::  - Protocol     = $Protocol"
		Write-Verbose " [Get-Splunkd] ::  - Timeout      = $Timeout"
		Write-Verbose " [Get-Splunkd] ::  - Credential   = $Credential"

		Write-Verbose " [Get-Splunkd] :: Setting up Invoke-APIRequest parameters"
		$InvokeAPIParams = @{
			ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
			Endpoint     = '/services/server/settings' 
			Verbose      = $VerbosePreference -eq "Continue"
		}
			
		Write-Verbose " [Get-Splunkd] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
		try
		{
			[XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams
        }
        catch
		{
			Write-Verbose " [Get-Splunkd] :: Invoke-SplunkAPIRequest threw an exception: $_"
            Write-Error $_		
		}
        try
        {
			if($Results -and ($Results -is [System.Xml.XmlDocument]))
			{
				$MyObj = @{}
				Write-Verbose " [Get-Splunkd] :: Creating Hash Table to be used to create Splunk.SDK.Splunkd"
				switch ($results.feed.entry.content.dict.key)
				{
		        	{$_.name -eq "SPLUNK_DB"}		    {$Myobj.Add("Splunk_DB",$_.'#text');continue}
		        	{$_.name -eq "SPLUNK_HOME"}		    {$Myobj.Add("Splunk_Home",$_.'#text');continue}
					{$_.name -eq "enableSplunkWebSSL"}	{$Myobj.Add("EnableWebSSL",[bool]($_.'#text'));continue}
			        {$_.name -eq "serverName"}			{$Myobj.Add("ComputerName",$_.'#text');continue}
					{$_.name -eq "host"}				{$Myobj.Add("DefaultHostName",$_.'#text');continue}
			        {$_.name -eq "httpport"}			{$Myobj.Add("HTTPPort",$_.'#text');continue}
			        {$_.name -eq "mgmtHostPort"}		{$Myobj.Add("MgmtPort",$_.'#text');continue}
			        {$_.name -eq "minFreeSpace"}		{$Myobj.Add("MinFreeSpace",$_.'#text');continue}
			        {$_.name -eq "sessionTimeout"}		{$Myobj.Add("SessionTimeout",$_.'#text');continue}
			        {$_.name -eq "startwebserver"}		{$Myobj.Add("EnableWeb",[bool]($_.'#text'));continue}
			        {$_.name -eq "trustedIP"}			{$Myobj.Add("TrustedIP",$_.'#text');continue}
				}
			}
			else
			{
				Write-Verbose " [Get-Splunkd] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
			}
            
            Write-Verbose " [Get-Splunkd] :: Setting up Invoke-APIRequest parameters"
    		$InvokeAPIParams = @{
    			ComputerName = $ComputerName
    			Port         = $Port
    			Protocol     = $Protocol
    			Timeout      = $Timeout
    			Credential   = $Credential
    			Endpoint     = '/services/server/info/server-info' 
    			Verbose      = $VerbosePreference -eq "Continue"
    		}
			
			[XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams
			if($Results -and ($Results -is [System.Xml.XmlDocument]))
			{
				Write-Verbose " [Get-Splunkd] :: Creating Hash Table to be used to create Splunk.SDK.Splunkd"
				switch ($results.feed.entry.content.dict.key)
				{
		        	{$_.name -eq "build"}		    	{$Myobj.Add("Build",$_.'#text');continue}
		        	{$_.name -eq "cpu_arch"}		    {$Myobj.Add("CPU_Arch",$_.'#text');continue}
					{$_.name -eq "GUID"}				{$Myobj.Add("GUID",$_.'#text');continue}
			        {$_.name -eq "isFree"}				{$Myobj.Add("IsFree",[bool]($_.'#text'));continue}
					{$_.name -eq "isTrial"}				{$Myobj.Add("IsTrial",[bool]($_.'#text'));continue}
			        {$_.name -eq "mode"}				{$Myobj.Add("Mode",$_.'#text');continue}
			        {$_.name -eq "os_build"}			{$Myobj.Add("OSBuild",$_.'#text');continue}
			        {$_.name -eq "os_name"}				{$Myobj.Add("OSName",$_.'#text');continue}
			        {$_.name -eq "os_version"}			{$Myobj.Add("OSVersion",$_.'#text');continue}
			        {$_.name -eq "version"}				{$Myobj.Add("Version",$_.'#text');continue}
				}
				
				# Creating Splunk.SDK.ServiceStatus
			    $obj = New-Object PSObject -Property $MyObj
			    $obj.PSTypeNames.Clear()
			    $obj.PSTypeNames.Add('Splunk.SDK.Splunkd')
			    $obj
			}
			else
			{
				Write-Verbose " [Get-SplunkdVersion] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
			}
		}
		catch
		{
			Write-Verbose " [Get-Splunkd] :: Get-Splunkd threw an exception: $_"
            Write-Error $_		
		}
	}
	End
	{
		Write-Verbose " [Get-Splunkd] :: =========    End   ========="
	}
} # Get-Splunkd

#endregion Get-Splunkd

#region Test-Splunkd

function Test-Splunkd
{

	<# .ExternalHelp ../Splunk-Help.xml #>
	
	[Cmdletbinding(SupportsShouldProcess=$true)]
    Param(
	
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]$ComputerName = ( get-splunkconnectionobject ).ComputerName,
        
        [Parameter()]
        [int]$Port            = ( get-splunkconnectionobject ).Port,
        
        [Parameter()]
        [STRING]$Protocol     = ( get-splunkconnectionobject ).Protocol,
        
        [Parameter()]
        [int]$Timeout         = ( get-splunkconnectionobject ).Timeout,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential = ( get-splunkconnectionobject ).Credential,
		
		[Parameter()]
		[SWITCH]$Native
        
    )
	Begin
	{
		Write-Verbose " [Test-Splunkd] :: Starting..."
	}
	Process
	{
	
		Write-Verbose " [Test-Splunkd] :: Parameters"
		Write-Verbose " [Test-Splunkd] ::  - ComputerName = $ComputerName"
		Write-Verbose " [Test-Splunkd] ::  - Port         = $Port"
		Write-Verbose " [Test-Splunkd] ::  - Protocol     = $Protocol"
		Write-Verbose " [Test-Splunkd] ::  - Timeout      = $Timeout"
		Write-Verbose " [Test-Splunkd] ::  - Credential   = $Credential"
		Write-Verbose " [Test-Splunkd] ::  - Native       = $Native"
		
		if( -not $pscmdlet.ShouldProcess( $ComputerName, "Testing Splunk Connection" ) )
		{
			return;
		}

		$Results = Get-Splunkd @PSBoundParameters
		
		if($Results)
		{
			if($_)
			{
				$_			
			}
			else
			{
				$True
			}
		}
		else
		{
			if($_)
			{
				
			}
			else
			{
				$False
			}
		}
	}
	End
	{
		Write-Verbose " [Test-Splunkd] :: =========    End   ========="
	}
} # Test-Splunkd

#endregion Test-Splunkd

#region Set-Splunkd

#region Set-Splunkd

function Set-Splunkd
{

	<# .ExternalHelp ../Splunk-Help.xml #>

	[Cmdletbinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
    Param(
	
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]$ComputerName = ( get-splunkconnectionobject ).ComputerName,
        
        [Parameter()]
        [int]$Port            = ( get-splunkconnectionobject ).Port,
        
        [Parameter()]
        [STRING]$Protocol     = ( get-splunkconnectionobject ).Protocol,
        
        [Parameter()]
        [INT]$Timeout         = ( get-splunkconnectionobject ).Timeout,
		
		[Parameter()]
		[STRING]$ServerName,
		
		[Parameter()]
		[STRING]$DefaultHostName,
		
		[Parameter()]
		[INT]$MangementPort,
		
		[Parameter()]
		[STRING]$SSOTrustedIP,
		
		[Parameter()]
		[INT]$WebPort,
		
		[Parameter()]
		[STRING]$SessionTimeout,
		
		[Parameter()]
		[STRING]$IndexPath,
		
		[Parameter()]
		[INT]$MinFreeSpace,
		
#		[Parameter()]
#		[SWITCH]$EnableWeb,
#		
#		[Parameter()]
#		[SWITCH]$EnableSSL,
		
        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential = ( get-splunkconnectionobject ).Credential,
		
		[Parameter()]
		[SWITCH]$Force,
		
		[Parameter()]
		[SWITCH]$Restart
        
    )
	
	Begin
	{	
		$SetSplunkDParams = @{}
		Write-Verbose " [Set-Splunkd] :: Starting..."
		switch -exact ($PSBoundParameters.Keys)
		{
			"ServerName"		{$SetSplunkDParams.Add('serverName',$ServerName)}
			"DefaultHostName"	{$SetSplunkDParams.Add('host',$DefaultHostName)}
			"MangementPort"		{$SetSplunkDParams.Add('mgmtHostPort',$MangementPort)}
			"SSOTrustedIP"		{$SetSplunkDParams.Add('trustedIP',$SSOTrustedIP)}
			"WebPort"			{$SetSplunkDParams.Add('httpport',$WebPort)}
			"SessionTimeout"	{$SetSplunkDParams.Add('sessionTimeout',$SessionTimeout)}
			"IndexPath"			{$SetSplunkDParams.Add('SPLUNK_DB',$IndexPath)}
			"MinFreeSpace"		{$SetSplunkDParams.Add('minFreeSpace',$MinFreeSpace)}
			#"EnableWeb"			{$SetSplunkDParams.Add('startwebserver',$EnableWeb)}
			#"EnableSSL"			{$SetSplunkDParams.Add('enableSplunkWebSSL',$EnableSSL)}
		}
	}
	
	Process
	{
		Write-Verbose " [Set-Splunkd] :: Parameters"
		Write-Verbose " [Set-Splunkd] ::  - ComputerName = $ComputerName"
		Write-Verbose " [Set-Splunkd] ::  - Port         = $Port"
		Write-Verbose " [Set-Splunkd] ::  - Protocol     = $Protocol"
		Write-Verbose " [Set-Splunkd] ::  - Timeout      = $Timeout"
		Write-Verbose " [Set-Splunkd] ::  - Credential   = $Credential"

		Write-Verbose " [Set-Splunkd] :: Setting up Invoke-APIRequest parameters"
		$InvokeAPIParams = @{
			ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
			Endpoint     = '/services/server/settings/settings' 
			Verbose      = $VerbosePreference -eq "Continue"
		}
			
		Write-Verbose " [Set-Splunkd] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
		if($Force -or $PSCmdlet.ShouldProcess($ComputerName,"Setting Splunkd Settings"))
		{
			[XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams -Arguments $SetSplunkDParams -RequestType POST
			if($Results)
			{
				Write-Verbose " [Set-Splunkd] :: Creating HASH table to be used for parameters for Get-Splunkd"
				$GetSplunkd = @{
					ComputerName = $ComputerName
					Port         = $Port
					Protocol     = $Protocol
					Timeout      = $Timeout
					Credential   = $Credential
					Verbose      = $VerbosePreference -eq "Continue"
				}
				Get-Splunkd @GetSplunkd
				if($Restart)
				{
					Restart-SplunkService @GetSplunkd -Force
				}
			}
			else
			{
				Write-Verbose " [Set-Splunkd] ::  No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
			}
		}
	}
	End
	{
		Write-Verbose " [Set-Splunkd] :: =========    End   ========="
	}
} # Set-Splunkd

#endregion Set-Splunkd

#endregion Set-Splunkd

#region Restart-SplunkService

function Restart-SplunkService
{

	<# .ExternalHelp ../Splunk-Help.xml #>
	
	[Cmdletbinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
    Param(
	
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]$ComputerName = ( get-splunkconnectionobject ).ComputerName,
        
        [Parameter()]
        [int]$Port            = ( get-splunkconnectionobject ).Port,
        
        [Parameter()]
        [STRING]$Protocol     = ( get-splunkconnectionobject ).Protocol,
        
        [Parameter()]
        [int]$Timeout         = ( get-splunkconnectionobject ).Timeout,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential = ( get-splunkconnectionobject ).Credential,
		
		[Parameter()]
		[SWITCH]$Force,
		
		[Parameter()]
		[SWITCH]$Wait,
		
		[Parameter()]
		[SWITCH]$Native
        
    )
	Begin
	{
		Write-Verbose " [Restart-SplunkService] :: Starting..."
	}
	Process
	{
		Write-Verbose " [Restart-SplunkService] :: Parameters"
		Write-Verbose " [Restart-SplunkService] ::  - ComputerName = $ComputerName"
		Write-Verbose " [Restart-SplunkService] ::  - Port         = $Port"
		Write-Verbose " [Restart-SplunkService] ::  - Protocol     = $Protocol"
		Write-Verbose " [Restart-SplunkService] ::  - Timeout      = $Timeout"
		Write-Verbose " [Restart-SplunkService] ::  - Credential   = $Credential"

		Write-Verbose " [Restart-SplunkService] :: Setting up Invoke-APIRequest parameters"
		$InvokeAPIParams = @{
			ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
			Endpoint     = '/services/server/control/restart' 
			Verbose      = $VerbosePreference -eq "Continue"
		}

		if($Force -or $PSCmdlet.ShouldProcess($ComputerName,"Restarting Splunk Services"))
	    {
			if($Native)
			{
				Write-Error "Not Implemented Yet" -ErrorAction Stop
			}
			else
			{
		        Write-Verbose " [Restart-SplunkService] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
				[XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams 
				Write-Host "Restarting Splunk services on $ComputerName, Please wait..."
				if($Results -and $Wait)
				{
					while($true)
					{
						sleep 3
                        $GetSplunkdParams = @{
                			ComputerName = $ComputerName
                			Port         = $Port
                			Protocol     = $Protocol
                			Timeout      = $Timeout
                			Credential   = $Credential
                			Verbose      = $VerbosePreference -eq "Continue"
                		}
						$SplunkD = Get-Splunkd @GetSplunkdParams -ErrorAction SilentlyContinue
						if($SplunkD -and $splunkd.computername)
						{
							return $SplunkD
						}
					}
				}
			}
	    }
	}
	End
	{
		Write-Verbose " [Restart-SplunkService] :: =========    End   ========="
	}
} # Restart-SplunkService

#endregion Restart-SplunkService

#region Get-SplunkdVersion

function Get-SplunkdVersion
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
		Write-Verbose " [Get-SplunkdVersion] :: Starting..."
	}
	Process
	{
		Write-Verbose " [Get-SplunkdVersion] :: Parameters"
		Write-Verbose " [Get-SplunkdVersion] ::  - ComputerName = $ComputerName"
		Write-Verbose " [Get-SplunkdVersion] ::  - Port         = $Port"
		Write-Verbose " [Get-SplunkdVersion] ::  - Protocol     = $Protocol"
		Write-Verbose " [Get-SplunkdVersion] ::  - Timeout      = $Timeout"
		Write-Verbose " [Get-SplunkdVersion] ::  - Credential   = $Credential"

		Write-Verbose " [Get-SplunkdVersion] :: Setting up Invoke-APIRequest parameters"
		$InvokeAPIParams = @{
			ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
			Endpoint     = '/services/server/info/server-info' 
			Verbose      = $VerbosePreference -eq "Continue"
		}
			
		Write-Verbose " [Get-SplunkdVersion] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
		try
		{
			[XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams
			if($Results -and ($Results -is [System.Xml.XmlDocument]))
			{
				$MyObj = @{}
				$MyObj.Add("ComputerName",$ComputerName)
				Write-Verbose " [Get-SplunkdVersion] :: Creating Hash Table to be used to create Splunk.SDK.ServiceStatus"
				switch ($results.feed.entry.content.dict.key)
				{
		        	{$_.name -eq "build"}		    	{$Myobj.Add("Build",$_.'#text');continue}
		        	{$_.name -eq "cpu_arch"}		    {$Myobj.Add("CPU_Arch",$_.'#text');continue}
					{$_.name -eq "GUID"}				{$Myobj.Add("GUID",$_.'#text');continue}
			        {$_.name -eq "isFree"}				{$Myobj.Add("IsFree",[bool]($_.'#text'));continue}
					{$_.name -eq "isTrial"}				{$Myobj.Add("IsTrial",[bool]($_.'#text'));continue}
			        {$_.name -eq "mode"}				{$Myobj.Add("Mode",$_.'#text');continue}
			        {$_.name -eq "os_build"}			{$Myobj.Add("OSBuild",$_.'#text');continue}
			        {$_.name -eq "os_name"}				{$Myobj.Add("OSName",$_.'#text');continue}
			        {$_.name -eq "os_version"}			{$Myobj.Add("OSVersion",$_.'#text');continue}
			        {$_.name -eq "version"}				{$Myobj.Add("Version",$_.'#text');continue}
				}
				
				# Creating Splunk.SDK.ServiceStatus
			    $obj = New-Object PSObject -Property $MyObj
			    $obj.PSTypeNames.Clear()
			    $obj.PSTypeNames.Add('Splunk.SDK.Splunkd.VersionInfo')
			    $obj
			}
			else
			{
				Write-Verbose " [Get-SplunkdVersion] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
			}
		}
		catch
		{
			Write-Verbose " [Get-SplunkdVersion] :: Invoke-SplunkAPIRequest threw an exception: $_"
            Write-Error $_		
		}
	}
	End
	{
		Write-Verbose " [Get-SplunkdVersion] :: =========    End   ========="
	}
} # Get-SplunkdVersion

#endregion Get-SplunkdVersion

#region Get-SplunkdLogging

function Get-SplunkdLogging
{

	<# .ExternalHelp ../Splunk-Help.xml #>
	
	[Cmdletbinding(DefaultParameterSetName="byFilter")]
    Param(
    
        [Parameter(Position=0,ParameterSetName="byFilter")]
        [STRING]$Filter = '.*',
	
		[Parameter(Position=0,ParameterSetName="byName")]
		[STRING]$Name,
        
        [Parameter()]        
        [ValidateSet("WARN" , "DEBUG" , "INFO" , "CRIT" , "ERROR" , "FATAL")]
		[STRING]$Level,
	
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
		Write-Verbose " [Get-SplunkdLogging] :: Starting..."
        $ParamSetName = $pscmdlet.ParameterSetName
        
        Write-Verbose " [Get-SplunkdLogging] :: Creating Level Filter"
        $LevelFilter = { if($Level){ $_.Level -eq $Level } else { $true } }
        
        switch ($ParamSetName)
        {
            "byFilter"  { $WhereFilter = { $_.Name -match $Filter } } 
            "byName"    { $WhereFilter = { $_.Name -eq    $Name } }
        }
        
	}
	Process
	{
		Write-Verbose " [Get-SplunkdLogging] :: Parameters"
        Write-Verbose " [Get-SplunkdLogging] ::  - ParameterSet = $ParamSetName"
		Write-Verbose " [Get-SplunkdLogging] ::  - ComputerName = $ComputerName"
		Write-Verbose " [Get-SplunkdLogging] ::  - Port         = $Port"
		Write-Verbose " [Get-SplunkdLogging] ::  - Protocol     = $Protocol"
		Write-Verbose " [Get-SplunkdLogging] ::  - Timeout      = $Timeout"
		Write-Verbose " [Get-SplunkdLogging] ::  - Credential   = $Credential"
        Write-Verbose " [Get-SplunkdLogging] ::  - LevelFilter  = $LevelFilter"
        Write-Verbose " [Get-SplunkdLogging] ::  - WhereFilter  = $WhereFilter"

		Write-Verbose " [Get-SplunkdLogging] :: Setting up Invoke-APIRequest parameters"
		$InvokeAPIParams = @{
			ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
			Endpoint     = '/services/server/logger?count=-1' 
			Verbose      = $VerbosePreference -eq "Continue"
		}
			
		Write-Verbose " [Get-SplunkdLogging] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
		try
		{
			[XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams 
			if($Results -and ($Results -is [System.Xml.XmlDocument]))
			{
				foreach($Entry in $Results.Feed.Entry)
				{
                    Write-Verbose " [Get-SplunkdLogging] :: Creating Hash Table to be used to create Splunk.SDK.Splunkd.Logger"
					$MyObj = @{}
					$MyObj.Add('Name',$Entry.Title)
                    $MyObj.Add('ComputerName',$ComputerName)
					$MyObj.Add('ServiceURL',$Entry.link[0].href)
					switch ($Entry.content.dict.key)
					{
			        	{$_.name -eq "level"}		    { $Myobj.Add("Level",$_.'#text') ; continue }
					}
					
					# Creating Splunk.SDK.ServiceStatus
				    $obj = New-Object PSObject -Property $MyObj
				    $obj.PSTypeNames.Clear()
				    $obj.PSTypeNames.Add('Splunk.SDK.Splunkd.Logger')
                    $obj | Where-Object $WhereFilter | Where-Object $LevelFilter
				}
			}
			else
			{
				Write-Verbose " [Get-SplunkdLogging] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
			}
		}
		catch
		{
			Write-Verbose " [Get-SplunkdLogging] :: Invoke-SplunkAPIRequest threw an exception: $_"
            Write-Error $_
		}
	}
	End
	{
		Write-Verbose " [Get-SplunkdLogging] :: =========    End   ========="
	}
} # Get-SplunkdLogging

#endregion Get-SplunkdLogging

#region Set-SplunkdLogging

function Set-SplunkdLogging # Need to note Change does not persist service restart
{
	<# .ExternalHelp ../Splunk-Help.xml #>

	[Cmdletbinding(SupportsShouldProcess=$true,DefaultParameterSetName="byFilter")]
    Param(
    
		[Parameter(ValueFromPipeline=$true,Position=0,ParameterSetName="byLogger")]
		[Object]$Logger,
		
        [Parameter(Position=0,ParameterSetName="byFilter")]
        [STRING]$Filter = '.*',
	
		[Parameter(Position=0,ParameterSetName="byName")]
		[STRING]$Name,
        
        [Parameter()]        
        [ValidateSet("WARN" , "DEBUG" , "INFO" , "CRIT" , "ERROR" , "FATAL")]
		[STRING]$NewLevel,
	
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
		Write-Verbose " [Set-SplunkdLogging] :: Starting..."
        $ParamSetName = $pscmdlet.ParameterSetName
        
        switch ($ParamSetName)
        {
            "byFilter"  { $LoggerObjects = Get-SplunkdLogging -Filter $Filter	} 
            "byName"    { $LoggerObjects = Get-SplunkdLogging -Name $Name 		}
        }
        
	}
	Process
	{
		Write-Verbose " [Set-SplunkdLogging] :: Parameters"
        Write-Verbose " [Set-SplunkdLogging] ::  - ParameterSet = $ParamSetName"
		Write-Verbose " [Set-SplunkdLogging] ::  - ComputerName = $ComputerName"
		Write-Verbose " [Set-SplunkdLogging] ::  - Port         = $Port"
		Write-Verbose " [Set-SplunkdLogging] ::  - Protocol     = $Protocol"
		Write-Verbose " [Set-SplunkdLogging] ::  - Timeout      = $Timeout"
		Write-Verbose " [Set-SplunkdLogging] ::  - Credential   = $Credential"
        Write-Verbose " [Set-SplunkdLogging] ::  - LevelFilter  = $LevelFilter"
        Write-Verbose " [Set-SplunkdLogging] ::  - WhereFilter  = $WhereFilter"

		if($Logger -and $Logger.PSTypeNames -contains "Splunk.SDK.Splunkd.Logger")
		{
			$LoggerObjects = $Logger
		}
		
		foreach($LoggerObject in $LoggerObjects)
		{
			Write-Verbose " [Set-SplunkdLogging] :: Setting up Invoke-APIRequest parameters"
			$InvokeAPIParams = @{
				ComputerName = $ComputerName
				Port         = $Port
				Protocol     = $Protocol
				Timeout      = $Timeout
				Credential   = $Credential
				Endpoint     = $LoggerObject.ServiceURL
				Verbose      = $VerbosePreference -eq "Continue"
			}
			$Arguments = @{"level"=$NewLevel}
			
            Write-Verbose " [Set-SplunkdLogging] :: Using endpoint $($LoggerObject.ServiceURL)"
			Write-Verbose " [Set-SplunkdLogging] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
			try
			{
				if($Force -or $PSCmdlet.ShouldProcess($ComputerName,"Setting Splunkd Logging [$($LoggerObject.Name)] to [$NewLevel]"))
				{
					[XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams -Arguments $Arguments -RequestType POST
					if($Results -and ($Results -is [System.Xml.XmlDocument]))
					{
						Get-SplunkdLogging -Name $LoggerObject.Name
					}
					else
					{
						Write-Verbose " [Set-SplunkdLogging] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
					}
				}
			}
			catch
			{
				Write-Verbose " [Set-SplunkdLogging] :: Invoke-SplunkAPIRequest threw an exception: $_"
                Write-Error $_
			}
		}
	}
	End
	{
		Write-Verbose " [Set-SplunkdLogging] :: =========    End   ========="
	}
} # Set-SplunkdLogging

#endregion Set-SplunkdLogging

#endregion SplunkD

