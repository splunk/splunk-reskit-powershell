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

#region Base_Cmdlets

#region Invoke-SplunkAPIRequest

function Invoke-SplunkAPIRequest
{

	<# .ExternalHelp ../Splunk-Help.xml #>
	
    [Cmdletbinding(DefaultParameterSetName="byAuthToken")]
    Param(
    
	    [Parameter()]
        [String]$ComputerName = ( get-splunkconnectionobject ).ComputerName,
        
        [Parameter()]
        [int]$Port = ( get-splunkconnectionobject ).Port,
        
        [Parameter()]
		[ValidateSet("http", "https")]
        [STRING]$Protocol = ( get-splunkconnectionobject ).Protocol,
        
        [Parameter()]
        [int]$Timeout = ( get-splunkconnectionobject ).Timeout,
		
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
            [System.Management.Automation.PSCredential]$Creds,
            
			[Parameter(ParameterSetName='byNoAuth')]
			[Switch]$NoAuth,
			
			[Parameter()]
			[Hashtable] $Arguments
        )
        
        Write-Verbose " [Invoke-HTTPGet] :: Using [$($pscmdlet.ParameterSetName)] ParameterSet"
        switch -exact ($pscmdlet.ParameterSetName)
        {
            "byToken"       {
								if( -not $Arguments )
								{
									$Arguments = new @{};
								}
								$Arguments['username'] = $UName;
								$Arguments['authToken'] = $Token;
                            }
		}

		if( $Arguments )
		{
			$Arguments.Keys | foreach {
				if( ( $null -eq $Arguments[$_] ) -or ( '' -eq $Arguments[$_] ) )
				{
					return;
				}
				if( $URL -match '\?' )
				{
					$URL += '&';
				}
				else
				{
					$Url += '?';
				}
				
				$Url += ( "{0}={1}" -f $_,$Arguments[$_] );
			}
		}
		
		Write-Verbose " [Invoke-HTTPGet] :: Connecting to URL: $URL"
        $Request = [System.Net.WebRequest]::Create($URL)
        $Request.Credentials = $Creds
        $Request.Method ="GET"
        $Request.Timeout = $Timeout
        $Request.ContentLength = 0

		switch -exact ($pscmdlet.ParameterSetName)
        {
            "byCreds"       {
                                $Request.Credentials = $Creds
                            }

			"byNoAuth"      {
								$Request.AuthenticationLevel = [System.Net.Security.AuthenticationLevel]::None
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
		
		Write-Verbose " [Invoke-HTTPPost] :: Creating POST message"
        [string]$PostString = "search={0}" -f [System.Web.HttpUtility]::UrlEncode([string]$Arguments['search'])
        $Arguments.Remove('search')
		foreach($Argument in $Arguments.Keys)
		{
			[string]$PostString += "&{0}={1}" -f $Argument,[System.Web.HttpUtility]::UrlEncode([string]$Arguments[$Argument])
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
			
			try
			{
				if( 'silentlycontinue' -ne $VerbosePreference )
				{				
					$Response = $_.exception.innerexception.response
					$Reader = new-object System.IO.StreamReader($Response.GetResponseStream())
					$Results = $Reader.ReadToEnd()
					$Results | Write-Verbose;
				}
			}
			catch
			{
			}
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
    
    function Invoke-HTTPDelete
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
            [System.Management.Automation.PSCredential]$Creds,
            
			[Parameter(ParameterSetName='byNoAuth')]
			[Switch]$NoAuth
        )
        
        Write-Verbose " [Invoke-HTTPDelete] :: Using [$($pscmdlet.ParameterSetName)] ParameterSet"
        switch -exact ($pscmdlet.ParameterSetName)
        {
            "byToken"       {
                                $MyURL = "{0}?username={1}&authToken={2}" -f $URL,$UName,$Token
                                Write-Verbose " [Invoke-HTTPDelete] :: Connecting to URL: $MyURL"
                                $Request = [System.Net.WebRequest]::Create($MyURL)
                                $Request.Method ="DELETE"
                                $Request.Timeout = $Timeout
                                $Request.ContentLength = 0
                            }
            "byCreds"       {
                                Write-Verbose " [Invoke-HTTPDelete] :: Connecting to URL: $URL"
                                $Request = [System.Net.WebRequest]::Create($URL)
                                $Request.Credentials = $Creds
                                $Request.Method ="DELETE"
                                $Request.Timeout = $Timeout
                                $Request.ContentLength = 0
                            }

			"byNoAuth"      {
	                            Write-Verbose " [Invoke-HTTPDelete] :: Connecting to URL: $URL"
	                            $Request = [System.Net.WebRequest]::Create($URL)
	                            $Request.Method = "DELETE"
                                $Request.Timeout = $Timeout
                                $Request.ContentLength = 0
								$Request.AuthenticationLevel = [System.Net.Security.AuthenticationLevel]::None
	                        }

		}

		#JDAC: refactor for testing to mock network txn
        try
        {
            Write-Verbose " [Invoke-HTTPDelete] :: Sending Request"
            $Response = $Request.GetResponse()
        }
        catch
        {
            Write-Verbose " [Invoke-HTTPDelete] :: Error sending request"
			Write-Error $_ -ErrorAction Stop
            return
        }
        
        try
        {
            Write-Verbose " [Invoke-HTTPDelete] :: Creating StreamReader from Response"
            $Reader = New-Object System.IO.StreamReader($Response.GetResponseStream())
        }
        catch
        {
            Write-Verbose " [Invoke-HTTPDelete] :: Error getting Response Stream"
			Write-Error $_ -ErrorAction Stop
            return
        }
        
        try
        {
            Write-Verbose " [Invoke-HTTPDelete] :: Getting Results"
            $Result = $Reader.ReadToEnd()
        }
        catch
        {
            Write-Verbose " [Invoke-HTTPDelete] :: Error Reading Response Stream"
			Write-Error $_ -ErrorAction Stop
            return
        }
   
	    Write-Verbose " [Invoke-HTTPDelete] :: Returning Results"
    	$Result
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
                                    "GET"           { $xml = Invoke-HTTPGet        @InvokeHTTPParams -UName $UserName -Token $AuthToken -Arguments $Arguments }
                                    "PUT"           { $xml = Invoke-HTTPPut        @InvokeHTTPParams -UName $UserName -Token $AuthToken }
                                    "POST"          { $xml = Invoke-HTTPPost       @InvokeHTTPParams -UName $UserName -Token $AuthToken -Arguments $Arguments }
                                    "SIMPLEPOST"    { $xml = Invoke-HTTPSimplePost @InvokeHTTPParams -UName $UserName -Token $AuthToken -URLParam $URLParam -PostMessage $PostMessage}
                                    "DELETE"        { $xml = Invoke-HTTPDelete     @InvokeHTTPParams -UName $UserName -Token $AuthToken }
                                }
                            }
        "byCredential"      {
                                Write-Verbose " [Invoke-SplunkAPIRequest] ::  - Credential   = $Credential"
                                switch -exact ($RequestType)
                                {
                                    "GET"           { $xml = Invoke-HTTPGet        @InvokeHTTPParams -Creds $Credential -Arguments $Arguments }
                                    "PUT"           { $xml = Invoke-HTTPPut        @InvokeHTTPParams -Creds $Credential }
                                    "POST"          { $xml = Invoke-HTTPPost       @InvokeHTTPParams -Creds $Credential -Arguments $Arguments }
                                    "SIMPLEPOST"    { $xml = Invoke-HTTPSimplePost @InvokeHTTPParams -Creds $Credential -URLParam $URLParam -PostMessage $PostMessage }
                                    "DELETE"        { $xml = Invoke-HTTPDelete     @InvokeHTTPParams -Creds $Credential }
                                }
                            }
							
		"byNoAuth"      	{
                                Write-Verbose " [Invoke-SplunkAPIRequest] ::  - NoAuth"
                                switch -exact ($RequestType)
                                {
                                    "GET"           { $xml = Invoke-HTTPGet        @InvokeHTTPParams -NoAuth -Arguments $Arguments }
                                    "PUT"           { $xml = Invoke-HTTPPut        @InvokeHTTPParams -NoAuth }
                                    "POST"          { $xml = Invoke-HTTPPost       @InvokeHTTPParams -NoAuth -Arguments $Arguments }
                                    "SIMPLEPOST"    { $xml = Invoke-HTTPSimplePost @InvokeHTTPParams -NoAuth -URLParam $URLParam -PostMessage $PostMessage}
                                    "DELETE"        { $xml = Invoke-HTTPDelete     @InvokeHTTPParams -NoAuth }
                                }
                            }
    }
    
	#workaround bug in Splunk API where empty results are returned as invalid XML
	if( $xml -match '<[^?]' )
	{
		Write-Verbose $xml;
		[XML]$xml;
	}
	else
	{
		Write-Verbose "The Splunk API has returned a partial XML document that appears to be an empty set" 
	}
	
	Write-Verbose " [Invoke-SplunkAPIRequest] :: =========    End   ========="
	
} # Invoke-SplunkAPIRequest

#endregion Invoke-SplunkAPIRequest

#endregion Base_Cmdlets

################################################################################

