#region functions

#region Base_Cmdlets

#region Invoke-SplunkAPIRequest

function Invoke-SplunkAPIRequest
{

	<#
        .Synopsis 
            Sends a request to the Splunk REST API on the targeted instance.
            
        .Description
            Sends a request to the Splunk REST API on the targeted instance.
            
        .Parameter ComputerName
            Name of the Splunk instance to get the settings for (Default is $SplunkDefaultObject.ComputerName.)
        
		.Parameter Port
            Port of the REST Instance (i.e. 8089) (Default is $SplunkDefaultObject.Port.)
        
		.Parameter Protocol
            Protocol to use to access the REST API must be 'http' or 'https' (Default is $SplunkDefaultObject.Protocol.)
        
		.Parameter Timeout
            How long to wait for the REST API to respond (Default is $SplunkDefaultObject.Timeout.)	
			
        .Parameter Credential
            Credential object with the user name and password used to access the REST API.	
		
		.Parameter Endpoint
			API Endpoint to access (i.e. /services/server/settings)
        
        .Parameter Format
        	How to format the output. Valid values are "XML", "CSV", "JSON", "RAW". Default is "XML."
			
        .Parameter RequestType
			Type of API request to make. Valid values are "GET", "POST", "PUT", "DELETE". Default is "GET."
        
        .Parameter Arguments
			Hash table of values to pass to the REST API.

        .Parameter UserName
			User to connect with. Must be used with AuthToken and cannot be used with Credential or NoAuth switch.
        
        .Parameter AuthToken
			AuthToken for user. Must be used with UserName and cannot be used with Credential or NoAuth switch.
        
        .Parameter NoAuth
			Tells the API request to bypass authentication. May not be used with UserName,AuthToken, or Credential.
			
		.Example
            Invoke-SplunkAPIRequest
            Description
            -----------
            Gets the values set for the targeted Splunk instance using the $SplunkDefaultObject settings.
    
        .Example
            Invoke-SplunkAPIRequest -ComputerName MySplunkInstance -Port 8089 -Protocol https -Timeout 5000 -Credential $MyCreds
            Description
            -----------
            Gets the values set for MySplunkInstance connecting on port 8089 with a 5sec timeout.
            
        .OUTPUTS
            PSObject
            
        .Notes
	        NAME:      Invoke-SplunkAPIRequest 
	        AUTHOR:    Splunk\bshell
	        Website:   www.splunk.com
	        #Requires -Version 2.0
    #>
	
    [Cmdletbinding(DefaultParameterSetName="byAuthToken")]
    Param(
    
	    [Parameter()]
        [String]$ComputerName = $SplunkDefaultObject.ComputerName,
        
        [Parameter()]
        [int]$Port = $SplunkDefaultObject.Port,
        
        [Parameter()]
		[ValidateSet("http", "https")]
        [STRING]$Protocol = $SplunkDefaultObject.Protocol,
        
        [Parameter()]
        [int]$Timeout = $SplunkDefaultObject.Timeout,
		
        [Parameter(Mandatory=$True)]
        [STRING]$Endpoint,
        
        [Parameter()]
        [ValidateSet("XML", "CSV", "JSON", "RAW")]
        [STRING]$Format = 'XML',
        
        [Parameter()]
        [ValidateSet("GET", "POST", "PUT", "DELETE","SIMPLEPOST")]
        [STRING]$RequestType = 'GET',
        
        [Parameter()]
        [System.Collections.Hashtable]$Arguments,
        
        [Parameter()]
        [STRING]$PostMessage,
        
        [Parameter()]
        [STRING]$URLParam,

		[Parameter(ParameterSetName="byAuthToken")]
        [STRING]$UserName,
        
        [Parameter(ParameterSetName="byAuthToken")]
        [STRING]$AuthToken,
        
        [Parameter(ParameterSetName="byCredential")]
        [System.Management.Automation.PSCredential]$Credential,
		
		[Parameter(ParameterSetName="byNoAuth")]
        [SWITCH]$NoAuth
        
    )
    
	Write-Verbose " [Invoke-SplunkAPIRequest] :: Starting"
	
    #region Internal Functions
    
    function Invoke-HTTPGet
    {
        [CmdletBinding(DefaultParameterSetName="byToken")]
        Param(
            [Parameter(Mandatory=$True)]
            [STRING]$URL,
			
			[Parameter(Mandatory=$True)]
            [INT]$Timeout,
            
            [Parameter(ParameterSetName='byToken')]
            [STRING]$UName,
            
            [Parameter(ParameterSetName='byToken')]
            [STRING]$Token,
            
            [Parameter(ParameterSetName='byCreds')]
            [System.Management.Automation.PSCredential]$Creds
            
        )
        
        Write-Verbose " [Invoke-HTTPGet] :: Using [$($pscmdlet.ParameterSetName)] ParameterSet"
        switch -exact ($pscmdlet.ParameterSetName)
        {
            "byToken"       {
                                $MyURL = "{0}?username={1}&authToken={2}" -f $URL,$UName,$Token
                                Write-Verbose " [Invoke-HTTPGet] :: Connecting to URL: $MyURL"
                                $Request = [System.Net.WebRequest]::Create($MyURL)
                                $Request.Method ="GET"
                                $Request.Timeout = $Timeout
                                $Request.ContentLength = 0
                            }
            "byCreds"       {
                                Write-Verbose " [Invoke-HTTPGet] :: Connecting to URL: $URL"
                                $Request = [System.Net.WebRequest]::Create($URL)
                                $Request.Credentials = $Creds
                                $Request.Method ="GET"
                                $Request.Timeout = $Timeout
                                $Request.ContentLength = 0
                            }
        }

        try
        {
            Write-Verbose " [Invoke-HTTPGet] :: Sending Request"
            $Response = $Request.GetResponse()
        }
        catch
        {
            Write-Verbose " [Invoke-HTTPGet] :: Error sending request"
			Write-Error $_ -ErrorAction Stop
            return
        }
        
        try
        {
            Write-Verbose " [Invoke-HTTPGet] :: Creating StreamReader from Response"
            $Reader = New-Object System.IO.StreamReader($Response.GetResponseStream())
        }
        catch
        {
            Write-Verbose " [Invoke-HTTPGet] :: Error getting Response Stream"
			Write-Error $_ -ErrorAction Stop
            return
        }
        
        try
        {
            Write-Verbose " [Invoke-HTTPGet] :: Getting Results"
            $Result = $Reader.ReadToEnd()
        }
        catch
        {
            Write-Verbose " [Invoke-HTTPGet] :: Error Reading Response Stream"
			Write-Error $_ -ErrorAction Stop
            return
        }
   
	    Write-Verbose " [Invoke-HTTPGet] :: Returning Results"
    	$Result
    }
    
	function Invoke-HTTPPost
	{
	    [CmdletBinding(DefaultParameterSetName="byToken")]
	    Param(
	        [Parameter(Mandatory=$True)]
	        [STRING]$URL,
			
			[Parameter(Mandatory=$True)]
            [INT]$Timeout,
			
			[Parameter()]
			[System.Collections.Hashtable]$Arguments,
	        
	        [Parameter(ParameterSetName='byToken')]
	        [STRING]$UName,
	        
	        [Parameter(ParameterSetName='byToken')]
	        [STRING]$Token,
	        
	        [Parameter(ParameterSetName='byCreds')]
	        [System.Management.Automation.PSCredential]$Creds,
			
			[Parameter(ParameterSetName='byNoAuth')]
			[Switch]$NoAuth
	        
	    )
		
		$i = 1
		
		Write-Verbose " [Invoke-HTTPPost] :: Creating POST message"
		foreach($Argument in $Arguments.Keys)
		{
			if($i -le 1)
			{
		    	[string]$PostString = "{0}={1}" -f $Argument,[System.Web.HttpUtility]::UrlEncode($Arguments[$Argument])
			}
			else
			{
				[string]$PostString += "&{0}={1}" -f $Argument,[System.Web.HttpUtility]::UrlEncode($Arguments[$Argument])
			}
			$i++
		}
		
		
		Write-Verbose " [Invoke-HTTPPost] :: `$PostString = $PostString"
		
	    Write-Verbose " [Invoke-HTTPPost] :: Using [$($pscmdlet.ParameterSetName)] ParameterSet"
	    switch -exact ($pscmdlet.ParameterSetName)
	    {
	        "byToken"       {
	                            $MyURL = "{0}?username={1}&authToken={2}" -f $URL,$UName,$Token
	                            Write-Verbose " [Invoke-HTTPPost] :: Connecting to URL: $MyURL"
	                            $Request = [System.Net.WebRequest]::Create($URL)
	                            $Request.Method ="POST"
								$request.ContentLength = $PostString.Length
								$Request.ContentType = "application/x-www-form-urlencoded"
	                            $Request.Timeout = $Timeout
	                        }
	        "byCreds"       {
	                            Write-Verbose " [Invoke-HTTPPost] :: Connecting to URL: $URL"
	                            $Request = [System.Net.WebRequest]::Create($URL)
	                            $Request.Credentials = $Creds
	                            $Request.Method ="POST"
								$request.ContentLength = $PostString.Length
								$Request.ContentType = "application/x-www-form-urlencoded"
	                            $Request.Timeout = $Timeout
	                        }
			"byNoAuth"      {
	                            Write-Verbose " [Invoke-HTTPPost] :: Connecting to URL: $URL"
	                            $Request = [System.Net.WebRequest]::Create($URL)
	                            $Request.Method = "POST"
								$request.ContentLength = $PostString.Length
								$Request.ContentType = "application/x-www-form-urlencoded"
								$Request.AuthenticationLevel = [System.Net.Security.AuthenticationLevel]::None
	                            $Request.Timeout = $Timeout
	                        }
	    }
	    
	    try
	    {
	        $RequestStream = new-object IO.StreamWriter($Request.GetRequestStream(),[System.Text.Encoding]::ASCII)
	    }
	    catch
	    {
			Write-Error $_
	        return
	    }

		try
		{
			Write-Verbose " [Invoke-HTTPPost] :: Sending POST message"
	    	$RequestStream.Write($PostString)
	    }
		catch
		{
			Write-Verbose " [Invoke-HTTPPost] :: Error sending POST message"
			Write-Error $_
		}
		finally
		{
		    Write-Verbose " [Invoke-HTTPPost] :: Closing POST stream"
			$RequestStream.Flush()
		    $RequestStream.Close()
		}
		Write-Verbose " [Invoke-HTTPPost] :: Getting Response from POST"
		try
		{
	    	$Response = $Request.GetResponse()
			$Reader = new-object System.IO.StreamReader($Response.GetResponseStream())
			$Results = $Reader.ReadToEnd()
	    	Write-Verbose " [Invoke-HTTPPost] :: Returning Results"
			$Results
		}
		catch
		{
			Write-Verbose " [Invoke-HTTPPost] :: Error getting response from POST"
			Write-Error $_
		}
	}
    
    function Invoke-HTTPSimplePost
	{
	    [CmdletBinding(DefaultParameterSetName="byToken")]
	    Param(
        
	        [Parameter(Mandatory=$True)]
	        [STRING]$URL,
			
			[Parameter(Mandatory=$True)]
            [INT]$Timeout,
			
			[Parameter()]
			[STRING]$URLParam,
            
            [Parameter()]
			[STRING]$PostMessage,
	        
	        [Parameter(ParameterSetName='byToken')]
	        [STRING]$UName,
	        
	        [Parameter(ParameterSetName='byToken')]
	        [STRING]$Token,
	        
	        [Parameter(ParameterSetName='byCreds')]
	        [System.Management.Automation.PSCredential]$Creds,
			
			[Parameter(ParameterSetName='byNoAuth')]
			[Switch]$NoAuth
	        
	    )
		
        if($URLParam)
        {
            $PostURL = "{0}?{1}" -f $URL,$URLParam
        }
        else
        {
            $PostURL = $URL
        }
                        
        $ContentLength = $PostMessage.Length
		
	    Write-Verbose " [Invoke-HTTPSimplePost] :: Using [$($pscmdlet.ParameterSetName)] ParameterSet"
	    switch -exact ($pscmdlet.ParameterSetName)
	    {
	        "byToken"       {
	                            if($URLParam)
                                {
                                    $PostURL = "{0}&username={1}&authToken={2}" -f $PostURL,$UName,$Token
                                }
                                else
                                {
                                    $PostURL = "{0}?username={1}&authToken={2}" -f $PostURL,$UName,$Token
                                }
	                            Write-Verbose " [Invoke-HTTPPost] :: Connecting to URL: $PostURL"
	                            $Request = [System.Net.WebRequest]::Create($PostURL)
	                            $Request.Method ="POST"
								$request.ContentLength = $ContentLength
								$Request.ContentType = "text/xml"
	                            $Request.Timeout = $Timeout
	                        }
	        "byCreds"       {
	                            Write-Verbose " [Invoke-HTTPPost] :: Connecting to URL: $PostURL"
	                            $Request = [System.Net.WebRequest]::Create($PostURL)
	                            $Request.Credentials = $Creds
	                            $Request.Method ="POST"
								$request.ContentLength = $ContentLength
								$Request.ContentType = "text/xml"
	                            $Request.Timeout = $Timeout
	                        }
			"byNoAuth"      {
	                            Write-Verbose " [Invoke-HTTPPost] :: Connecting to URL: $PostURL"
	                            $Request = [System.Net.WebRequest]::Create($PostURL)
	                            $Request.Method = "POST"
								$request.ContentLength = $ContentLength
								$Request.ContentType = "text/xml"
								$Request.AuthenticationLevel = [System.Net.Security.AuthenticationLevel]::None
	                            $Request.Timeout = $Timeout
	                        }
	    }
	    
	    try
	    {
	        $RequestStream = new-object IO.StreamWriter($Request.GetRequestStream(),[System.Text.Encoding]::ASCII)
	    }
	    catch
	    {
			Write-Error $_
	        return
	    }

		try
		{
			Write-Verbose " [Invoke-HTTPSimplePost] :: Sending POST message [$PostMessage]"
	    	$RequestStream.Write($PostMessage)
	    }
		catch
		{
			Write-Verbose " [Invoke-HTTPSimplePost] :: Error sending POST message"
			Write-Error $_
		}
		finally
		{
		    Write-Verbose " [Invoke-HTTPSimplePost] :: Closing POST stream"
			$RequestStream.Flush()
		    $RequestStream.Close()
		}
		Write-Verbose " [Invoke-HTTPSimplePost] :: Getting Response from POST"
		try
		{
	    	$Response = $Request.GetResponse()
			$Reader = new-object System.IO.StreamReader($Response.GetResponseStream())
			$Results = $Reader.ReadToEnd()
	    	Write-Verbose " [Invoke-HTTPSimplePost] :: Returning Results"
			$Results
		}
		catch
		{
			Write-Verbose " [Invoke-HTTPSimplePost] :: Error getting response from POST"
			Write-Error $_
		}
	}
    
    #endregion Internal Functions
    
    Write-Verbose " [Invoke-SplunkAPIRequest] :: Using [$($pscmdlet.ParameterSetName)] ParameterSet"
    Write-Verbose " [Invoke-SplunkAPIRequest] :: Parameters"
    Write-Verbose " [Invoke-SplunkAPIRequest] ::  - Endpoint     = $Endpoint"
    Write-Verbose " [Invoke-SplunkAPIRequest] ::  - Format       = $Format"
    Write-Verbose " [Invoke-SplunkAPIRequest] ::  - RequestType  = $RequestType"
    Write-Verbose " [Invoke-SplunkAPIRequest] ::  - ComputerName = $ComputerName"
    Write-Verbose " [Invoke-SplunkAPIRequest] ::  - Port         = $Port"
    Write-Verbose " [Invoke-SplunkAPIRequest] ::  - Protocol     = $Protocol"
    Write-Verbose " [Invoke-SplunkAPIRequest] ::  - Timeout      = $Timeout"
    
    $FullURL = "{0}://{1}:{2}/{3}" -f $Protocol,$ComputerName,$Port,($Endpoint -replace '^/(.*)','$1')
    Write-Verbose " [Invoke-SplunkAPIRequest] ::  - FullURL      = $FullURL"
	
	$InvokeHTTPParams = @{
		URL = $FullURL
		Timeout = $Timeout
	}
        
    switch ($pscmdlet.ParameterSetName)
    {
        "byAuthToken"       {
                                Write-Verbose " [Invoke-SplunkAPIRequest] ::  - UserName     = $UserName"
                                Write-Verbose " [Invoke-SplunkAPIRequest] ::  - AuthToken    = $AuthToken"
                                switch -exact ($RequestType)
                                {
                                    "GET"           { Invoke-HTTPGet        @InvokeHTTPParams -UName $UserName -Token $AuthToken }
                                    "PUT"           { Invoke-HTTPPut        @InvokeHTTPParams -UName $UserName -Token $AuthToken }
                                    "POST"          { Invoke-HTTPPost       @InvokeHTTPParams -UName $UserName -Token $AuthToken -Arguments $Arguments }
                                    "SIMPLEPOST"    { Invoke-HTTPSimplePost @InvokeHTTPParams -UName $UserName -Token $AuthToken -URLParam $URLParam -PostMessage $PostMessage}
                                    "DELETE"        { Invoke-HTTPDelete     @InvokeHTTPParams -UName $UserName -Token $AuthToken }
                                }
                            }
        "byCredential"      {
                                Write-Verbose " [Invoke-SplunkAPIRequest] ::  - Credential   = $Credential"
                                switch -exact ($RequestType)
                                {
                                    "GET"           { Invoke-HTTPGet        @InvokeHTTPParams -Creds $Credential }
                                    "PUT"           { Invoke-HTTPPut        @InvokeHTTPParams -Creds $Credential }
                                    "POST"          { Invoke-HTTPPost       @InvokeHTTPParams -Creds $Credential -Arguments $Arguments }
                                    "SIMPLEPOST"    { Invoke-HTTPSimplePost @InvokeHTTPParams -Creds $Credential -URLParam $URLParam -PostMessage $PostMessage }
                                    "DELETE"        { Invoke-HTTPDelete     @InvokeHTTPParams -Creds $Credential }
                                }
                            }
							
		"byNoAuth"      	{
                                Write-Verbose " [Invoke-SplunkAPIRequest] ::  - NoAuth"
                                switch -exact ($RequestType)
                                {
                                    "GET"           { Invoke-HTTPGet        @InvokeHTTPParams -NoAuth }
                                    "PUT"           { Invoke-HTTPPut        @InvokeHTTPParams -NoAuth }
                                    "POST"          { Invoke-HTTPPost       @InvokeHTTPParams -NoAuth -Arguments $Arguments }
                                    "SIMPLEPOST"    { Invoke-HTTPSimplePost @InvokeHTTPParams -NoAuth -URLParam $URLParam -PostMessage $PostMessage}
                                    "DELETE"        { Invoke-HTTPDelete     @InvokeHTTPParams -NoAuth }
                                }
                            }
    }
    

	Write-Verbose " [Invoke-SplunkAPIRequest] :: =========    End   ========="
	
} # Invoke-SplunkAPIRequest

#endregion Invoke-SplunkAPIRequest

#endregion Base_Cmdlets

################################################################################

#region Authentication

#region New-SplunkCredential

# Helper function to Get and Store Credentials to be used against the Splunk API
function New-SplunkCredential
{
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
    [Cmdletbinding(DefaultParameterSetName="byCredentials")]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$ComputerName,
        
        [Parameter()]
        [int]$Port = 8089, 
        
        [Parameter()]
        [STRING]$Protocol = "https", 
        
        [Parameter()]
        [INT]$Timeout = 10000, 
        
        [Parameter(Mandatory=$true,ParameterSetName="byCredentials")]
        [System.Management.Automation.PSCredential]$Credentials,
        
        [Parameter(Mandatory=$true,ParameterSetName="byUserName")]
        [STRING]$UserName
    )
	
    Write-Verbose " [Connect-Splunk] :: Starting..."
    Write-Verbose " [Connect-Splunk] :: Checking ParameterSet"
    Write-Verbose " [Connect-Splunk] :: Using [$($pscmdlet.ParameterSetName)] ParameterSet."
    switch ($pscmdlet.ParameterSetName)
    {
        "byCredentials"     {
								Write-Verbose " [Connect-Splunk] :: Parameters"
								Write-Verbose " [Connect-Splunk] ::  - ComputerName = $ComputerName"
								Write-Verbose " [Connect-Splunk] ::  - Port         = $Port"
								Write-Verbose " [Connect-Splunk] ::  - Protocol     = $Protocol"
								Write-Verbose " [Connect-Splunk] ::  - Timeout      = $Timeout"
								Write-Verbose " [Connect-Splunk] ::  - Credential   = $Credential"
                                $MyCredential = $Credentials
                                
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
    
    # Creating Splunk.Connection
    $obj = New-Object PSObject -Property $myobj
    $obj.PSTypeNames.Clear()
    $obj.PSTypeNames.Add('Splunk.SDK.Connection')
    $obj
    
	Write-Verbose " [Connect-Splunk] :: =========    End   ========="
} # Connect-Splunk

#endregion Connect-Splunk

#region Get-SplunkLogin

function Get-SplunkLogin
{
	[Cmdletbinding()]
    Param(
	
		[Parameter()]
		[String]$Name = '.*',
        
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]$ComputerName = $SplunkDefaultObject.ComputerName,
        
        [Parameter()]
        [int]$Port            = $SplunkDefaultObject.Port,
        
        [Parameter()]
        [STRING]$Protocol     = $SplunkDefaultObject.Protocol,
        
        [Parameter()]
        [int]$Timeout         = $SplunkDefaultObject.Timeout,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential = $SplunkDefaultObject.Credential
        
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
				$obj = New-Object PSObject -Property $Myobj -ea 0 | where{$_.UserName -match $Name}
				$obj.PSTypeNames.Clear()
			    $obj.PSTypeNames.Add('Splunk.SDK.AuthToken')
			    $obj
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
	[Cmdletbinding(DefaultParameterSetName="byUserName")]
    Param(
	
		[Parameter(Mandatory=$True,ParameterSetName="byUserName")]
		[String]$UserName,
        
        [Parameter()]
        [String]$ComputerName = $SplunkDefaultObject.ComputerName,
        
        [Parameter()]
        [int]$Port            = $SplunkDefaultObject.Port,
        
        [Parameter()]
        [STRING]$Protocol     = $SplunkDefaultObject.Protocol,
        
        [Parameter()]
        [int]$Timeout         = $SplunkDefaultObject.Timeout,
		
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

	<#
        .Synopsis 
            Sets the password for the user provided.
            
        .Description
            Sets the password for the user provided. This is the password found in the Splunk web interface: Manager » Access controls » Users » <UserName>
        
		.Parameter UserName
			User to set the password for. This is required.
			
		.Parameter NewPassword
			Password for the user. If not provide you will be prompted for a password.
			
        .Parameter ComputerName
            Name of the Splunk instance to set the user password on (Default is $SplunkDefaultObject.ComputerName.)
        
		.Parameter Port
            Port of the REST Instance (i.e. 8089) (Default is $SplunkDefaultObject.Port.)
        
		.Parameter Protocol
            Protocol to use to access the REST API must be 'http' or 'https' (Default is $SplunkDefaultObject.Protocol.)
        
		.Parameter Timeout
            How long to wait for the REST API to respond (Default is $SplunkDefaultObject.Timeout.)	
			
        .Parameter Credential
            Credential object with the user name and password used to access the REST API (Default is $SplunkDefaultObject.Credential.)	
			
		.Example
            Set-SplunkdPassword -UserName admin -NewPassword P@ssw0rd!
            Description
            -----------
            Sets the password for user 'admin' to 'P@ssw0rd!' on targeted Splunk instance using the $SplunkDefaultObject settings.
    
		.Example
            Set-SplunkdPassword -UserName admin
            Description
            -----------
            Sets the password for user 'admin' to provided password on targeted Splunk instance using the $SplunkDefaultObject settings.
			
        .Example
            Set-SplunkdPassword -UserName admin -NewPassword P@ssw0rd! -ComputerName MySplunkInstance -Port 8089 -Protocol https -Timeout 5000 -Credential $MyCreds
            Description
            -----------
            Sets the password for user 'admin' to 'P@ssw0rd!' on MySplunkInstance connecting on port 8089 with a 5sec timeout.
            
        .Example
            $SplunkServers | Set-SplunkdPassword -UserName admin -NewPassword P@ssw0rd!
            Description
            -----------
            Sets the password for user 'admin' to 'P@ssw0rd!' for each Splunk server in the pipeline using the $SplunkDefaultObject settings.
        
		.Example
            $SplunkServers | Set-SplunkdPassword -UserName admin -NewPassword P@ssw0rd! -Port 8089 -Protocol https -Timeout 5000 -Credential $MyCreds
            Description
            -----------
            Sets the password for user 'admin' to 'P@ssw0rd!' for each Splunk server in the pipeline connecting on port 8089 with a 5sec timeout and using credentials provided.
			
        .OUTPUTS
            PSObject
            
        .Notes
	        NAME:      Set-SplunkdPassword 
	        AUTHOR:    Splunk\bshell
	        Website:   www.splunk.com
	        #Requires -Version 2.0
    #>

	[Cmdletbinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
    Param(

		[Parameter(Mandatory=$True)]
		[STRING]$UserName,
		
		[Parameter()]
		[STRING]$NewPassword,
		
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]$ComputerName = $SplunkDefaultObject.ComputerName,
        
        [Parameter()]
        [int]$Port            = $SplunkDefaultObject.Port,
        
        [Parameter()]
        [STRING]$Protocol     = $SplunkDefaultObject.Protocol,
        
        [Parameter()]
        [int]$Timeout         = $SplunkDefaultObject.Timeout,
		
		[Parameter()]
        [System.Management.Automation.PSCredential]$Credential = $SplunkDefaultObject.Credential,
		
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

	<#
        .Synopsis 
            Returns users for the targeted Splunk instance.
            
        .Description
            Returns users for the targeted Splunk instance. These are found in the Splunk web interface Manager » Access controls » Users 
        
		.Parameter UserName
			User to return. Returns nothing if user is not found.
			
        .Parameter ComputerName
            Name of the Splunk instance to get the settings for (Default is $SplunkDefaultObject.ComputerName.)
        
		.Parameter Port
            Port of the REST Instance (i.e. 8089) (Default is $SplunkDefaultObject.Port.)
        
		.Parameter Protocol
            Protocol to use to access the REST API must be 'http' or 'https' (Default is $SplunkDefaultObject.Protocol.)
        
		.Parameter Timeout
            How long to wait for the REST API to respond (Default is $SplunkDefaultObject.Timeout.)	
			
        .Parameter Credential
            Credential object with the user name and password used to access the REST API (Default is $SplunkDefaultObject.Credential.)	
			
		.Example
            Get-SplunkdUser
            Description
            -----------
            Gets the users for the targeted Splunk instance using the $SplunkDefaultObject settings.
    
		.Example
            Get-SplunkdUser -UserName admin
            Description
            -----------
            Returns the admin user for the targeted Splunk instance using the $SplunkDefaultObject settings.
			
        .Example
            Get-SplunkdUser -ComputerName MySplunkInstance -Port 8089 -Protocol https -Timeout 5000 -Credential $MyCreds
            Description
            -----------
            Gets the users for MySplunkInstance connecting on port 8089 with a 5sec timeout.
            
        .Example
            $SplunkServers | Get-SplunkdUser
            Description
            -----------
            Gets the users for each Splunk server in the pipeline using the $SplunkDefaultObject settings.
        
		.Example
            $SplunkServers | Get-SplunkdUser -Port 8089 -Protocol https -Timeout 5000 -Credential $MyCreds
            Description
            -----------
            Gets the users for each Splunk server in the pipeline connecting on port 8089 with a 5sec timeout and using credentials provided.
			
        .OUTPUTS
            PSObject
            
        .Notes
	        NAME:      Get-SplunkdUser 
	        AUTHOR:    Splunk\bshell
	        Website:   www.splunk.com
	        #Requires -Version 2.0
    #>
	
	[Cmdletbinding()]
    Param(
	
		[Parameter()]
		[STRING]$UserName,
		
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]$ComputerName = $SplunkDefaultObject.ComputerName,
        
        [Parameter()]
        [int]$Port            = $SplunkDefaultObject.Port,
        
        [Parameter()]
		[ValidateSet("http", "https")]
        [STRING]$Protocol     = $SplunkDefaultObject.Protocol,
        
        [Parameter()]
        [int]$Timeout         = $SplunkDefaultObject.Timeout,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential = $SplunkDefaultObject.Credential
        
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

#endregion Authentication

################################################################################

#region SplunkD

#region Get-Splunkd

function Get-Splunkd
{

	<#
        .Synopsis 
            Gets the values set for the targeted Splunk instance.
            
        .Description
            Gets the values set for the targeted Splunk instance. These are the settings found in the Splunk web interface Manager » System settings » General settings
            
        .Parameter ComputerName
            Name of the Splunk instance to get the settings for (Default is $SplunkDefaultObject.ComputerName.)
        
		.Parameter Port
            Port of the REST Instance (i.e. 8089) (Default is $SplunkDefaultObject.Port.)
        
		.Parameter Protocol
            Protocol to use to access the REST API must be 'http' or 'https' (Default is $SplunkDefaultObject.Protocol.)
        
		.Parameter Timeout
            How long to wait for the REST API to respond (Default is $SplunkDefaultObject.Timeout.)	
			
        .Parameter Credential
            Credential object with the user name and password used to access the REST API (Default is $SplunkDefaultObject.Credential.)	
			
		.Example
            Get-Splunkd
            Description
            -----------
            Gets the values set for the targeted Splunk instance using the $SplunkDefaultObject settings.
    
        .Example
            Get-Splunkd -ComputerName MySplunkInstance -Port 8089 -Protocol https -Timeout 5000 -Credential $MyCreds
            Description
            -----------
            Gets the values set for MySplunkInstance connecting on port 8089 with a 5sec timeout.
            
        .Example
            $SplunkServers | Get-Splunkd
            Description
            -----------
            Gets the values set for each Splunk server in the pipeline using the $SplunkDefaultObject settings.
        
		.Example
            $SplunkServers | Get-Splunkd -Port 8089 -Protocol https -Timeout 5000 -Credential $MyCreds
            Description
            -----------
            Gets the values set for each Splunk server in the pipeline connecting on port 8089 with a 5sec timeout and using credentials provided.
			
        .OUTPUTS
            PSObject
            
        .Notes
	        NAME:      Get-Splunkd 
	        AUTHOR:    Splunk\bshell
	        Website:   www.splunk.com
	        #Requires -Version 2.0
    #>
	
	[Cmdletbinding()]
    Param(
	
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]$ComputerName = $SplunkDefaultObject.ComputerName,
        
        [Parameter()]
        [int]$Port            = $SplunkDefaultObject.Port,
        
        [Parameter()]
		[ValidateSet("http", "https")]
        [STRING]$Protocol     = $SplunkDefaultObject.Protocol,
        
        [Parameter()]
        [int]$Timeout         = $SplunkDefaultObject.Timeout,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential = $SplunkDefaultObject.Credential
        
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
				Write-Verbose " [Get-Splunkd] :: Creating Hash Table to be used to create Splunk.SDK.ServiceStatus"
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
				
				# Creating Splunk.SDK.ServiceStatus
			    $obj = New-Object PSObject -Property $MyObj
			    $obj.PSTypeNames.Clear()
			    $obj.PSTypeNames.Add('Splunk.SDK.Splunkd.Setting')
			    $obj
			}
			else
			{
				Write-Verbose " [Get-Splunkd] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
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

	<#
        .Synopsis 
            Tests the targeted Splunk instance for a response.
            
        .Description
            Tests the targeted Splunk instance for a response. Returns $True if the Splunk Instance responds or $False if it encounters a problem.
            
        .Parameter ComputerName
            Name of the Splunk instance to test (Default is $SplunkDefaultObject.ComputerName.)
        
		.Parameter Port
            Port of the REST Instance (i.e. 8089) (Default is $SplunkDefaultObject.Port.)
        
		.Parameter Protocol
            Protocol to use to access the REST API must be 'http' or 'https' (Default is $SplunkDefaultObject.Protocol.)
        
		.Parameter Timeout
            How long to wait for the REST API to respond (Default is $SplunkDefaultObject.Timeout.)	
			
        .Parameter Credential
            Credential object with the user name and password used to access the REST API (Default is $SplunkDefaultObject.Credential.)	
			
		.Example
            Test-Splunkd
            Description
            -----------
            Test the targeted Splunk instance using the $SplunkDefaultObject settings.
    
        .Example
            Test-Splunkd -ComputerName MySplunkInstance -Port 8089 -Protocol https -Timeout 5000 -Credential $MyCreds
            Description
            -----------
            Test MySplunkInstance connecting on port 8089 with a 5sec timeout.
            
        .Example
            $SplunkServers | Test-Splunkd
            Description
            -----------
            Test each Splunk server in the pipeline using the $SplunkDefaultObject settings.
        
		.Example
            $SplunkServers | Test-Splunkd -Port 8089 -Protocol https -Timeout 5000 -Credential $MyCreds
            Description
            -----------
            Test each Splunk server in the pipeline connecting on port 8089 with a 5sec timeout and using credentials provided.
			
        .OUTPUTS
            PSObject
            
        .Notes
	        NAME:      Test-Splunkd 
	        AUTHOR:    Splunk\bshell
	        Website:   www.splunk.com
	        #Requires -Version 2.0
    #>
	
	[Cmdletbinding()]
    Param(
	
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]$ComputerName = $SplunkDefaultObject.ComputerName,
        
        [Parameter()]
        [int]$Port            = $SplunkDefaultObject.Port,
        
        [Parameter()]
        [STRING]$Protocol     = $SplunkDefaultObject.Protocol,
        
        [Parameter()]
        [int]$Timeout         = $SplunkDefaultObject.Timeout,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential = $SplunkDefaultObject.Credential,
		
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
				$True
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

	<#
        .Synopsis 
            Sets the values for the targeted Splunk instance.
            
        .Description
            Sets the values for the targeted Splunk instance. These are the settings found in the Splunk web interface Manager » System settings » General settings
            
        .Parameter ComputerName
            Name of the Splunk instance to set the settings for (Default is $SplunkDefaultObject.ComputerName.)
        
		.Parameter Port
            Port of the REST Instance (i.e. 8089) (Default is $SplunkDefaultObject.Port.)
        
		.Parameter Protocol
            Protocol to use to access the REST API must be 'http' or 'https' (Default is $SplunkDefaultObject.Protocol.)
        
		.Parameter Timeout
            How long to wait for the REST API to respond (Default is $SplunkDefaultObject.Timeout.)	
			
        .Parameter Credential
            Credential object with the user name and password used to access the REST API (Default is $SplunkDefaultObject.Credential.)	
		
		.Parameter ServerName
			Value to use for the Splunk server name.
			
		.Parameter DefaultHostName
			Sets the host field value for all events coming from this server.

		.Parameter MangementPort
			Port that Splunk Web uses to communicate with the splunkd process. This port is also used for distributed search.
		
		.Parameter SSOTrustedIP
			The IP address to accept trusted logins from. Only set this if you are using single sign-on (SSO) with a proxy server for authentication.
		
		.Parameter WebPort,
			Port to use for Splunk Web.
			
		.Parameter SessionTimeout
			Set the Splunk Web session timeout. Use the same notation as relative time modifiers, for example 3h, 100s, 6d.

		.Parameter IndexPath
			Path to Idexese
		
		.Parameter MinFreeSpace
			Pause indexing if free disk space (in MB) falls below.
		
		.Parameter Restart
			Restarts the Splunkd Services after making changes. 
		
		.Example
            Set-Splunkd -SessionTimeout 2h
            Description
            -----------
            Sets the 'sessionTimeout' to '2h' on the targeted Splunk instance using the $SplunkDefaultObject settings.
    
        .Example
            Set-Splunkd -SessionTimeout 2h -ComputerName MySplunkInstance -Port 8089 -Protocol https -Timeout 5000 -Credential $MyCreds
            Description
            -----------
            Sets the 'sessionTimeout' to '2h' on MySplunkInstance connecting on port 8089 with a 5sec timeout.
            
        .Example
            $SplunkServers | Set-Splunkd -SessionTimeout 2h
            Description
            -----------
            Sets the 'sessionTimeout' to '2h' on each Splunk server in the pipeline using the $SplunkDefaultObject settings.
        
		.Example
            $SplunkServers | Set-Splunkd -SessionTimeout 2h -Port 8089 -Protocol https -Timeout 5000 -Credential $MyCreds
            Description
            -----------
            Sets the 'sessionTimeout' to '2h' on each Splunk server in the pipeline connecting on port 8089 with a 5sec timeout and using credentials provided.
			
        .OUTPUTS
            PSObject
            
        .Notes
	        NAME:      Set-Splunkd 
	        AUTHOR:    Splunk\bshell
	        Website:   www.splunk.com
	        #Requires -Version 2.0
    #>

	[Cmdletbinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
    Param(
	
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]$ComputerName = $SplunkDefaultObject.ComputerName,
        
        [Parameter()]
        [int]$Port            = $SplunkDefaultObject.Port,
        
        [Parameter()]
        [STRING]$Protocol     = $SplunkDefaultObject.Protocol,
        
        [Parameter()]
        [INT]$Timeout         = $SplunkDefaultObject.Timeout,
		
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
        [System.Management.Automation.PSCredential]$Credential = $SplunkDefaultObject.Credential,
		
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

	<#
        .Synopsis 
            Restarts Splunkd and SplunkWeb on targeted Splunk instance.
            
        .Description
            Restarts Splunkd and SplunkWeb on targeted Splunk instance. Splunk Web will only be restarted if the services is started.
            
        .Parameter ComputerName
            Name of the Splunk instance to restart services on (Default is $SplunkDefaultObject.ComputerName.)
        
		.Parameter Port
            Port of the REST Instance (i.e. 8089) (Default is $SplunkDefaultObject.Port.)
        
		.Parameter Protocol
            Protocol to use to access the REST API must be 'http' or 'https' (Default is $SplunkDefaultObject.Protocol.)
        
		.Parameter Timeout
            How long to wait for the REST API to respond (Default is $SplunkDefaultObject.Timeout.)	
			
        .Parameter Credential
            Credential object with the user name and password used to access the REST API (Default is $SplunkDefaultObject.Credential.)	
		
		.Parameter Force
			Suppresses the confirm prompt.
		
		.Parameter Wait
			Waits for the Splunk instance to respond before proceeding.
		
		.Parameter Native
			Restarts the services using native methods (Windows Only.)
			
		.Example
            Restart-SplunkService
            Description
            -----------
            Restarts the Splunk services using the $SplunkDefaultObject settings.
    
        .Example
            Restart-SplunkService -ComputerName MySplunkInstance -Port 8089 -Protocol https -Timeout 5000 -Credential $MyCreds
            Description
            -----------
            Restarts the Splunk services on MySplunkInstance connecting on port 8089 with a 5sec timeout.
            
        .Example
            $SplunkServers | Restart-SplunkService
            Description
            -----------
            Restarts the Splunk services on each Splunk server in the pipeline using the $SplunkDefaultObject settings.
        
		.Example
            $SplunkServers | Restart-SplunkService -Port 8089 -Protocol https -Timeout 5000 -Credential $MyCreds
            Description
            -----------
            Restarts the Splunk services on each Splunk server in the pipeline connecting on port 8089 with a 5sec timeout and using credentials provided.
			
        .OUTPUTS
            PSObject
            
        .Notes
	        NAME:      Restart-SplunkService 
	        AUTHOR:    Splunk\bshell
	        Website:   www.splunk.com
	        #Requires -Version 2.0
    #>
	
	[Cmdletbinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
    Param(
	
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]$ComputerName = $SplunkDefaultObject.ComputerName,
        
        [Parameter()]
        [int]$Port            = $SplunkDefaultObject.Port,
        
        [Parameter()]
        [STRING]$Protocol     = $SplunkDefaultObject.Protocol,
        
        [Parameter()]
        [int]$Timeout         = $SplunkDefaultObject.Timeout,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential = $SplunkDefaultObject.Credential,
		
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
						$SplunkD = Get-Splunkd -ComputerName $ComputerName -Port $Port -Protocol $Protocol -Credential $Credential
						if($SplunkD)
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

	<#
        .Synopsis 
            Gets the OS and Splunk version info for the targeted Splunk instance.
            
        .Description
            Gets the OS and Splunk version info for the targeted Splunk instance. 
			
        .Parameter ComputerName
            Name of the Splunk instance to get the settings for (Default is $SplunkDefaultObject.ComputerName.)
        
		.Parameter Port
            Port of the REST Instance (i.e. 8089) (Default is $SplunkDefaultObject.Port.)
        
		.Parameter Protocol
            Protocol to use to access the REST API must be 'http' or 'https' (Default is $SplunkDefaultObject.Protocol.)
        
		.Parameter Timeout
            How long to wait for the REST API to respond (Default is $SplunkDefaultObject.Timeout.)	
			
        .Parameter Credential
            Credential object with the user name and password used to access the REST API (Default is $SplunkDefaultObject.Credential.)	
			
		.Example
            Get-SplunkdVersion
            Description
            -----------
            Gets the OS and Splunk version info for the targeted Splunk instance using the $SplunkDefaultObject settings.
    
        .Example
            Get-SplunkdVersion -ComputerName MySplunkInstance -Port 8089 -Protocol https -Timeout 5000 -Credential $MyCreds
            Description
            -----------
            Gets the OS and Splunk version info for MySplunkInstance connecting on port 8089 with a 5sec timeout.
            
        .Example
            $SplunkServers | Get-SplunkdVersion
            Description
            -----------
            Gets the OS and Splunk version info for each Splunk server in the pipeline using the $SplunkDefaultObject settings.
        
		.Example
            $SplunkServers | Get-SplunkdVersion -Port 8089 -Protocol https -Timeout 5000 -Credential $MyCreds
            Description
            -----------
            Gets the OS and Splunk version info for each Splunk server in the pipeline connecting on port 8089 with a 5sec timeout and using credentials provided.
			
        .OUTPUTS
            PSObject
            
        .Notes
	        NAME:      Get-SplunkdVersion 
	        AUTHOR:    Splunk\bshell
	        Website:   www.splunk.com
	        #Requires -Version 2.0
    #>
	
	[Cmdletbinding()]
    Param(
	
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]$ComputerName = $SplunkDefaultObject.ComputerName,
        
        [Parameter()]
        [int]$Port            = $SplunkDefaultObject.Port,
        
        [Parameter()]
		[ValidateSet("http", "https")]
        [STRING]$Protocol     = $SplunkDefaultObject.Protocol,
        
        [Parameter()]
        [int]$Timeout         = $SplunkDefaultObject.Timeout,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential = $SplunkDefaultObject.Credential
        
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

	<#
        .Synopsis 
            Gets the logging values set for the targeted Splunk instance.
            
        .Description
            Gets the logging values set for the targeted Splunk instance. These are the settings found in the Splunk web interface Manager » System settings » System logging
        
		.Parameter Filter
            A regular expression of the Logger to get. (Default is ".*")
            
        .Parameter Name
            Name of the Logger to get.
		
        .Parameter Level
            If passed will return logger entries with the provided level.
            
        .Parameter ComputerName
            Name of the Splunk instance to get the log settings for (Default is $SplunkDefaultObject.ComputerName.)
        
		.Parameter Port
            Port of the REST Instance (i.e. 8089) (Default is $SplunkDefaultObject.Port.)
        
		.Parameter Protocol
            Protocol to use to access the REST API must be 'http' or 'https' (Default is $SplunkDefaultObject.Protocol.)
        
		.Parameter Timeout
            How long to wait for the REST API to respond (Default is $SplunkDefaultObject.Timeout.)	
			
        .Parameter Credential
            Credential object with the user name and password used to access the REST API (Default is $SplunkDefaultObject.Credential.)	
			
		.Example
            Get-SplunkdLogging
            Description
            -----------
            Returns all loggers on the targeted Splunk instance using the $SplunkDefaultObject settings.
    
		.Example
            Get-SplunkdLogging -Name AdminHandler:Monitor
            Description
            -----------
            Returns AdminHandler:Monitor logger on the targeted Splunk instance using the $SplunkDefaultObject settings.
		
		.Example
            Get-SplunkdLogging -filter monitor
            Description
            -----------
            Returns all loggers that match 'monitor' on the targeted Splunk instance using the $SplunkDefaultObject settings.
		
        .Example
            Get-SplunkdLogging -level debug
            Description
            -----------
            Returns all loggers that match 'monitor' on the targeted Splunk instance using the $SplunkDefaultObject settings.
        
        .Example
            Get-SplunkdLogging -ComputerName MySplunkInstance -Port 8089 -Protocol https -Timeout 5000 -Credential $MyCreds
            Description
            -----------
            Returns all loggers for MySplunkInstance connecting on port 8089 with a 5sec timeout.
            
        .Example
            $SplunkServers | Get-SplunkdLogging
            Description
            -----------
            Returns all loggers on each Splunk server in the pipeline using the $SplunkDefaultObject settings.
        
		.Example
            $SplunkServers | Get-SplunkdLogging -Port 8089 -Protocol https -Timeout 5000 -Credential $MyCreds
            Description
            -----------
            Returns all loggers on each Splunk server in the pipeline connecting on port 8089 with a 5sec timeout and using credentials provided.
			
        .OUTPUTS
            PSObject
            
        .Notes
	        NAME:      Get-SplunkdLogging 
	        AUTHOR:    Splunk\bshell
	        Website:   www.splunk.com
	        #Requires -Version 2.0
    #>
	
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
        [String]$ComputerName = $SplunkDefaultObject.ComputerName,
        
        [Parameter()]
        [int]$Port            = $SplunkDefaultObject.Port,
        
        [Parameter()]
		[ValidateSet("http", "https")]
        [STRING]$Protocol     = $SplunkDefaultObject.Protocol,
        
        [Parameter()]
        [int]$Timeout         = $SplunkDefaultObject.Timeout,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential = $SplunkDefaultObject.Credential
        
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
        [String]$ComputerName = $SplunkDefaultObject.ComputerName,
        
        [Parameter()]
        [int]$Port            = $SplunkDefaultObject.Port,
        
        [Parameter()]
		[ValidateSet("http", "https")]
        [STRING]$Protocol     = $SplunkDefaultObject.Protocol,
        
        [Parameter()]
        [int]$Timeout         = $SplunkDefaultObject.Timeout,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential = $SplunkDefaultObject.Credential
        
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

################################################################################

#region Deployment

#region Get-SplunkServerClass

function Get-SplunkServerClass
{
	[Cmdletbinding(DefaultParameterSetName="byFilter")]
    Param(
	    
        [Parameter(Position=0,ParameterSetName="byFilter")]
        [STRING]$Filter = '.*',
	
		[Parameter(Position=0,ParameterSetName="byName")]
		[STRING]$Name,
       
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]$ComputerName = $SplunkDefaultObject.ComputerName,
        
        [Parameter()]
        [int]$Port            = $SplunkDefaultObject.Port,
        
        [Parameter()]
		[ValidateSet("http", "https")]
        [STRING]$Protocol     = $SplunkDefaultObject.Protocol,
        
        [Parameter()]
        [int]$Timeout         = $SplunkDefaultObject.Timeout,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential = $SplunkDefaultObject.Credential
        
    )
	
	Begin
	{
		Write-Verbose " [Get-SplunkServerClass] :: Starting..."
        
        $ParamSetName = $pscmdlet.ParameterSetName
        switch ($ParamSetName)
        {
            "byFilter"  { $WhereFilter = { $_.Name -match $Filter } } 
            "byName"    { $WhereFilter = { $_.Name -ceq   $Name } }
        }
        
	}
	Process
	{
		Write-Verbose " [Get-SplunkServerClass] :: Parameters"
        Write-Verbose " [Get-SplunkServerClass] ::  - ParameterSet = $ParamSetName"
		Write-Verbose " [Get-SplunkServerClass] ::  - ComputerName = $ComputerName"
		Write-Verbose " [Get-SplunkServerClass] ::  - Port         = $Port"
		Write-Verbose " [Get-SplunkServerClass] ::  - Protocol     = $Protocol"
		Write-Verbose " [Get-SplunkServerClass] ::  - Timeout      = $Timeout"
		Write-Verbose " [Get-SplunkServerClass] ::  - Credential   = $Credential"
        Write-Verbose " [Get-SplunkServerClass] ::  - WhereFilter  = $WhereFilter"

		Write-Verbose " [Get-SplunkServerClass] :: Setting up Invoke-APIRequest parameters"
		$InvokeAPIParams = @{
			ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
			Endpoint     = '/services/deployment/serverclass' 
			Verbose      = $VerbosePreference -eq "Continue"
		}
			
		Write-Verbose " [Get-SplunkServerClass] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
		try
		{
			[XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams
        }
		catch
		{
			Write-Verbose " [Get-SplunkServerClass] :: Invoke-SplunkAPIRequest threw an exception: $_"
            Write-Error $_
		}
        try
        {
			if($Results -and ($Results -is [System.Xml.XmlDocument]))
			{
                foreach($Entry in $Results.feed.entry)
                {
				    $MyObj = @{
                        ComputerName                = $ComputerName
                        Name                        = $Entry.Title
                        FilterType                  = $null
                        Blacklist                   = $null
                        RestartSplunkd              = $null
                        ContinueMatching            = $null
                        MachineTypes                = $null
                        RepositoryLocation          = $null
                        RestartSplunkWeb            = $null
                        Whitelist                   = $null
                        Disabled                    = $null
                        TmpFolder                   = $null
                        StateOnClient               = $null
                        TargetRepositoryLocation    = $null
                        Endpoint                    = $null
                    }
    				Write-Verbose " [Get-SplunkServerClass] :: Creating Hash Table to be used to create Splunk.SDK.Deployment.ServerClass"
    				switch ($Entry.content.dict.key)
    				{
                        { $_.name -eq "serverClass" }               { $Myobj.ServerClass              = $_.'#text' ; continue }
                        { $_.name -eq "filterType" }                { $Myobj.FilterType               = $_.'#text' ; continue }
                        { $_.name -eq "blacklist" }                 { $Myobj.Blacklist                = $_.'#text' ; continue }
                        { $_.name -eq "restartSplunkd" }            { $Myobj.RestartSplunkd           = [bool]([int]$_.'#text') ; continue }
                        { $_.name -eq "continueMatching" }          { $Myobj.ContinueMatching         = [bool]([int]$_.'#text') ; continue }
                        { $_.name -eq "machineTypes" }              { $Myobj.MachineTypes             = $_.'#text' ; continue }
                        { $_.name -eq "repositoryLocation" }        { $Myobj.RepositoryLocation       = $_.'#text' ; continue }
                        { $_.name -eq "restartSplunkWeb" }          { $Myobj.RestartSplunkWeb         = [bool]([int]$_.'#text') ; continue }
                        { $_.name -eq "whitelist" }                 { $Myobj.Whitelist                = $_.'#text' ; continue }
                        { $_.name -eq "disabled" }                  { $Myobj.Disabled                 = [bool]([int]$_.'#text') ; continue }
                        { $_.name -eq "tmpFolder" }                 { $Myobj.TmpFolder                = $_.'#text' ; continue }
                        { $_.name -eq "stateOnClient" }             { $Myobj.StateOnClient            = $_.'#text' ; continue }
                        { $_.name -eq "targetRepositoryLocation" }  { $Myobj.TargetRepositoryLocation = $_.'#text' ; continue }
                        { $_.name -eq "endpoint" }                  { $Myobj.Endpoint                 = $_.'#text' ; continue }
    		        	Default		                                { $Myobj.Add($_.Name,$_.'#text')               ; continue }
    				}
    				
    				# Creating Splunk.SDK.ServiceStatus
    			    $obj = New-Object PSObject -Property $MyObj
    			    $obj.PSTypeNames.Clear()
    			    $obj.PSTypeNames.Add('Splunk.SDK.Deployment.ServerClass')
    			    $obj | Where $WhereFilter
                }
			}
			else
			{
				Write-Verbose " [Get-SplunkServerClass] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
			}
		}
		catch
		{
			Write-Verbose " [Get-SplunkServerClass] :: Get-SplunkServerClass threw an exception: $_"
            Write-Error $_
		}
	}
	End
	{
		Write-Verbose " [Get-SplunkServerClass] :: =========    End   ========="
	}
} # Get-SplunkServerClass

#endregion Get-SplunkServerClass

#region New-SplunkServerClass

function New-SplunkServerClass
{
	[Cmdletbinding(SupportsShouldProcess=$true)]
    Param(
	    
		[Parameter(Mandatory=$True)]
		[STRING]$Name,
        
        [Parameter()]
        [STRING[]]$Blacklist,
        
        [Parameter()]
        [STRING[]]$Whitelist,
        
        [Parameter()]
        [SWITCH]$ContinueMatching,
        
        [Parameter()]
        [STRING]$Endpoint,
        
        [Parameter()]
        [STRING]$FilterType,
        
        [Parameter()]
        [STRING]$RepositoryLocation,
        
        [Parameter()]
        [STRING]$TargetRepositoryLocation,
        
        [Parameter()]
        [STRING]$TmpFolder,
       
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]$ComputerName = $SplunkDefaultObject.ComputerName,
        
        [Parameter()]
        [int]$Port            = $SplunkDefaultObject.Port,
        
        [Parameter()]
		[ValidateSet("http", "https")]
        [STRING]$Protocol     = $SplunkDefaultObject.Protocol,
        
        [Parameter()]
        [int]$Timeout         = $SplunkDefaultObject.Timeout,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential = $SplunkDefaultObject.Credential
        
    )
	
	Begin
	{
		Write-Verbose " [New-SplunkServerClass] :: Starting..."
        
	}
	Process
	{
    
        
		Write-Verbose " [New-SplunkServerClass] :: Parameters"
        Write-Verbose " [New-SplunkServerClass] ::  - ParameterSet = $ParamSetName"
		Write-Verbose " [New-SplunkServerClass] ::  - ComputerName = $ComputerName"
		Write-Verbose " [New-SplunkServerClass] ::  - Port         = $Port"
		Write-Verbose " [New-SplunkServerClass] ::  - Protocol     = $Protocol"
		Write-Verbose " [New-SplunkServerClass] ::  - Timeout      = $Timeout"
		Write-Verbose " [New-SplunkServerClass] ::  - Credential   = $Credential"
        Write-Verbose " [New-SplunkServerClass] ::  - WhereFilter  = $WhereFilter"
        
        
        Write-Verbose " [New-SplunkServerClass] :: checking for existance of server class"
        $InvokeAPIParams = @{
        			ComputerName = $ComputerName
        			Port         = $Port
        			Protocol     = $Protocol
        			Timeout      = $Timeout
        			Credential   = $Credential
                    Name         = $Name
                }
        $ServerClass = Get-SplunkServerClass @InvokeAPIParams
        
        if($ServerClass)
        {
            Write-Host " [New-SplunkServerClass] :: Server Class [$Name] already exist"
            Return
        }

		Write-Verbose " [New-SplunkServerClass] :: Setting up Invoke-APIRequest parameters"
		$InvokeAPIParams = @{
			ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
			Endpoint     = '/services/deployment/serverclass' 
			Verbose      = $VerbosePreference -eq "Continue"
		}
        
        $MyArgs = @{}
        
        Write-Verbose " [New-SplunkServerClass] :: Adding Name [$Name] to `$MyArgs"
        $MyArgs.Add("name",$Name)
        
        if($Blacklist)
        {
            $i = 0
            foreach($Entry in $Blacklist)
            {
                Write-Verbose " [New-SplunkServerClass] :: Adding blacklist entry [$Entry] to `$MyArgs"
                $MyArgs.Add("blacklist.${i}",$Entry)
                $i++
            }   
        }
        
        if($Whitelist)
        {
            $i = 0
            foreach($Entry in $Whitelist)
            {
                Write-Verbose " [New-SplunkServerClass] :: Adding whitelist entry [$Entry] to `$MyArgs"
                $MyArgs.Add("whitelist.${i}",$Entry)
                $i++
            }
        }
        
        if($ContinueMatching)
        {
            Write-Verbose " [New-SplunkServerClass] :: Adding ContinueMatching [$ContinueMatching] to `$MyArgs"
            $MyArgs.Add("continueMatching",$True)
        }
        
        if($Endpoint)
        {
            Write-Verbose " [New-SplunkServerClass] :: Adding Endpoint [$Endpoint] to `$MyArgs"
            $MyArgs.Add("endpoint",$Endpoint)
        }
        
        if($FilterType)
        {
            Write-Verbose " [New-SplunkServerClass] :: Adding FilterType [$FilterType] to `$MyArgs"
            $MyArgs.Add("filterType",$FilterType)
        }
        
        if($RepositoryLocation)
        {
            Write-Verbose " [New-SplunkServerClass] :: Adding RepositoryLocation [$RepositoryLocation] to `$MyArgs"
            $MyArgs.Add("repositoryLocation",$RepositoryLocation)
        }
        
        if($TargetRepositoryLocation)
        {
            Write-Verbose " [New-SplunkServerClass] :: Adding TargetRepositoryLocation [$TargetRepositoryLocation] to `$MyArgs"
            $MyArgs.Add("targetRepositoryLocation",$TargetRepositoryLocation)
        }
        
        if($TmpFolder)
        {
            Write-Verbose " [New-SplunkServerClass] :: Adding TmpFolder [$TmpFolder] to `$MyArgs"
            $MyArgs.Add("tmpFolder",$TmpFolder)
        }
			
		Write-Verbose " [New-SplunkServerClass] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
		try
		{
            if($PSCmdlet.ShouldProcess($ComputerName,"Creating new server class $Name"))
    		{
			    [XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams -Arguments $MyArgs -RequestType POST 
            }
        }
		catch
		{
			Write-Verbose " [New-SplunkServerClass] :: Invoke-SplunkAPIRequest threw an exception: $_"
            Write-Error $_
		}
        try
        {
			if($Results -and ($Results -is [System.Xml.XmlDocument]))
			{
                $InvokeAPIParams = @{
        			ComputerName = $ComputerName
        			Port         = $Port
        			Protocol     = $Protocol
        			Timeout      = $Timeout
        			Credential   = $Credential
                    Name         = $Name
                }
                Get-SplunkServerClass @InvokeAPIParams
			}
			else
			{
				Write-Verbose " [New-SplunkServerClass] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
			}
		}
		catch
		{
			Write-Verbose " [New-SplunkServerClass] :: Get-SplunkServerClass threw an exception: $_"
            Write-Error $_
		}
	}
	End
	{
		Write-Verbose " [New-SplunkServerClass] :: =========    End   ========="
	}
} # New-SplunkServerClass

#endregion New-SplunkServerClass

#region Invoke-SplunkDeploymentServerReload

function Invoke-SplunkDeploymentServerReload
{
	[Cmdletbinding()]
    Param(

        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]$ComputerName = $SplunkDefaultObject.ComputerName,
        
        [Parameter()]
        [int]$Port            = $SplunkDefaultObject.Port,
        
        [Parameter()]
		[ValidateSet("http", "https")]
        [STRING]$Protocol     = $SplunkDefaultObject.Protocol,
        
        [Parameter()]
        [int]$Timeout         = $SplunkDefaultObject.Timeout,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential = $SplunkDefaultObject.Credential
        
    )
	
	Begin
	{
		Write-Verbose " [Invoke-SplunkDeploymentServerReload] :: Starting..."
	}
	Process
	{
		Write-Verbose " [Invoke-SplunkDeploymentServerReload] :: Parameters"
		Write-Verbose " [Invoke-SplunkDeploymentServerReload] ::  - ComputerName = $ComputerName"
		Write-Verbose " [Invoke-SplunkDeploymentServerReload] ::  - Port         = $Port"
		Write-Verbose " [Invoke-SplunkDeploymentServerReload] ::  - Protocol     = $Protocol"
		Write-Verbose " [Invoke-SplunkDeploymentServerReload] ::  - Timeout      = $Timeout"
		Write-Verbose " [Invoke-SplunkDeploymentServerReload] ::  - Credential   = $Credential"

		Write-Verbose " [Invoke-SplunkDeploymentServerReload] :: Setting up Invoke-APIRequest parameters"
		$InvokeAPIParams = @{
			ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
			Endpoint     = '/services/deployment/server/_reload' 
			Verbose      = $VerbosePreference -eq "Continue"
		}
			
		Write-Verbose " [Invoke-SplunkDeploymentServerReload] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
		try
		{
			[XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams
        }
		catch
		{
			Write-Verbose " [Invoke-SplunkDeploymentServerReload] :: Invoke-SplunkAPIRequest threw an exception: $_"
            Write-Error $_
		}
        try
        {
			if($Results -and ($Results -is [System.Xml.XmlDocument]))
			{
                Write-Host "Reload of [$ComputerName] successful"
			}
			else
			{
				Write-Verbose " [Invoke-SplunkDeploymentServerReload] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
			}
		}
		catch
		{
			Write-Verbose " [Invoke-SplunkDeploymentServerReload] :: Get-SplunkServerClass threw an exception: $_"
            Write-Error $_
		}
	}
	End
	{
		Write-Verbose " [Invoke-SplunkDeploymentServerReload] :: =========    End   ========="
	}
} # Invoke-SplunkDeploymentServerReload

#endregion Invoke-SplunkDeploymentServerReload

#region Disable-SplunkServerClass

function Disable-SplunkServerClass
{
	[Cmdletbinding(SupportsShouldProcess=$true,DefaultParameterSetName="byPipeline")]
    Param(
	    
        [Parameter(Position=0,ParameterSetName="byFilter")]
        [STRING]$Filter = '.*',
	
		[Parameter(Position=0,ParameterSetName="byName")]
		[STRING]$Name,
        
        [Parameter(ValueFromPipeline=$True,ParameterSetName="byPipeline")]
        [Object]$ServerClass,
	
        [Parameter()]
        [String]$ComputerName = $SplunkDefaultObject.ComputerName,
        
        [Parameter()]
        [int]$Port            = $SplunkDefaultObject.Port,
        
        [Parameter()]
		[ValidateSet("http", "https")]
        [STRING]$Protocol     = $SplunkDefaultObject.Protocol,
        
        [Parameter()]
        [int]$Timeout         = $SplunkDefaultObject.Timeout,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential = $SplunkDefaultObject.Credential,
        
        [Parameter()]
        [SWITCH]$Force
        
    )
	
	Begin
	{
		Write-Verbose " [Disable-SplunkServerClass] :: Starting..."
        $ParamSetName = $pscmdlet.ParameterSetName
        $GetSplunkServerClassParams = @{
            ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
        }
        
        switch ($ParamSetName)
        {
            "byFilter"  { $ServerClasses = Get-SplunkServerClass @GetSplunkServerClassParams -Filter $Filter } 
            "byName"    { $ServerClasses = Get-SplunkServerClass @GetSplunkServerClassParams -Name $Name }
        }
	}
	Process
	{
		Write-Verbose " [Disable-SplunkServerClass] :: Parameters"
        Write-Verbose " [Disable-SplunkServerClass] ::  - ParameterSet = $ParamSetName"
		Write-Verbose " [Disable-SplunkServerClass] ::  - ComputerName = $ComputerName"
		Write-Verbose " [Disable-SplunkServerClass] ::  - Port         = $Port"
		Write-Verbose " [Disable-SplunkServerClass] ::  - Protocol     = $Protocol"
		Write-Verbose " [Disable-SplunkServerClass] ::  - Timeout      = $Timeout"
		Write-Verbose " [Disable-SplunkServerClass] ::  - Credential   = $Credential"
        
        if($ServerClass -and $ServerClass.PSTypeNames -contains "Splunk.SDK.Deployment.ServerClass")
		{
			$ServerClasses = $ServerClass
		}
        
        foreach($Class in $ServerClasses)
        {
            $ClassName = $Class.Name
    		Write-Verbose " [Disable-SplunkServerClass] :: Setting up Invoke-APIRequest parameters for [$ClassName]"
    		$InvokeAPIParams = @{
    			ComputerName = $ComputerName
    			Port         = $Port
    			Protocol     = $Protocol
    			Timeout      = $Timeout
    			Credential   = $Credential
    			Endpoint     = '/services/deployment/serverclass/{0}/disable' -f $ClassName
    			Verbose      = $VerbosePreference -eq "Continue"
    		}
    			
    		Write-Verbose " [Disable-SplunkServerClass] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
    		try
    		{
                if($Force -or $PSCmdlet.ShouldProcess($ComputerName,"Disabling $ClassName"))
    			{
    			    [XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams
                    try
                    {
            			if($Results)
            			{
                            $GetSplunkServerClassParams = @{
                                ComputerName = $ComputerName
                    			Port         = $Port
                    			Protocol     = $Protocol
                    			Timeout      = $Timeout
                    			Credential   = $Credential
                                Verbose      = $VerbosePreference -eq "Continue"
                            }
                            Get-SplunkServerClass @GetSplunkServerClassParams -Name $ClassName
            			}
            			else
            			{
            				Write-Verbose " [Disable-SplunkServerClass] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
            			}
            		}
            		catch
            		{
            			Write-Verbose " [Disable-SplunkServerClass] :: Get-SplunkServerClass threw an exception: $_"
                        Write-Error $_
            		}
                }
            }
    		catch
    		{
    			Write-Verbose " [Disable-SplunkServerClass] :: Invoke-SplunkAPIRequest threw an exception: $_"
                Write-Error $_
    		}
            
        }
	}
	End
	{
		Write-Verbose " [Disable-SplunkServerClass] :: =========    End   ========="
	}
} # Disable-SplunkServerClass

#endregion Disable-SplunkServerClass 

#region Enable-SplunkServerClass

function Enable-SplunkServerClass
{
	[Cmdletbinding(SupportsShouldProcess=$true,DefaultParameterSetName="byPipeline")]
    Param(
	    
        [Parameter(Position=0,ParameterSetName="byFilter")]
        [STRING]$Filter = '.*',
	
		[Parameter(Position=0,ParameterSetName="byName")]
		[STRING]$Name,
        
        [Parameter(Position=0,ValueFromPipeline=$True,ParameterSetName="byPipeline")]
        [Object]$ServerClass,
	
        [Parameter()]
        [String]$ComputerName = $SplunkDefaultObject.ComputerName,
        
        [Parameter()]
        [int]$Port            = $SplunkDefaultObject.Port,
        
        [Parameter()]
		[ValidateSet("http", "https")]
        [STRING]$Protocol     = $SplunkDefaultObject.Protocol,
        
        [Parameter()]
        [int]$Timeout         = $SplunkDefaultObject.Timeout,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential = $SplunkDefaultObject.Credential,
        
        [Parameter()]
        [SWITCH]$Force
        
    )
	
	Begin
	{
		Write-Verbose " [Enable-SplunkServerClass] :: Starting..."
        $ParamSetName = $pscmdlet.ParameterSetName
        $GetSplunkServerClassParams = @{
            ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
        }
        
        switch ($ParamSetName)
        {
            "byFilter"  { $ServerClasses = Get-SplunkServerClass @GetSplunkServerClassParams -Filter $Filter } 
            "byName"    { $ServerClasses = Get-SplunkServerClass @GetSplunkServerClassParams -Name $Name }
        }
	}
	Process
	{
		Write-Verbose " [Enable-SplunkServerClass] :: Parameters"
        Write-Verbose " [Enable-SplunkServerClass] ::  - ParameterSet = $ParamSetName"
		Write-Verbose " [Enable-SplunkServerClass] ::  - ComputerName = $ComputerName"
		Write-Verbose " [Enable-SplunkServerClass] ::  - Port         = $Port"
		Write-Verbose " [Enable-SplunkServerClass] ::  - Protocol     = $Protocol"
		Write-Verbose " [Enable-SplunkServerClass] ::  - Timeout      = $Timeout"
		Write-Verbose " [Enable-SplunkServerClass] ::  - Credential   = $Credential"
        
        if($ServerClass -and $ServerClass.PSTypeNames -contains "Splunk.SDK.Deployment.ServerClass")
		{
			$ServerClasses = $ServerClass
		}
        
        foreach($Class in $ServerClasses)
        {
            $ClassName = $Class.Name
    		Write-Verbose " [Enable-SplunkServerClass] :: Setting up Invoke-APIRequest parameters for [$ClassName]"
    		$InvokeAPIParams = @{
    			ComputerName = $ComputerName
    			Port         = $Port
    			Protocol     = $Protocol
    			Timeout      = $Timeout
    			Credential   = $Credential
    			Endpoint     = '/services/deployment/serverclass/{0}/enable' -f $ClassName
    			Verbose      = $VerbosePreference -eq "Continue"
    		}
    			
    		Write-Verbose " [Enable-SplunkServerClass] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
    		try
    		{
                if($Force -or $PSCmdlet.ShouldProcess($ComputerName,"Enabling $ClassName"))
    			{
    			    [XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams
                    try
                    {
            			if($Results)
            			{
                            $GetSplunkServerClassParams = @{
                                ComputerName = $ComputerName
                    			Port         = $Port
                    			Protocol     = $Protocol
                    			Timeout      = $Timeout
                    			Credential   = $Credential
                                Verbose      = $VerbosePreference -eq "Continue"
                            }
                            Get-SplunkServerClass @GetSplunkServerClassParams -Name $ClassName
            			}
            			else
            			{
            				Write-Verbose " [Enable-SplunkServerClass] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
            			}
            		}
            		catch
            		{
            			Write-Verbose " [Enable-SplunkServerClass] :: Get-SplunkServerClass threw an exception: $_"
                        Write-Error $_
            		}
                }
            }
    		catch
    		{
    			Write-Verbose " [Enable-SplunkServerClass] :: Invoke-SplunkAPIRequest threw an exception: $_"
                Write-Error $_
    		}
            
        }
	}
	End
	{
		Write-Verbose " [Enable-SplunkServerClass] :: =========    End   ========="
	}
} # Enable-SplunkServerClass

#endregion Enable-SplunkServerClass 

#region Get-SplunkDeploymentClient

function Get-SplunkDeploymentClient
{
    [Cmdletbinding(DefaultParameterSetName="byFilter")]
    Param(

        [Parameter(Position=0,ParameterSetName="byFilter")]
        [STRING]$Filter = '.*',
	
		[Parameter(Position=0,ParameterSetName="byName")]
		[STRING]$Name,

        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]$ComputerName = $SplunkDefaultObject.ComputerName,
        
        [Parameter()]
        [int]$Port            = $SplunkDefaultObject.Port,
        
        [Parameter()]
		[ValidateSet("http", "https")]
        [STRING]$Protocol     = $SplunkDefaultObject.Protocol,
        
        [Parameter()]
        [int]$Timeout         = $SplunkDefaultObject.Timeout,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential = $SplunkDefaultObject.Credential
        
    )
    Begin
	{
		Write-Verbose " [Get-SplunkDeploymentClient] :: Starting..."
        $ParamSetName = $pscmdlet.ParameterSetName
        
        switch ($ParamSetName)
        {
            "byFilter"  { $WhereFilter = { $_.Name -match $Filter } } 
            "byName"    { $WhereFilter = { $_.Name -eq    $Name } }
        }
	}
	Process
	{
		Write-Verbose " [Get-SplunkDeploymentClient] :: Parameters"
        Write-Verbose " [Get-SplunkDeploymentClient] ::  - ParameterSet = $ParamSetName"
		Write-Verbose " [Get-SplunkDeploymentClient] ::  - ComputerName = $ComputerName"
		Write-Verbose " [Get-SplunkDeploymentClient] ::  - Port         = $Port"
		Write-Verbose " [Get-SplunkDeploymentClient] ::  - Protocol     = $Protocol"
		Write-Verbose " [Get-SplunkDeploymentClient] ::  - Timeout      = $Timeout"
		Write-Verbose " [Get-SplunkDeploymentClient] ::  - Credential   = $Credential"
        Write-Verbose " [Get-SplunkDeploymentClient] ::  - WhereFilter  = $WhereFilter"

		Write-Verbose " [Get-SplunkDeploymentClient] :: Setting up Invoke-APIRequest parameters"
		$InvokeAPIParams = @{
			ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
			Endpoint     = '/servicesNS/nobody/system/deployment/server/default/default.Clients' 
			Verbose      = $VerbosePreference -eq "Continue"
		}
			
		Write-Verbose " [Get-SplunkDeploymentClient] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
		try
		{
			[XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams
        }
        catch
		{
			Write-Verbose " [Get-SplunkDeploymentClient] :: Invoke-SplunkAPIRequest threw an exception: $_"
            Write-Error $_
		}
        try
        {
			if($Results -and ($Results -is [System.Xml.XmlDocument]))
			{
				$MyObj = @{}
				Write-Verbose " [Get-SplunkDeploymentClient] :: Creating Hash Table to be used to create Splunk.SDK.Deployment.DeploymentClient"
				switch ($results.feed.entry.content.dict.key)
				{
		        	{$_.name -eq "build"}		    { $Myobj.Add("Build",$_.'#text')    ; continue }
					{$_.name -eq "ip"}	            { $Myobj.Add("IP",$_.'#text')       ; continue }
			        {$_.name -eq "hostname"}	    { $Myobj.Add("ComputerName",$_.'#text'); continue }
                    {$_.name -eq "mgmt"}		    { $Myobj.Add("MgmtPort",$_.'#text') ; continue }
                    {$_.name -eq "name"}		    { $Myobj.Add("Name",$_.'#text')     ; continue }
                    {$_.name -eq "phoneHomeTime"}	{ $Myobj.Add("LastUpdate",(ConvertFrom-SplunkTime $_.'#text')); continue }
                    {$_.name -eq "utsname"}		    { $Myobj.Add("utsname",$_.'#text')  ; continue }
                    {$_.name -eq "id"}		        { $Myobj.Add("ID",$_.'#text')       ; continue }
				}
				
				# Creating Splunk.SDK.ServiceStatus
			    $obj = New-Object PSObject -Property $MyObj
			    $obj.PSTypeNames.Clear()
			    $obj.PSTypeNames.Add('Splunk.SDK.Deployment.DeploymentClient')
			    $obj | Where-Object $WhereFilter
			}
			else
			{
				Write-Verbose " [Get-SplunkDeploymentClient] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
			}
		}
		catch
		{
			Write-Verbose " [Get-SplunkDeploymentClient] :: Get-SplunkDeploymentClient threw an exception: $_"
            Write-Error $_
		}
	}
	End
	{
		Write-Verbose " [Get-SplunkDeploymentClient] :: =========    End   ========="
	}

}    # Get-SplunkDeploymentClient

#endregion Get-SplunkDeploymentClient

#endregion Deployment

################################################################################

#region Splunk License

#region Get-SplunkLicenseFile

function Get-SplunkLicenseFile
{

	<#
        .Synopsis 
            Returns the licenses files registered for the targeted Splunk instance.
            
        .Description
            Returns the licenses files registered for the targeted Splunk instance. These are found in the Splunk web interface Manager » Licensing
            
        .Parameter ComputerName
            Name of the Splunk instance to get the licenses for (Default is $SplunkDefaultObject.ComputerName.)
        
		.Parameter Port
            Port of the REST Instance (i.e. 8089) (Default is $SplunkDefaultObject.Port.)
        
		.Parameter Protocol
            Protocol to use to access the REST API must be 'http' or 'https' (Default is $SplunkDefaultObject.Protocol.)
        
		.Parameter Timeout
            How long to wait for the REST API to respond (Default is $SplunkDefaultObject.Timeout.)	
			
        .Parameter Credential
            Credential object with the user name and password used to access the REST API (Default is $SplunkDefaultObject.Credential.)	
			
		.Example
            Get-SplunkLicenseFile
            Description
            -----------
            Gets the licenses for the targeted Splunk instance using the $SplunkDefaultObject settings.
    
        .Example
            Get-SplunkLicenseFile -ComputerName MySplunkInstance -Port 8089 -Protocol https -Timeout 5000 -Credential $MyCreds
            Description
            -----------
            Gets the licenses for MySplunkInstance connecting on port 8089 with a 5sec timeout.
            
        .Example
            $SplunkServers | Get-SplunkLicenseFile
            Description
            -----------
            Gets the licenses for each Splunk server in the pipeline using the $SplunkDefaultObject settings.
        
		.Example
            $SplunkServers | Get-SplunkLicenseFile -Port 8089 -Protocol https -Timeout 5000 -Credential $MyCreds
            Description
            -----------
            Gets the licenses for each Splunk server in the pipeline connecting on port 8089 with a 5sec timeout and using credentials provided.
			
        .OUTPUTS
            PSObject
            
        .Notes
	        NAME:      Get-SplunkLicenseFile 
	        AUTHOR:    Splunk\bshell
	        Website:   www.splunk.com
	        #Requires -Version 2.0
    #>
	
	[Cmdletbinding()]
    Param(
	
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]$ComputerName = $SplunkDefaultObject.ComputerName,
        
        [Parameter()]
        [int]$Port            = $SplunkDefaultObject.Port,
        
        [Parameter()]
		[ValidateSet("http", "https")]
        [STRING]$Protocol     = $SplunkDefaultObject.Protocol,
        
        [Parameter()]
        [int]$Timeout         = $SplunkDefaultObject.Timeout,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential = $SplunkDefaultObject.Credential,
        
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

#region Get-SplunkLicenseMessage

function Get-SplunkLicenseMessage
{
    [Cmdletbinding()]
    Param(

        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]$ComputerName = $SplunkDefaultObject.ComputerName,
        
        [Parameter()]
        [int]$Port            = $SplunkDefaultObject.Port,
        
        [Parameter()]
		[ValidateSet("http", "https")]
        [STRING]$Protocol     = $SplunkDefaultObject.Protocol,
        
        [Parameter()]
        [int]$Timeout         = $SplunkDefaultObject.Timeout,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential = $SplunkDefaultObject.Credential
        
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

    [Cmdletbinding(DefaultParameterSetName="byFilter")]
    Param(

        [Parameter(Position=0,ParameterSetName="byFilter")]
        [STRING]$Filter = '.*',
	
		[Parameter(Position=0,ParameterSetName="byName")]
		[STRING]$Name,

        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]$ComputerName = $SplunkDefaultObject.ComputerName,
        
        [Parameter()]
        [int]$Port            = $SplunkDefaultObject.Port,
        
        [Parameter()]
		[ValidateSet("http", "https")]
        [STRING]$Protocol     = $SplunkDefaultObject.Protocol,
        
        [Parameter()]
        [int]$Timeout         = $SplunkDefaultObject.Timeout,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential = $SplunkDefaultObject.Credential
        
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
        			    $obj | Where-Object $WhereFilter
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

    [Cmdletbinding(DefaultParameterSetName="byFilter")]
    Param(

        [Parameter(Position=0,ParameterSetName="byFilter")]
        [STRING]$Filter = '.*',
	
		[Parameter(Position=0,ParameterSetName="byName")]
		[STRING]$Name,

        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]$ComputerName = $SplunkDefaultObject.ComputerName,
        
        [Parameter()]
        [int]$Port            = $SplunkDefaultObject.Port,
        
        [Parameter()]
		[ValidateSet("http", "https")]
        [STRING]$Protocol     = $SplunkDefaultObject.Protocol,
        
        [Parameter()]
        [int]$Timeout         = $SplunkDefaultObject.Timeout,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential = $SplunkDefaultObject.Credential
        
    )
    Begin
	{
		Write-Verbose " [Get-SplunkLicenseGroup] :: Starting..."
        
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
    [Cmdletbinding(DefaultParameterSetName="byFilter")]
    Param(

        [Parameter(Position=0,ParameterSetName="byFilter")]
        [STRING]$Filter = '.*',
    
        [Parameter(Position=0,ParameterSetName="byName")]
        [STRING]$Name,

        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]$ComputerName = $SplunkDefaultObject.ComputerName,
        
        [Parameter()]
        [int]$Port            = $SplunkDefaultObject.Port,
        
        [Parameter()]
        [ValidateSet("http", "https")]
        [STRING]$Protocol     = $SplunkDefaultObject.Protocol,
        
        [Parameter()]
        [int]$Timeout         = $SplunkDefaultObject.Timeout,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential = $SplunkDefaultObject.Credential
        
    )
    Begin 
    {

        Write-Verbose " [Get-SplunkLicensePool] :: Starting..."
        
        $ParamSetName = $pscmdlet.ParameterSetName
        switch ($ParamSetName)
        {
            "byFilter"  { $WhereFilter = { $_.PoolName -match $Filter } } 
            "byName"    { $WhereFilter = { $_.PoolName -ceq   $Name } }
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

#region Set-SplunkLicenseGroup

function Set-SplunkLicenseGroup
{

    [Cmdletbinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
    Param(

		[Parameter(ValueFromPipelineByPropertyName=$true,Mandatory=$True)]
		[STRING]$GroupName,

        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]$ComputerName = $SplunkDefaultObject.ComputerName,
        
        [Parameter()]
        [int]$Port            = $SplunkDefaultObject.Port,
        
        [Parameter()]
		[ValidateSet("http", "https")]
        [STRING]$Protocol     = $SplunkDefaultObject.Protocol,
        
        [Parameter()]
        [int]$Timeout         = $SplunkDefaultObject.Timeout,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential = $SplunkDefaultObject.Credential,
        
        [Parameter()]
        [SWITCH]$Force
        
    )
    Begin
	{
		Write-Verbose " [Get-SplunkLicenseGroup] :: Starting..."
	}
	Process
	{
		Write-Verbose " [Set-SplunkLicenseGroup] :: Parameters"
		Write-Verbose " [Set-SplunkLicenseGroup] ::  - ComputerName = $ComputerName"
		Write-Verbose " [Set-SplunkLicenseGroup] ::  - Port         = $Port"
		Write-Verbose " [Set-SplunkLicenseGroup] ::  - Protocol     = $Protocol"
		Write-Verbose " [Set-SplunkLicenseGroup] ::  - Timeout      = $Timeout"
		Write-Verbose " [Set-SplunkLicenseGroup] ::  - Credential   = $Credential"

		Write-Verbose " [Set-SplunkLicenseGroup] :: Setting up Invoke-APIRequest parameters"
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
        
		Write-Verbose " [Set-SplunkLicenseGroup] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
		try
		{
            if($Force -or $PSCmdlet.ShouldProcess($ComputerName,"Setting Active Group to [$GroupName]"))
			{
			    [XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams -Arguments $GroupPostParam -RequestType POST
            }
        }
        catch
		{
			Write-Verbose " [Set-SplunkLicenseGroup] :: Invoke-SplunkAPIRequest threw an exception: $_"
            Write-Error $_
		}
        try
        {
			if($Results -and ($Results -is [System.Xml.XmlDocument]))
			{
                Write-Host " [Set-SplunkLicenseGroup] :: Please restart Splunkd"
                Get-SplunkLicenseGroup -Name $GroupName
			}
			else
			{
				Write-Verbose " [Set-SplunkLicenseGroup] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
			}
		}
		catch
		{
			Write-Verbose " [Set-SplunkLicenseGroup] :: Set-SplunkLicenseGroup threw an exception: $_"
            Write-Error $_
		}
	}
	End
	{
		Write-Verbose " [Set-SplunkLicenseGroup] :: =========    End   ========="
	}

}    # Set-SplunkLicenseGroup

#endregion Set-SplunkLicenseGroup

#endregion SPlunk License

################################################################################

#region Search

#region Search-Splunk

function Search-Splunk
{

	<#
        .Synopsis 
            Performs a simple search against targeted Splunk instance.
            
        .Description
            Performs a simple search against targeted Splunk instance. 
			
		.Parameter Search
			String you want to search for. 
            
        .Parameter ComputerName
            Name of the Splunk instance to search (Default is $SplunkDefaultObject.ComputerName.)
        
		.Parameter Port
            Port of the REST Instance (i.e. 8089) (Default is $SplunkDefaultObject.Port.)
        
		.Parameter Protocol
            Protocol to use to access the REST API must be 'http' or 'https' (Default is $SplunkDefaultObject.Protocol.)
        
		.Parameter Timeout
            How long to wait for the REST API to respond (Default is $SplunkDefaultObject.Timeout.)	
			
        .Parameter Credential
            Credential object with the user name and password used to access the REST API (Default is $SplunkDefaultObject.Credential.)	
			
		.Parameter StartTime
			The earliest (inclusive), respectively, time bounds for the search. The time string can be either a UTC time (with fractional seconds), a relative time specifier (to now) or a formatted time string. 
        
        .Parameter EndTime
        	The latest (exclusive), respectively, time bounds for the search. The time string can be either a UTC time (with fractional seconds), a relative time specifier (to now) or a formatted time string.
			
        .Parameter MaxReturnCount
			The maximum number of events to return.
        
        .Parameter MaxTime
			The number of seconds to run this search before finalizing.
		
		.Parameter RequiredFields	
			This is the list (csv) of required fields that, even if not referenced or used directly by the search, will still be included by the events and summary endpoints. 
			
		.Example
            Search-Splunk -Search 'source="WinEventLog:System"
            Description
            -----------
            Searches for events with source of "WinEventLog:System" on the targeted Splunk instance using the $SplunkDefaultObject settings.
    
        .Example
            Search-Splunk -Search 'source="WinEventLog:System" -ComputerName MySplunkInstance -Port 8089 -Protocol https -Timeout 5000 -Credential $MyCreds
            Description
            -----------
            Searches for events with source of "WinEventLog:System" on MySplunkInstance connecting on port 8089 with a 5sec timeout.
            
        .Example
            $SplunkServers | Search-Splunk -Search 'source="WinEventLog:System"
            Description
            -----------
            Searches for events with source of "WinEventLog:System" on each Splunk server in the pipeline using the $SplunkDefaultObject settings.
        
		.Example
            $SplunkServers | Search-Splunk -Search 'source="WinEventLog:System" -Port 8089 -Protocol https -Timeout 5000 -Credential $MyCreds
            Description
            -----------
            Searches for events with source of "WinEventLog:System" on each Splunk server in the pipeline connecting on port 8089 with a 5sec timeout and using credentials provided.
			
        .OUTPUTS
            PSObject
            
        .Notes
	        NAME:      Search-Splunk 
	        AUTHOR:    Splunk\bshell
	        Website:   www.splunk.com
	        #Requires -Version 2.0
    #>
	
	[Cmdletbinding()]
    Param(
	
		[Parameter(Mandatory=$True)]
		[STRING]$Search,
	
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]$ComputerName = $SplunkDefaultObject.ComputerName,
        
        [Parameter()]
        [int]$Port            = $SplunkDefaultObject.Port,
        
        [Parameter()]
		[ValidateSet("http", "https")]
        [STRING]$Protocol     = $SplunkDefaultObject.Protocol,
        
        [Parameter()]
        [int]$Timeout         = $SplunkDefaultObject.Timeout,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential = $SplunkDefaultObject.Credential,
		
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
			"StartTime"			{ $SearchParams.Add('earliest_time',$DefaultHostName) 		; continue }
			"EndTime"			{ $SearchParams.Add('latest_time',$MangementPort)     		; continue }
			"MaxReturnCount"	{ 
									$SearchParams.Add('auto_finalize_ec',$MaxReturnCount)
									$SearchParams.Add('max_count',$MaxReturnCount)
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

################################################################################

#region General functions

#region Write-SplunkMessage

function Write-SplunkMessage
{
    [Cmdletbinding()]
    Param(
        
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]$ComputerName = $SplunkDefaultObject.ComputerName,
        
        [Parameter()]
        [int]$Port            = $SplunkDefaultObject.Port,
        
        [Parameter()]
		[ValidateSet("http", "https")]
        [STRING]$Protocol     = $SplunkDefaultObject.Protocol,
        
        [Parameter()]
        [int]$Timeout         = $SplunkDefaultObject.Timeout,

        [Parameter()]           
        [String]$HostName     = $Env:COMPUTERNAME,
        
        [Parameter()]           
        [String]$Source       = "Powershell_Script",
        
        [Parameter()]           
        [String]$SourceType   = "Splunk_SDK_PowerShell",
        
        [Parameter()]           
        [String]$Index        = "main",
        
        [Parameter()]           
        [String]$Message,
        
        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential = $SplunkDefaultObject.Credential
        
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

################################################################################

#region Helper cmdlets

#region ConvertFrom-UnixTime

function ConvertFrom-UnixTime
{
	[Cmdletbinding()]
	Param($UnixTime)
	
	$Jan11970 = New-Object DateTime(1970, 1, 1, 0, 0, 0, 0)
	
	try
	{
		Write-Verbose " [ConvertFrom-UnixTime] :: Converting $UnixTime to DateTime"
		$Jan11970.AddSeconds($UnixTime)
	}
	catch
	{
		Write-Verbose " [ConvertFrom-UnixTime] :: Unable to convert $UnixTime to DateTime format"
		return $UnixTime
	}
}

#endregion ConvertFrom-UnixTime

#region ConvertFrom-SplunkTime

function ConvertFrom-SplunkTime($TimeAccessed)
{
    try
	{
		$DateTimeFormat = "ddd MMM dd HH:mm:ss yyyy"
		Write-Verbose " [ConvertFrom-SplunkTime] :: DateTimeFormat - $DateTimeFormat"
		$DateTime = [DateTime]::ParseExact($TimeAccessed,$DateTimeFormat,$Null)
		$DateTime
	}
	catch
	{
		Write-Verbose " [ConvertFrom-SplunkTime] :: Unable to convert timeAccessed to DateTime."
	}
	try
	{
		$DateTimeFormat = "ddd MMM  d HH:mm:ss yyyy"
		Write-Verbose " [ConvertFrom-SplunkTime] :: DateTimeFormat - $DateTimeFormat"
		$DateTime = [DateTime]::ParseExact($TimeAccessed,$DateTimeFormat,$Null)
		$DateTime
	}
	catch
	{
		Write-Verbose " [ConvertFrom-SplunkTime] :: Unable to convert timeAccessed to DateTime."
	}
}

#endregion ConvertFrom-SplunkTime

#region Disable-CertificateValidation

function Disable-CertificateValidation
{
	[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
}

#endregion Disable-CertificateValidation

#region Enable-CertificateValidation

function Enable-CertificateValidation
{
	[System.Net.ServicePointManager]::ServerCertificateValidationCallback = $Null
}

#endregion Enable-CertificateValidation

#region Export-SplunkModuleConfiguration

function Export-SplunkModuleConfiguration
{
	Param(
		[Parameter()]
		$Path = "$psScriptRoot\Splunk.Module.Config.xml"
	)
	Write-Verbose " [Export-SplunkModuleConfiguration] :: Exporting Configuration to $Path"
	$SplunkDefaultObject | Export-Clixml -Path $Path 
}

#endregion Export-SplunkModuleConfiguration

#region Import-SplunkModuleConfiguration

function Import-SplunkModuleConfiguration
{

	Param(
		[Parameter()]
		$Path = "$psScriptRoot\Splunk.Module.Config.xml"
	)
	
	Write-Verbose " [Import-SplunkModuleConfiguration] :: Importing Configuration from $Path"
	$OldObject = Import-Clixml -Path $Path
	
	Write-Verbose " [Import-SplunkModuleConfiguration] :: Creating Credential Object"
	$UserName = $OldObject.UserName
	$Password = ConvertTo-SecureString $OldObject.Password
	$MyCredential = New-Object System.Management.Automation.PSCredential($UserName,$Password)
	
	Write-Verbose " [Import-SplunkModuleConfiguration] :: Calling Connect-Splunk"
	Connect-Splunk -ComputerName $OldObject.ComputerName -Credentials $MyCredential
	
}

#endregion Import-SplunkModuleConfiguration

#endregion Helper cmdlets

#endregion functions

################################################################################
function Get-Splunk
{
    <#
	    .Synopsis
	        Get all the command contained in the Splunk Module
	        
	    .Description
	        Get all the command contained in the Splunk Module
	        
	    .Parameter Verb
	    
	    .Parameter Noun
	    
	    .Example
	        Get-Splunk
	        
	    .Example
	        Get-Splunk -verb Get
	        
	    .Example
	        Get-Splunk -noun Host
	        
	    .ReturnValue
	        function
	        
	    .Notes
	        NAME:      Get-Splunk
	        AUTHOR:    Splunk\bshell
	        Website:   www.Splunk.com
	        #Requires -Version 2.0
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Verb = "*",
        [Parameter()]
        [string]$noun = "*"
    )


    Process
    {
        Get-Command -Module Splunk -Verb $verb -noun $noun
    }#Process

} # Get-Splunk

# Adding System.Web namespace
Add-Type -AssemblyName System.Web 

New-Variable -Name SplunkModuleHome -Value $psScriptRoot -Scope Global -Force

# code to load scripts
Get-ChildItem $SplunkModuleHome *.ps1xml -Recurse | foreach-object{ Update-FormatData $_.fullname -ea 0 } 
