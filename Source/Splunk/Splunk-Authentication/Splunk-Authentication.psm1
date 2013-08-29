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

#region Authentication

#region New-SplunkCredential

# Helper function to Get and Store Credentials to be used against the Splunk API
function New-SplunkCredential
{
	<# .ExternalHelp ../Splunk-Help.xml #>

    Param(
        [Parameter()]
        [STRING]$UserName
    )
    
    if(!$UserName)
    {
        # If no UserName is provided we create the PSCredential object using Get-Credential
        # http://msdn.microsoft.com/en-us/library/system.management.automation.pscredential(VS.85).aspx
        Get-Credential
    }
    else
    {
        # Prompt User for Passord and store securely in a SecureString
        # http://msdn.microsoft.com/en-us/library/system.security.securestring.aspx
        $SecurePassword = Read-Host "Password" -AsSecureString
        
        # Create and Return a PSCredential Object
        # http://msdn.microsoft.com/en-us/library/system.management.automation.pscredential(VS.85).aspx
        New-Object System.Management.Automation.PSCredential($UserName,$SecurePassword)
    }
}    # New-SplunkCredential

#endregion New-SplunkCredential

#region Connect-Splunk

# Creates a Splunk.Connection object. This can be used to create a default context for cmdlets to use.
function Connect-Splunk
{
	<# .ExternalHelp ../Splunk-Help.xml #>
    [Cmdletbinding(SupportsShouldProcess=$true,ConfirmImpact='None',DefaultParameterSetName="byCredentials")]
    Param(
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0)]
        [String]$ComputerName,
        
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [int]$Port = 8089, 
        
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [STRING]$Protocol = "https", 
        
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [INT]$Timeout = 10000, 
        
        [Parameter(Mandatory=$true,ParameterSetName="byCredentials", ValueFromPipelineByPropertyName=$true)]
        [System.Management.Automation.PSCredential]$Credential,
        
        [Parameter(Mandatory=$true,ParameterSetName="byUserName")]
        [STRING]$UserName,
		
		[Parameter()]
        [Switch]$Passthru 
    )
	
    Write-Verbose " [Connect-Splunk] :: Starting..."
    Write-Verbose " [Connect-Splunk] :: Checking ParameterSet"
    Write-Verbose " [Connect-Splunk] :: Using [$($pscmdlet.ParameterSetName)] ParameterSet."
	
	if( -not $pscmdlet.ShouldProcess( $ComputerName, "Connecting to port $Port using protocol $Protocol with timeout $Timeout (ms)" ) )
	{
		return;
	}
	
    switch ($pscmdlet.ParameterSetName)
    {
        "byCredentials"     {
								Write-Verbose " [Connect-Splunk] :: Parameters"
								Write-Verbose " [Connect-Splunk] ::  - ComputerName = $ComputerName"
								Write-Verbose " [Connect-Splunk] ::  - Port         = $Port"
								Write-Verbose " [Connect-Splunk] ::  - Protocol     = $Protocol"
								Write-Verbose " [Connect-Splunk] ::  - Timeout      = $Timeout"
								Write-Verbose " [Connect-Splunk] ::  - Credential   = $Credential"
                                $MyCredential = $Credential
                                
                                # Setting $AuthUser to be stored in Splunk.Connection Object (removing preceeding \)
                                $AuthUser = $MyCredential.UserName -replace "^\\(.*)",'$1'
                            }
        "byUserName"        {
								Write-Verbose " [Connect-Splunk] :: Parameters"
								Write-Verbose " [Connect-Splunk] ::  - ComputerName = $ComputerName"
								Write-Verbose " [Connect-Splunk] ::  - Port         = $Port"
								Write-Verbose " [Connect-Splunk] ::  - Protocol     = $Protocol"
								Write-Verbose " [Connect-Splunk] ::  - Timeout      = $Timeout"
								Write-Verbose " [Connect-Splunk] ::  - UserName     = $UserName"
                                Write-Verbose " [Connect-Splunk] :: Creating a PSCredential object using [$UserName]"
                                $MyCredential = New-SplunkCredential -UserName $UserName
                                
                                # Setting $AuthUser to be stored in Splunk.Connection Object
                                $AuthUser = $UserName
                            }
    }

    Write-Verbose " [Connect-Splunk] :: Creating a hash table for the Parameters to pass to Get-SplunkAuthToken"
    $GetSplunkAuthTokenParams = @{
        ComputerName = $ComputerName
        Port         = $Port
        Timeout      = $Timeout
        Credential   = $MyCredential
        Protocol     = $Protocol
		Verbose      = $VerbosePreference -eq "Continue"
    }
	
	$AuthTokenObject = Get-SplunkAuthToken @GetSplunkAuthTokenParams
    
    # Creating Hash Table to be used to create Splunk.Connection
    $MyObj = @{
        ComputerName = $ComputerName
        Port         = $Port
        Timeout      = $Timeout
        Protocol     = $Protocol
        UserName     = $AuthTokenObject.UserName
        AuthToken    = $AuthTokenObject.AuthToken
        Credential   = $MyCredential
		Password     = ConvertFrom-SecureString $MyCredential.Password
    }
    
    Write-Verbose " [Connect-Splunk] :: Creating Splunk.SDK.Connection Object"
    # Creating Splunk.Connection
    $obj = New-Object PSObject -Property $myobj
    $obj.PSTypeNames.Clear()
    $obj.PSTypeNames.Add('Splunk.SDK.Connection')
    
    Write-Verbose " [Connect-Splunk] :: Setting SplunkDefaultConnectionObject using Set-SplunkConnectionObject"
    Set-SplunkConnectionObject -ConnectionObject $obj -force
	
	if($Passthru)
	{
		$obj;
	}
    
	Write-Verbose " [Connect-Splunk] :: =========    End   ========="
} # Connect-Splunk

#endregion Connect-Splunk

#region Get-SplunkLogin

function Get-SplunkLogin
{
	<# .ExternalHelp ../Splunk-Help.xml #>

	[Cmdletbinding()]
    Param(
	
		[Parameter()]
		[String]$Name = '.*',
        
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]$ComputerName = ( get-splunkconnectionobject ).ComputerName,
        
        [Parameter()]
        [int]$Port            = ( get-splunkconnectionobject ).Port,
        
        [Parameter()]
        [STRING]$Protocol     = ( get-splunkconnectionobject ).Protocol,
        
        [Parameter()]
        [int]$Timeout         = ( get-splunkconnectionobject ).Timeout,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential = ( get-splunkconnectionobject ).Credential
        
    )
	Begin
	{
		Write-Verbose " [Get-SplunkLogin] :: Starting"
	}
	Process
	{
		Write-Verbose " [Get-SplunkLogin] :: Parameters"
		Write-Verbose " [Get-SplunkLogin] ::  - Name         = $Name"
		Write-Verbose " [Get-SplunkLogin] ::  - ComputerName = $ComputerName"
		Write-Verbose " [Get-SplunkLogin] ::  - Port         = $Port"
		Write-Verbose " [Get-SplunkLogin] ::  - Protocol     = $Protocol"
		Write-Verbose " [Get-SplunkLogin] ::  - Timeout      = $Timeout"
		Write-Verbose " [Get-SplunkLogin] ::  - Credential   = $Credential"
		
		Write-Verbose " [Get-SplunkLogin] ::  Setting up Invoke-APIRequest parameters"
		$InvokeAPIParams = @{
			ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
			EndPoint     = '/services/authentication/httpauth-tokens'
			Verbose      = $VerbosePreference -eq "Continue"
		}
		
		Write-Verbose " [Get-SplunkLogin] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
		[XML]$UserToken = Invoke-SplunkAPIRequest @InvokeAPIParams 
		
		if($UserToken)
		{
			foreach($entry in $UserToken.feed.entry)
			{
				$Myobj = @{}
				$MyObj.Add("ComputerName",$ComputerName)
				foreach($Key in $entry.content.dict.key)
				{
					Write-Verbose " [Get-SplunkLogin] :: Processing [$($Key.Name)] with Value [$($Key.'#text')]"
					switch -exact ($Key.name)
					{
						"username"  	{$Myobj.Add('UserName',$Key.'#text')}
						"authString"	{$Myobj.Add('AuthToken',$Key.'#text')}
						"timeAccessed"	{
											# This code is work around a small bug where the Linux and Windows return different values.
											Write-Verbose " [Get-SplunkLogin] :: Setting DateTime format to convert the TimeAccessed to System.DateTime"
											$ConvertedTime = ConvertFrom-SplunkTime $Key.'#text'
                                            $Myobj.Add('TimeAccessed',$ConvertedTime)
										}
					}
				}
				
				Write-Verbose " [Get-SplunkLogin] :: Returning Object"
				New-Object PSObject -Property $Myobj -ea 0 | where{$_.UserName -match $Name} | foreach {				
					$_.PSTypeNames.Clear()
				    $_.PSTypeNames.Add('Splunk.SDK.AuthToken')
				    $_
				}
			}
		}
		else
		{
			Write-Error " [Get-SplunkLogin] :: No value returned from Server [$ComputerName]"
		}
	}
	End
	{
		Write-Verbose " [Get-SplunkLogin] :: =========    End   ========="
	}
	
}	# Get-SplunkLogin

#endregion Get-SplunkAuthToken

#region Get-SplunkAuthToken

function Get-SplunkAuthToken
{
	<# .ExternalHelp ../Splunk-Help.xml #>

	[Cmdletbinding(DefaultParameterSetName="byUserName")]
    Param(
	
		[Parameter(Mandatory=$True,ParameterSetName="byUserName")]
		[String]$UserName,
        
        [Parameter()]
        [String]$ComputerName = ( get-splunkconnectionobject ).ComputerName,
        
        [Parameter()]
        [int]$Port            = ( get-splunkconnectionobject ).Port,
        
        [Parameter()]
        [STRING]$Protocol     = ( get-splunkconnectionobject ).Protocol,
        
        [Parameter()]
        [int]$Timeout         = ( get-splunkconnectionobject ).Timeout,
		
		[Parameter(Mandatory=$True,ParameterSetName="byCredential")]
        [System.Management.Automation.PSCredential]$Credential
        
    )
	
	Write-Verbose " [Get-SplunkAuthToken] :: Starting..."
	Write-Verbose " [Get-SplunkAuthToken] :: Checking ParameterSet"
    Write-Verbose " [Get-SplunkAuthToken] :: Using [$($pscmdlet.ParameterSetName)] ParameterSet."
    switch ($pscmdlet.ParameterSetName)
    {
        "byCredential"      {
								Write-Verbose " [Get-SplunkAuthToken] :: Parameters"
								Write-Verbose " [Get-SplunkAuthToken] ::  - ComputerName = $ComputerName"
								Write-Verbose " [Get-SplunkAuthToken] ::  - Port         = $Port"
								Write-Verbose " [Get-SplunkAuthToken] ::  - Protocol     = $Protocol"
								Write-Verbose " [Get-SplunkAuthToken] ::  - Timeout      = $Timeout"
								Write-Verbose " [Get-SplunkAuthToken] ::  - Credential   = $Credential"
                                $MyCredential = $Credential
                            }
        "byUserName"        {
								Write-Verbose " [Get-SplunkAuthToken] :: Parameters"
								Write-Verbose " [Get-SplunkAuthToken] ::  - UserName     = $UserName"
								Write-Verbose " [Get-SplunkAuthToken] ::  - ComputerName = $ComputerName"
								Write-Verbose " [Get-SplunkAuthToken] ::  - Port         = $Port"
								Write-Verbose " [Get-SplunkAuthToken] ::  - Protocol     = $Protocol"
								Write-Verbose " [Get-SplunkAuthToken] ::  - Timeout      = $Timeout"
                                Write-Verbose " [Get-SplunkAuthToken] :: Creating a PSCredential object using [$UserName]"
                                $MyCredential = New-SplunkCredential -UserName $UserName
                            }
    }
	$MyUserName = $MyCredential.UserName -replace "^\\(.*)",'$1'
	$MyPassword = $MyCredential.GetNetworkCredential().Password
	
	Write-Verbose "  [Get-SplunkAuthToken] :: UserName: $MyUserName"
	Write-Verbose "  [Get-SplunkAuthToken] :: Password: $MyPassword"
	
	$MyParameters = @{ 'username'= $MyUserName ; 'password'= $MyPassword }
	
	Write-Verbose "  [Get-SplunkAuthToken] :: Setting up Invoke-APIRequest parameters"
	$InvokeAPIArgs = @{
		ComputerName = $ComputerName
		Port         = $Port
		Protocol     = $Protocol
		Timeout      = $Timeout
		RequestType  = "POST"
		Endpoint     = '/services/auth/login'
		Verbose      = $VerbosePreference -eq "Continue"
	}
	
	Write-Verbose "  [Get-SplunkAuthToken] :: Getting Auth Token via Invoke-SplunkAPIRequest"
	[XML]$Response = Invoke-SplunkAPIRequest @InvokeAPIArgs -Arguments $MyParameters -NoAuth
	
	if($response)
	{
		Write-Verbose "  [Get-SplunkAuthToken] :: Creating object to return"
		$Myobj = @{
			ComputerName = $ComputerName
			UserName  = $MyUserName
			AuthToken = $Response.Response.sessionKey
		}
		$obj = New-Object PSObject -Property $myobj
	    $obj.PSTypeNames.Clear()
	    $obj.PSTypeNames.Add('Splunk.SDK.AuthToken')
	    $obj
	}
	else
	{
		Write-Error " [Get-SplunkAuthToken] :: No value returned from Server [$ComputerName]"
	}

	Write-Verbose " [Get-SplunkAuthToken] :: =========    End   ========="
	
}	# Get-SplunkAuthToken

#endregion Get-SplunkAuthToken

#region Set-SplunkdPassword

function Set-SplunkdPassword
{

	<# .ExternalHelp ../Splunk-Help.xml #>

	[Cmdletbinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
    Param(

		[Parameter(Mandatory=$True)]
		[STRING]$UserName,
		
		[Parameter()]
		[STRING]$NewPassword,
		
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
		[SWITCH]$Force
        
    )
	
	Begin
	{
		
		Write-Verbose " [Set-SplunkdPassword] :: Starting..."
		if(!$NewPassword)
		{
			$SecureString = Read-Host -AsSecureString -Prompt "Please type new Password"
			$TempCreds = New-Object System.Management.Automation.PSCredential($UserName,$SecureString)
			$Password = $TempCreds.GetNetworkCredential().Password
		}
		else
		{
			$Password = $NewPassword 
		}
	}
	Process
	{
		Write-Verbose " [Set-SplunkdPassword] :: Parameters"
		Write-Verbose " [Set-SplunkdPassword] ::  - ComputerName = $ComputerName"
		Write-Verbose " [Set-SplunkdPassword] ::  - Port         = $Port"
		Write-Verbose " [Set-SplunkdPassword] ::  - Protocol     = $Protocol"
		Write-Verbose " [Set-SplunkdPassword] ::  - Timeout      = $Timeout"
		Write-Verbose " [Set-SplunkdPassword] ::  - Credential   = $Credential"
		Write-Verbose " [Set-SplunkdPassword] ::  - UserName     = $UserName"
		Write-Verbose " [Set-SplunkdPassword] ::  - NewPassword  = $Password"

		if( -not $pscmdlet.ShouldProcess( $ComputerName, "Setting Splunk password for $UserName" ) )
		{
			return;
		}

		Write-Verbose " [Set-SplunkdPassword] :: Verify the User exist on the Target instance [$ComputerName]"
		$GetSplunkdUser = @{
			UserName	 = $UserName
			ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
		}
		
		$User = Get-SplunkdUser @GetSplunkdUser
		if(!$User)
		{
			Write-Host "User [$UserName] not found on [$ComputerName]" -ForegroundColor Red -BackgroundColor White
		}
		else
		{
			Write-Verbose " [Set-SplunkdPassword] :: Setting up Invoke-APIRequest parameters"
			$InvokeAPIParams = @{
				ComputerName = $ComputerName
				Port         = $Port
				Protocol     = $Protocol
				Timeout      = $Timeout
				Credential   = $Credential
				Endpoint     = "/services/authentication/users/$UserName" 
				Verbose      = $VerbosePreference -eq "Continue"
			}
				
			Write-Verbose " [Set-SplunkdPassword] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
			if($Force -or $PSCmdlet.ShouldProcess($ComputerName,"Setting Password for $UserName"))
			{
				[XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams -Arguments @{'password'=$Password} -RequestType POST
				if($Results)
				{
					Write-Host "Password for [$UserName] changed on [$ComputerName]"
				}
				else
				{
					Write-Verbose " [Set-SplunkdPassword] :: Bad response please see Invoke-SplunkAPIRequest"
				}
			}
		}
	}
	End
	{
		Write-Verbose " [Set-SplunkdPassword] :: =========    End   ========="
	}
} # Set-SplunkdPassword

#endregion Set-SplunkdPassword

#region Get-SplunkdUser

function Get-SplunkdUser
{

	<# .ExternalHelp ../Splunk-Help.xml #>
	
	[Cmdletbinding()]
    Param(
	
		[Parameter()]
		[STRING]$UserName,
		
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
		Write-Verbose " [Get-SplunkdUser] :: Starting..."
	}
	Process
	{
		Write-Verbose " [Get-SplunkdUser] :: Parameters"
		Write-Verbose " [Get-SplunkdUser] ::  - UserName     = $UserName"
		Write-Verbose " [Get-SplunkdUser] ::  - ComputerName = $ComputerName"
		Write-Verbose " [Get-SplunkdUser] ::  - Port         = $Port"
		Write-Verbose " [Get-SplunkdUser] ::  - Protocol     = $Protocol"
		Write-Verbose " [Get-SplunkdUser] ::  - Timeout      = $Timeout"
		Write-Verbose " [Get-SplunkdUser] ::  - Credential   = $Credential"
		
		if($UserName)
		{
			$ServiceURL = "/services/authentication/users/$UserName"
		}
		else
		{
			$ServiceURL = "/services/authentication/users"
		}	

		Write-Verbose " [Get-SplunkdUser] :: Setting up Invoke-APIRequest parameters"
		$InvokeAPIParams = @{
			ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
			Endpoint     = $ServiceURL
			Verbose      = $VerbosePreference -eq "Continue"
		}
			
		Write-Verbose " [Get-SplunkdUser] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
		try
		{
			[XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams
		}
		catch
		{
			Write-Verbose " [Get-SplunkdUser] :: Invoke-SplunkAPIRequest threw an exception: $_"
            Write-Error $_		
		}
		if($Results)
		{
			foreach($Entry in $Results.feed.entry)
			{
				$MyObj = @{}
				$MyObj.Add("ComputerName",$ComputerName)
				$MyObj.Add("UserName",$Entry.Title)
				Write-Verbose " [Get-SplunkdUser] :: Creating Hash Table to be used to create 'Splunk.SDK.Splunkd.User'"
				switch ($Entry.content.dict.key)
				{
		        	{$_.name -eq "email"}						{$Myobj.Add("Email",$_.'#text');continue}
					{$_.name -eq "password"}					{$Myobj.Add("password",$_.'#text');continue}
			        {$_.name -eq "realname"}					{$Myobj.Add("FullName",$_.'#text');continue}
			        {$_.name -eq "roles"}						{$Myobj.Add("roles",$_.list.item);continue}
			        {$_.name -eq "type"}						{$Myobj.Add("Type",$_.'#text');continue}
					{$_.name -eq "defaultApp"}		    		{$Myobj.Add("DefaultApp",$_.'#text');continue}
		        	{$_.name -eq "defaultAppIsUserOverride"}	{$Myobj.Add("Splunk_Home",$_.'#text');continue}
					{$_.name -eq "defaultAppSourceRole"}		{$Myobj.Add("defaultAppSourceRole",$_.'#text');continue}
				}
				
				# Creating Splunk.SDK.Splunkd.User
			    $obj = New-Object PSObject -Property $MyObj
			    $obj.PSTypeNames.Clear()
			    $obj.PSTypeNames.Add('Splunk.SDK.Splunkd.User')
			    $obj
			}
		}
		else
		{
			Write-Verbose " [Get-SplunkdUser] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
		}
	}
	End
	{
		Write-Verbose " [Get-SplunkdUser] :: =========    End   ========="
	}
} # Get-SplunkdUser

#endregion Get-SplunkdUser

#region Set-SplunkdUser

function Set-SplunkdUser
{
	<# .ExternalHelp ../Splunk-Help.xml #>	
	
	[Cmdletbinding(SupportsShouldProcess=$true)]
    Param(
	
		[Parameter(Mandatory=$true)]
		[STRING]
		# the username to update
		$UserName,
		
		[Parameter()]
		[STRING]
		# the default application for the user
		$DefaultApp,
		
		[Parameter()]
		[ValidatePattern( '^[\w\.\-]+@[a-zA-Z0-9\-]+(\.[a-zA-Z0-9\-]{1,})*(\.[a-zA-Z]{2,3}){1,2}$' )]
		[STRING]
		# the user email address
		$EmailAddress,
		
		[Parameter()]
		[STRING]
		# the real name of the user
		$RealName,
		
		#[Parameter()]
		#[STRING[]]$Roles,
		
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
		Write-Verbose " [Set-SplunkdUser] :: Starting..."
	}
	Process
	{
		Write-Verbose " [Set-SplunkdUser] :: Parameters"
		Write-Verbose " [Set-SplunkdUser] ::  - UserName     = $UserName"
		Write-Verbose " [Set-SplunkdUser] ::  - DefaultApp   = $DefaultApp"
		Write-Verbose " [Set-SplunkdUser] ::  - EmailAddress = $EmailAddress"
		Write-Verbose " [Set-SplunkdUser] ::  - RealName     = $RealName"
		Write-Verbose " [Set-SplunkdUser] ::  - ComputerName = $ComputerName"
		Write-Verbose " [Set-SplunkdUser] ::  - Port         = $Port"
		Write-Verbose " [Set-SplunkdUser] ::  - Protocol     = $Protocol"
		Write-Verbose " [Set-SplunkdUser] ::  - Timeout      = $Timeout"
		Write-Verbose " [Set-SplunkdUser] ::  - Credential   = $Credential"
		
		$Endpoint     = "/services/authentication/users/$UserName" 
		Write-Verbose " [Set-SplunkdUser] ::  - Endpoint     = $Endpoint"
		
		Write-Verbose " [Set-SplunkdPassword] :: Verify the User exist on the Target instance [$ComputerName]"
		$GetSplunkdUser = @{
			UserName	 = $UserName
			ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
		}
		
		$User = Get-SplunkdUser @GetSplunkdUser
		if(!$User)
		{
			Write-Host "User [$UserName] not found on [$ComputerName]" -ForegroundColor Red -BackgroundColor White
		}
		else
		{
			Write-Verbose " [Set-SplunkdUser] :: Setting up Invoke-APIRequest parameters"
			$InvokeAPIParams = @{
				ComputerName = $ComputerName
				Port         = $Port
				Protocol     = $Protocol
				Timeout      = $Timeout
				Credential   = $Credential
				Endpoint     = $Endpoint 
				Verbose      = $VerbosePreference -eq "Continue"
			}
						
			Write-Verbose " [Set-SplunkdUser] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
			if($Force -or $PSCmdlet.ShouldProcess($ComputerName,"Update user $UserName"))
			{	
				$Arguments = @{};
			
				if( $DefaultApp )
				{
					$Arguments['defaultApp'] = $DefaultApp;
				}
				if( $EmailAddress )
				{
					$Arguments['email'] = $EmailAddress;
				}
				if( $RealName )
				{
					$Arguments['realname'] = $RealName;
				}

				try
				{
					[XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams -Arguments $Arguments -RequestType POST
				}
				catch
				{
					Write-Verbose " [Set-SplunkdUser] :: Invoke-SplunkAPIRequest threw an exception: $_"
		            Write-Error $_		
				}

				if($Results)
				{
					Get-SplunkdUser @GetSplunkdUser
				}
			}
		}
	}
	End
	{
		Write-Verbose " [Set-SplunkdUser] :: =========    End   ========="
	}
} # Set-SplunkdUser

#endregion Set-SplunkdUser

#region Remove-SplunkdUser

function Remove-SplunkdUser
{
	<# .ExternalHelp ../Splunk-Help.xml #>	
	
	[Cmdletbinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
    Param(
	
		[Parameter(Mandatory=$true)]
		[STRING]
		# the user to remove
		$UserName,
		
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
		Write-Verbose " [Remove-SplunkdUser] :: Starting..."
	}
	Process
	{
		Write-Verbose " [Remove-SplunkdUser] :: Parameters"
		Write-Verbose " [Remove-SplunkdUser] ::  - UserName     = $UserName"
		Write-Verbose " [Remove-SplunkdUser] ::  - ComputerName = $ComputerName"
		Write-Verbose " [Remove-SplunkdUser] ::  - Port         = $Port"
		Write-Verbose " [Remove-SplunkdUser] ::  - Protocol     = $Protocol"
		Write-Verbose " [Remove-SplunkdUser] ::  - Timeout      = $Timeout"
		Write-Verbose " [Remove-SplunkdUser] ::  - Credential   = $Credential"
		
		$Endpoint     = "/services/authentication/users/$UserName" 
		Write-Verbose " [Remove-SplunkdUser] ::  - Endpoint     = $Endpoint"
		
		Write-Verbose " [Remove-SplunkdUser] :: Setting up Invoke-APIRequest parameters"
		$InvokeAPIParams = @{
			ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
			Endpoint     = $Endpoint 
			Verbose      = $VerbosePreference -eq "Continue"
		}
					
		Write-Verbose " [Remove-SplunkdUser] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
		if($Force -or $PSCmdlet.ShouldProcess($ComputerName,"Delete user $UserName"))
		{	
			try
			{
				[XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams -Arguments $Arguments -RequestType DELETE
			}
			catch
			{
				Write-Verbose " [Remove-SplunkdUser] :: Invoke-SplunkAPIRequest threw an exception: $_"
	            Write-Error $_		
			}
		}
	}
	End
	{
		Write-Verbose " [Remove-SplunkdUser] :: =========    End   ========="
	}
} # Remove-SplunkdUser

#endregion Remove-SplunkdUser

#region New-SplunkdUser

function New-SplunkdUser
{
	<# .ExternalHelp ../Splunk-Help.xml #>	
	[Cmdletbinding(SupportsShouldProcess=$true)]
    Param(
	
		[Parameter(Mandatory=$true)]
		[STRING]
		# the username to update
		$UserName,
		
		[Parameter()]
		[STRING]
		# the default application for the user
		$DefaultApp,
		
		[Parameter()]
		[ValidatePattern( '^[\w\.\-]+@[a-zA-Z0-9\-]+(\.[a-zA-Z0-9\-]{1,})*(\.[a-zA-Z]{2,3}){1,2}$' )]
		[STRING]
		# the user email address
		$EmailAddress,
		
		[Parameter()]
		[STRING]
		# the real name of the user
		$RealName,
		
		[Parameter()]
		[STRING[]]
		# the roles to assign to the user.  defaults to "user".
		$Roles = @("user"),
		
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
		Write-Verbose " [New-SplunkdUser] :: Starting..."
		if(!$Password)
		{
			$SecureString = Read-Host -AsSecureString -Prompt "Please type new user Password"
			$TempCreds = New-Object System.Management.Automation.PSCredential($UserName,$SecureString)
			$Password = $TempCreds.GetNetworkCredential().Password
		}
	}
		Process
	{
		Write-Verbose " [New-SplunkdUser] :: Parameters"
		Write-Verbose " [New-SplunkdUser] ::  - UserName     = $UserName"
		Write-Verbose " [New-SplunkdUser] ::  - Password     = $Password"
		Write-Verbose " [New-SplunkdUser] ::  - DefaultApp   = $DefaultApp"
		Write-Verbose " [New-SplunkdUser] ::  - EmailAddress = $EmailAddress"
		Write-Verbose " [New-SplunkdUser] ::  - RealName     = $RealName"
		Write-Verbose " [New-SplunkdUser] ::  - ComputerName = $ComputerName"
		Write-Verbose " [New-SplunkdUser] ::  - Port         = $Port"
		Write-Verbose " [New-SplunkdUser] ::  - Protocol     = $Protocol"
		Write-Verbose " [New-SplunkdUser] ::  - Timeout      = $Timeout"
		Write-Verbose " [New-SplunkdUser] ::  - Credential   = $Credential"
		
		$Endpoint     = "/services/authentication/users"  
		Write-Verbose " [New-SplunkdUser] ::  - Endpoint     = $Endpoint"
		
		Write-Verbose " [New-SplunkdUser] :: Setting up Invoke-APIRequest parameters"
		$InvokeAPIParams = @{
			ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
			Endpoint     = $Endpoint 
			Verbose      = $VerbosePreference -eq "Continue"
		}
					
		Write-Verbose " [New-SplunkdUser] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
		if($Force -or $PSCmdlet.ShouldProcess($ComputerName,"Creating new user $UserName"))
		{	
			$Arguments = @{
				'name'     = $UserName;
				'password' = $Password;
                'roles'    = $Roles -join ","
			};
		
			if( $DefaultApp )
			{
				$Arguments['defaultApp'] = $DefaultApp;
			}
			if( $EmailAddress )
			{
				$Arguments['email'] = $EmailAddress;
			}
			if( $RealName )
			{
				$Arguments['realname'] = $RealName;
			}

			try
			{
				[XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams -Arguments $Arguments -RequestType POST
			}
			catch
			{
				Write-Verbose " [New-SplunkdUser] :: Invoke-SplunkAPIRequest threw an exception: $_"
	            Write-Error $_		
			}

			if($Results)
			{
				Get-SplunkdUser @GetSplunkdUser
			}
		}
	}
	End
	{
		Write-Verbose " [New-SplunkdUser] :: =========    End   ========="
	}
} # New-SplunkdUser

#endregion New-SplunkdUser

#endregion Authentication

