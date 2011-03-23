#region functions

#region Base_Cmdlets

#region Invoke-SplunkAPIRequest

function Invoke-SplunkAPIRequest
{

    [Cmdletbinding(DefaultParameterSetName="byAuthToken")]
    Param(
    
        [Parameter(Mandatory=$True)]
        [STRING]$URL,
        
        [Parameter()]
        [ValidateSet("XML", "CSV", "JSON", "RAW")]
        [STRING]$Format = 'XML',
        
        [Parameter()]
        [ValidateSet("GET", "POST", "PUT", "DELETE")]
        [STRING]$RequestType = 'GET',
        
        [Parameter()]
        [System.Collections.Hashtable]$Arguments,
        
        [Parameter()]
        [String]$ComputerName,
        
        [Parameter()]
        [int]$Port,
        
        [Parameter()]
        [STRING]$Protocol,
        
        [Parameter()]
        [int]$Timeout,

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
			$Error[0]
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
			$Error[0]
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
			$Error[0]
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
	        Write-Host (" [Invoke-HTTPPost] :: Unable to connect: {0}" -f $Error[0].Exception.message)
	        return
	    }

	    Write-Verbose " [Invoke-HTTPPost] :: Sending POST message"
	    $RequestStream.Write($PostString)
	    
	    Write-Verbose " [Invoke-HTTPPost] :: Closing POST stream"
		$RequestStream.Flush()
	    $RequestStream.Close()
		
		Write-Verbose " [Invoke-HTTPPost] :: Getting Response from POST"
	    $Response = $Request.GetResponse()
	    $Reader = new-object System.IO.StreamReader($Response.GetResponseStream())
	    
	    [XML]$Results = $Reader.ReadToEnd()
	    Write-Verbose " [Invoke-HTTPPost] :: Returning Results"
		$Results
	}
    
    #endregion Internal Functions
    
    Write-Verbose " [Invoke-SplunkAPIRequest] :: Using [$($pscmdlet.ParameterSetName)] ParameterSet"
    Write-Verbose " [Invoke-SplunkAPIRequest] :: Parameters"
    Write-Verbose " [Invoke-SplunkAPIRequest] ::  - URL          = $URL"
    Write-Verbose " [Invoke-SplunkAPIRequest] ::  - Format       = $Format"
    Write-Verbose " [Invoke-SplunkAPIRequest] ::  - RequestType  = $RequestType"
    Write-Verbose " [Invoke-SplunkAPIRequest] ::  - ComputerName = $ComputerName"
    Write-Verbose " [Invoke-SplunkAPIRequest] ::  - Port         = $Port"
    Write-Verbose " [Invoke-SplunkAPIRequest] ::  - Protocol     = $Protocol"
    Write-Verbose " [Invoke-SplunkAPIRequest] ::  - Timeout      = $Timeout"
    
    $FullURL = "{0}://{1}:{2}/{3}" -f $Protocol,$ComputerName,$Port,($URL -replace '^/(.*)','$1').ToLower()
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
                                    "GET"       {Invoke-HTTPGet    @InvokeHTTPParams -UName $UserName -Token $AuthToken}
                                    "PUT"       {Invoke-HTTPPut    @InvokeHTTPParams -UName $UserName -Token $AuthToken}
                                    "POST"      {Invoke-HTTPPost   @InvokeHTTPParams -UName $UserName -Token $AuthToken -Arguments $Arguments}
                                    "DELETE"    {Invoke-HTTPDelete @InvokeHTTPParams -UName $UserName -Token $AuthToken}
                                }
                            }
        "byCredential"      {
                                Write-Verbose " [Invoke-SplunkAPIRequest] ::  - Credential   = $Credential"
                                switch -exact ($RequestType)
                                {
                                    "GET"       {Invoke-HTTPGet    @InvokeHTTPParams -Creds $Credential}
                                    "PUT"       {Invoke-HTTPPut    @InvokeHTTPParams -Creds $Credential}
                                    "POST"      {Invoke-HTTPPost   @InvokeHTTPParams -Creds $Credential -Arguments $Arguments}
                                    "DELETE"    {Invoke-HTTPDelete @InvokeHTTPParams -Creds $Credential}
                                }
                            }
							
		"byNoAuth"      	{
                                Write-Verbose " [Invoke-SplunkAPIRequest] ::  - NoAuth"
                                switch -exact ($RequestType)
                                {
                                    "GET"       {Invoke-HTTPGet    @InvokeHTTPParams -NoAuth}
                                    "PUT"       {Invoke-HTTPPut    @InvokeHTTPParams -NoAuth}
                                    "POST"      {Invoke-HTTPPost   @InvokeHTTPParams -NoAuth -Arguments $Arguments}
                                    "DELETE"    {Invoke-HTTPDelete @InvokeHTTPParams -NoAuth}
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
        [INT]$Timeout = 5000, 
        
        [Parameter(ParameterSetName="byCredentials")]
        [System.Management.Automation.PSCredential]$Credentials,
        
        [Parameter(ParameterSetName="byUserName")]
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
        
        [Parameter()]
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
	Write-Verbose " [Get-SplunkLogin] :: Starting"
	
	Write-Verbose " [Get-SplunkLogin] :: Parameters"
	Write-Verbose " [Get-SplunkLogin] ::  - Name         = $Name"
	Write-Verbose " [Get-SplunkLogin] ::  - ComputerName = $ComputerName"
	Write-Verbose " [Get-SplunkLogin] ::  - Port         = $Port"
	Write-Verbose " [Get-SplunkLogin] ::  - Protocol     = $Protocol"
	Write-Verbose " [Get-SplunkLogin] ::  - Timeout      = $Timeout"
	Write-Verbose " [Get-SplunkLogin] ::  - Credential   = $Credential"
	
	# Setting DateTime format to convert the TimeAccessed to System.DateTime
	$DateTimeFormat = "ddd MMM dd HH:mm:ss yyyy"
	
	Write-Verbose " [Get-SplunkLogin] ::  Setting up Invoke-APIRequest parameters"
	$InvokeAPIParams = @{
		ComputerName = $ComputerName
		Port         = $Port
		Protocol     = $Protocol
		Timeout      = $Timeout
		Credential   = $Credential
		URL          = '/services/authentication/httpauth-tokens'
		Verbose      = $VerbosePreference -eq "Continue"
	}
	
	Write-Verbose " [Get-SplunkLogin] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
	[XML]$UserToken = Invoke-SplunkAPIRequest @InvokeAPIParams 
	
	if($UserToken)
	{
		foreach($entry in $UserToken.feed.entry)
		{
			$Myobj = @{}
			foreach($Key in $entry.content.dict.key)
			{
				switch -exact ($Key.name)
				{
					"username"  	{$Myobj.Add('UserName',$Key.'#text')}
					"authString"	{$Myobj.Add('AuthToken',$Key.'#text')}
					"timeAccessed"	{$Myobj.Add('TimeAccessed',[DateTime]::ParseExact($Key.'#text',$DateTimeFormat,$Null))}
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

	Write-Verbose " [Get-SplunkLogin] :: =========    End   ========="
	
}	# Get-SplunkLogin

#endregion Get-SplunkAuthToken

#region Get-SplunkAuthToken

function Get-SplunkAuthToken
{
	[Cmdletbinding(DefaultParameterSetName="byCredentials")]
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
		URL          = '/services/auth/login'
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

#endregion Authentication

################################################################################

#region SplunkD

#region Get-Splunkd

function Get-Splunkd
{
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
        [System.Management.Automation.PSCredential]$Credential = $SplunkDefaultObject.Credential
        
    )
	
	Write-Verbose " [Get-Splunkd] :: Starting..."
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
		URL          = '/services/server/settings' 
		Verbose      = $VerbosePreference -eq "Continue"
	}
		
	Write-Verbose " [Get-Splunkd] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
	[XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams
	if($Results)
	{
		$MyObj = @{}
		Write-Verbose " [Get-Splunkd] :: Creating Hash Table to be used to create Splunk.SDK.ServiceStatus"
		switch ($results.feed.entry.content.dict.key)
		{
        	{$_.name -eq "SPLUNK_DB"}		    {$Myobj.Add("Splunk_DB",$_.'#text');continue}
        	{$_.name -eq "SPLUNK_HOME"}		    {$Myobj.Add("Splunk_Home",$_.'#text');continue}
			{$_.name -eq "enableSplunkWebSSL"}	{$Myobj.Add("EnableWebSSL",[bool]($_.'#text'));continue}
	        {$_.name -eq "host"}				{$Myobj.Add("ComputerName",$_.'#text');continue}
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
		Write-Verbose " [Get-Splunkd] :: Creating Hash Table to be used to create Splunk.SDK.ServiceStatus"
	}

	Write-Verbose " [Get-Splunkd] :: =========    End   ========="
} # Get-Splunkd

#endregion Get-Splunkd

#region Test-Splunkd

function Test-Splunkd
{
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
	
	Write-Verbose " [Test-Splunkd] :: Starting..."
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
		$True
	}
	else
	{
		$False
	}

	Write-Verbose " [Test-Splunkd] :: =========    End   ========="
} # Test-Splunkd

#endregion Test-Splunkd

#region Set-Splunkd

function Set-Splunkd
{
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
        [System.Management.Automation.PSCredential]$Credential = $SplunkDefaultObject.Credential
        
    )
	
	Write-Error "Not Implemented Yet" -ErrorAction Stop
	
	Write-Verbose " [Set-Splunkd] :: Starting..."
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
		URL          = '/services/server/settings' 
		Verbose      = $VerbosePreference -eq "Continue"
	}
		
	Write-Verbose " [Set-Splunkd] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
	[XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams
	if($Results)
	{

	}
	else
	{
		Write-Verbose " [Set-Splunkd] :: Creating Hash Table to be used to create Splunk.SDK.ServiceStatus"
	}

	Write-Verbose " [Set-Splunkd] :: =========    End   ========="
} # Set-Splunkd

#endregion Set-Splunkd

#region Restart-Splunkd

function Restart-Splunkd
{
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
		[SWITCH]$Native
        
    )
	
	Write-Verbose " [Restart-Splunkd] :: Starting..."
	Write-Verbose " [Restart-Splunkd] :: Parameters"
	Write-Verbose " [Restart-Splunkd] ::  - ComputerName = $ComputerName"
	Write-Verbose " [Restart-Splunkd] ::  - Port         = $Port"
	Write-Verbose " [Restart-Splunkd] ::  - Protocol     = $Protocol"
	Write-Verbose " [Restart-Splunkd] ::  - Timeout      = $Timeout"
	Write-Verbose " [Restart-Splunkd] ::  - Credential   = $Credential"

	Write-Verbose " [Restart-Splunkd] :: Setting up Invoke-APIRequest parameters"
	$InvokeAPIParams = @{
		ComputerName = $ComputerName
		Port         = $Port
		Protocol     = $Protocol
		Timeout      = $Timeout
		Credential   = $Credential
		URL          = '/services/server/control/restart' 
		Verbose      = $VerbosePreference -eq "Continue"
	}

	if($Force -or $PSCmdlet.ShouldProcess($ComputerName,"Restarting Splunkd Service"))
    {
		if($Native)
		{
			Write-Error "Not Implemented Yet" -ErrorAction Stop
		}
		else
		{
	        Write-Verbose " [Restart-Splunkd] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
			$Results = Invoke-SplunkAPIRequest @InvokeAPIParams
			Write-Host "Please wait..."
			if($Results)
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
	
	Write-Verbose " [Restart-Splunkd] :: =========    End   ========="
	
} # Get-Splunkd

#endregion Restart-Splunkd

#endregion SplunkD

#endregion functions


################################################################################
function Get-Splunk
{
    <#
	    .Synopsis
	        Get all the command contained in the BSonPosh Module
	        
	    .Description
	        Get all the command contained in the BSonPosh Module
	        
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
