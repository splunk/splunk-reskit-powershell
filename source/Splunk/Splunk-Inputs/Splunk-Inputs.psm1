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

#region Index

#region Get-SplunkApplication
function Get-SplunkApplication
{
	[CmdletBinding(DefaultParameterSetName='byFilter')]
    Param(

		[Parameter()]
		#Indicates the maximum number of entries to return. To return all entries, specify 0. 
		[int]$Count = 30,
		
		[Parameter()]
		#Index for first item to return. 
		[int]$Offset = 0,
		
		[Parameter()]
		#Boolean predicate to filter results
		[string]$Search,
		
		[Parameter(Position=0,ParameterSetName='byFilter')]
		#Regular expression used to match index name
		[string]$Filter = '.*',
		
		[Parameter(Position=0,ParameterSetName='byName',Mandatory=$true)]
		#Boolean predicate to filter results
		[string]$Name,
		
		[Parameter()]
		[ValidateSet("asc","desc")]
		#Indicates whether to sort the entries returned in ascending or descending order. Valid values: (asc | desc).  Defaults to asc.
		[string]$SortDirection = "asc",
		
		[Parameter()]
		[ValidateSet("auto","alpha","alpha_case","num")]
		#Indicates the collating sequence for sorting the returned entries. Valid values: (auto | alpha | alpha_case | num).  Defaults to auto.
		[string]$SortMode = "auto",
		
		[Parameter()]
		# Field to sort by.
		[string]$SortKey,
		
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
			$Endpoint = '/services/apps/local'
	        Write-Verbose " [Get-SplunkApplication] :: Starting..."	        
			
			$ParamSetName = $pscmdlet.ParameterSetName
	        
	        switch ($ParamSetName)
	        {
	            "byFilter"  { 
					
					$WhereFilter = { $_.Name -match $Filter }
				}
	            "byName"    { 
					$Endpoint += "/$Name"
					$WhereFilter = { $_ }
				}
	        }	        
	}
	Process 
	{
	        Write-Verbose " [Get-SplunkApplication] :: Parameters"
	        Write-Verbose " [Get-SplunkApplication] ::  - ComputerName = $ComputerName"
	        Write-Verbose " [Get-SplunkApplication] ::  - Port         = $Port"
	        Write-Verbose " [Get-SplunkApplication] ::  - Protocol     = $Protocol"
	        Write-Verbose " [Get-SplunkApplication] ::  - Timeout      = $Timeout"
	        Write-Verbose " [Get-SplunkApplication] ::  - Credential   = $Credential"
	        Write-Verbose " [Get-SplunkApplication] ::  - Count		 = $Count"
	        Write-Verbose " [Get-SplunkApplication] ::  - Offset 		 = $Offset"
	        Write-Verbose " [Get-SplunkApplication] ::  - Filter		 = $Filter"
			Write-Verbose " [Get-SplunkApplication] ::  - Name		 = $Name"
			Write-Verbose " [Get-SplunkApplication] ::  - SortDir		 = $SortDir"
			Write-Verbose " [Get-SplunkApplication] ::  - SortMode	 = $SortMode"
			Write-Verbose " [Get-SplunkApplication] ::  - SortKey		 = $SortKey"
			Write-Verbose " [Get-SplunkApplication] ::  - WhereFilter	 = $WhereFilter"
			
			Write-Verbose " [Get-SplunkApplication] ::  - Endpoint		 = $Endpoint"
			
	        Write-Verbose " [Get-SplunkApplication] :: Setting up Invoke-APIRequest parameters"
	        $InvokeAPIParams = @{
	            ComputerName = $ComputerName
	            Port         = $Port
	            Protocol     = $Protocol
	            Timeout      = $Timeout
	            Credential   = $Credential
	            Endpoint     = $Endpoint
	            Verbose      = $VerbosePreference -eq "Continue"
	        }

			$restArgs = @{
				count		 = $Count
				offset		 = $Offset
				search		 = $Search
				sort_dir	 = $SortDirection
				sort_mode	 = $SortMode
				sort_key	 = $SortKey
			}
			
	        Write-Verbose " [Get-SplunkApplication] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
	        try
	        {
	            [XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams -Arguments $restArgs;
	        }
	        catch
	        {
	            Write-Verbose " [Get-SplunkApplication] :: Invoke-SplunkAPIRequest threw an exception: $_"
	            Write-Error $_
	        }
			
	        try
	        {
	            if($Results -and ($Results -is [System.Xml.XmlDocument] -and ($Results.feed.entry)))
	            {
	                Write-Verbose " [Get-SplunkApplication] :: Creating Hash Table to be used to create Splunk.SDK.Index"
	                
	                foreach($Entry in $Results.feed.entry)
	                {
	                    $MyObj = @{
	                        ComputerName                = $ComputerName
	                        Name                 		= $Entry.Title
	                        ServiceEndpoint             = $Entry.link | ?{$_.rel -eq "edit"} | select -ExpandProperty href
	                    }
	                    
						$ignoreParams = 'eai:attributes,eai:acl' -split '\s*,\s*';
						$booleanParams = 'check_for_updates,configured,disabled,manageable,state_change_requires_restart,visible' -split '\s*,\s*';
						$intParams = @();
						
	                    switch ($Entry.content.dict.key)
	                    {
							{ $ignoreParams -contains $_.name }         { continue }
	                        { $booleanParams -contains $_.name }        { $Myobj.Add( $_.Name, [bool]([int]$_.'#text') ); continue }													
	                        { $intParams -contains $_.name }            { $Myobj.Add( $_.Name, ([int]$_.'#text') ); continue }
	                        Default                                     { $Myobj.Add($_.Name,$_.'#text'); continue }
	                    }
	                    
	                    # Creating Splunk.SDK.ServiceStatus
	                    $obj = New-Object PSObject -Property $MyObj
	                    $obj.PSTypeNames.Clear()
	                    $obj.PSTypeNames.Add('Splunk.SDK.Data.LocalApplication')
	                    $obj | Where $WhereFilter;
	                }
	            }
	            else
	            {
	                Write-Verbose " [Get-SplunkApplication] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
	            }
	        }
	        catch
	        {
	            Write-Verbose " [Get-SplunkApplication] :: Get-SplunkApplication threw an exception: $_"
	            Write-Error $_
	        }
	    
	}
	End 
    {

	        Write-Verbose " [Get-SplunkApplication] :: =========    End   ========="
	    
	}
}
#endregion Get-SplunkApplication

#region New-SplunkApplication

function New-SplunkApplication
{
	[Cmdletbinding(SupportsShouldProcess=$true)]
    Param(
	
		[Parameter(Mandatory=$true)]
		[Alias("Application","ApplicationName")]
		[string] $name,
		
		[Parameter()]
		# For apps you intend to post to Splunkbase, enter the username of your splunk.com account.
		# For internal-use-only apps, include your full name and/or contact info (for example, email).
		[string]$author,

		[Parameter()]
		# Short explanatory string displayed underneath the app's title in Launcher.
		#
		#Typically, short descriptions of 200 characters are more effective.
		[string]$description,
		
		[Parameter()]
		[ValidateLength(5,80)]
		#Defines the name of the app shown in the Splunk GUI and Launcher.
		#
    	#Must be between 5 and 80 characters.
    	#Must not include "Splunk For" prefix. 
		#Examples of good labels:
		#	IMAP
    	#	SQL Server Integration Services
    	#	FISMA Compliance 
		[string]$label,
		
		[Parameter()]
		# Indicates that the Splunk Manager can manage the app.
		[switch]$manageable,

		[Parameter()]
		[ValidateSet( 'barebones', 'sample_app' )]
		# Indicates the app template to use when creating the app.
		# 
		# Specify either of the following:
		# 
		#     barebones - contains basic framework for an app
		#     sample_app - contains example views and searches 
		# 
		# You can also specify any valid app template you may have previously added.
		[string]$template,

		[Parameter()]
		# Indicates if the app is visible and navigable from the UI.
		#
		# Visible apps require at least 1 view that is available from the UI 
		[switch]$visible,

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
		Write-Verbose " [New-SplunkApplication] :: Starting..."
        $Endpoint = '/services/apps/local';
	}
	Process
	{          
		Write-Verbose " [New-SplunkApplication] :: Parameters"
        Write-Verbose " [New-SplunkApplication] ::  - ParameterSet = $ParamSetName"
		$Arguments = @{};
		$nc = 'ComputerName','Port','Protocol','Timeout','Credential';
		
		$PSBoundParameters.Keys | foreach{
			Write-Verbose " [New-SplunkApplication] ::  - $_ = $PSBoundParameters[$_]"		
			if( $nc -notcontains $_ )
			{
				$arguments.Add( $_, $PSBoundParameters[$_] );
			}
		}
		
		Write-Verbose " [New-SplunkApplication] ::  - Endpoint = $Endpoint"
		        
		if( -not $pscmdlet.ShouldProcess( $ComputerName, "Creating new Splunk application named $Name" ) )
		{
			return;
		}
        
        Write-Verbose " [New-SplunkApplication] :: checking for existance of application $Name"
        $InvokeAPIParams = @{
        			ComputerName = $ComputerName
        			Port         = $Port
        			Protocol     = $Protocol
        			Timeout      = $Timeout
        			Credential   = $Credential
                    name		 = $Name
                }
        $ExistingApplication = Get-SplunkApplication @InvokeAPIParams -erroraction 'silentlycontinue';
        
        if($ExistingApplication)
        {
            Write-Host " [New-SplunkApplication] :: Application [$Name] already exists: [ $($ExistingApplication.ServiceEndpoint) ]"
            Return
        }

		Write-Verbose " [New-SplunkApplication] :: Setting up Invoke-APIRequest parameters"
		$InvokeAPIParams = @{
			ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
			Endpoint 	 = $Endpoint
			Verbose      = $VerbosePreference -eq "Continue"
		}
        	
		Write-Verbose " [New-SplunkApplication] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
		try
		{
		    [XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams -Arguments $Arguments -RequestType POST 
        }
		catch
		{
			Write-Verbose " [New-SplunkApplication] :: Invoke-SplunkAPIRequest threw an exception: $_"
            Write-Error $_;

			return;
		}
        try
        {
			Write-Verbose " [New-SplunkApplication] :: Checking for valid results"
			if($Results -and ($Results -is [System.Xml.XmlDocument]))
			{
				Write-Verbose " [New-SplunkApplication] :: Fetching Application $name"
                $InvokeAPIParams = @{
        			ComputerName = $ComputerName
        			Port         = $Port
        			Protocol     = $Protocol
        			Timeout      = $Timeout
        			Credential   = $Credential
                    name		 = $Name
                }
                Get-SplunkApplication @InvokeAPIParams
			}
			else
			{
				Write-Verbose " [New-SplunkApplication] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
			}
		}
		catch
		{
			Write-Verbose " [New-SplunkApplication] :: New-SplunkApplication threw an exception: $_"
            Write-Error $_
		}
	}
	End
	{
		Write-Verbose " [New-SplunkApplication] :: =========    End   ========="
	}
} # New-SplunkApplication

#endregion

#region Remove-SplunkApplication

function Remove-SplunkApplication
{	
	[Cmdletbinding(SupportsShouldProcess=$true,ConfirmImpact='high')]
    Param(
	
		[Parameter(ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
		[string] $name,
		
        [Parameter()]
        [switch]$Force,

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
		Write-Verbose " [Remove-SplunkApplication] :: Starting..."
        $Endpoint = "/services/apps/local/$Name";
	}
	Process
	{          
		Write-Verbose " [Remove-SplunkApplication] :: Parameters"
        Write-Verbose " [Remove-SplunkApplication] ::  - ParameterSet = $ParamSetName"
		$Arguments = @{};
		$nc = 'ComputerName','Port','Protocol','Timeout','Credential';
		
		$PSBoundParameters.Keys | foreach{
			Write-Verbose " [Remove-SplunkApplication] ::  - $_ = $PSBoundParameters[$_]"		
			if( $nc -notcontains $_ )
			{
				$arguments.Add( $_, $PSBoundParameters[$_] );
			}
		}
		
		Write-Verbose " [Remove-SplunkApplication] ::  - Endpoint = $Endpoint"
		        
		if( -not( $Force -or $pscmdlet.ShouldProcess( $ComputerName, "Removing Splunk application named $Name" ) ) )
		{
			return;
		}
        
        Write-Verbose " [Remove-SplunkApplication] :: checking for existance of application $Name"
        $InvokeAPIParams = @{
        			ComputerName = $ComputerName
        			Port         = $Port
        			Protocol     = $Protocol
        			Timeout      = $Timeout
        			Credential   = $Credential
                    name		 = $Name
                }
        $ExistingApplication = Get-SplunkApplication @InvokeAPIParams -erroraction 'silentlycontinue';
        
        if( -not $ExistingApplication )
        {
            Write-Debug " [Remove-SplunkApplication] :: Application [$Name] does not exist on computer [$ComputerName]"
            Return
        }

		Write-Verbose " [Remove-SplunkApplication] :: Setting up Invoke-APIRequest parameters"
		$InvokeAPIParams = @{
			ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
			Endpoint 	 = $Endpoint
			Verbose      = $VerbosePreference -eq "Continue"
		}
        	
		Write-Verbose " [Remove-SplunkApplication] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
		try
		{
		    [XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams -Arguments $Arguments -RequestType DELETE 
        }
		catch
		{
			Write-Verbose " [Remove-SplunkApplication] :: Invoke-SplunkAPIRequest threw an exception: $_"
            Write-Error $_;

			return;
		}
	}
	End
	{
		Write-Verbose " [Remove-SplunkApplication] :: =========    End   ========="
	}
} # Remove-SplunkApplication

#endregion

#region Set-SplunkApplication

function Set-SplunkApplication
{
	[Cmdletbinding(SupportsShouldProcess=$true)]
    Param(
	
		[Parameter(ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
		[string] $name,
		
		[Parameter(ValueFromPipelineByPropertyName=$true)]		
		# For apps you intend to post to Splunkbase, enter the username of your splunk.com account.
		# For internal-use-only apps, include your full name and/or contact info (for example, email).
		[string]$author,

		[Parameter(ValueFromPipelineByPropertyName=$true)]
		# Short explanatory string displayed underneath the app's title in Launcher.
		#
		#Typically, short descriptions of 200 characters are more effective.
		[string]$description,
		
		[Parameter(ValueFromPipelineByPropertyName=$true)]
		[ValidateLength(5,80)]
		#Defines the name of the app shown in the Splunk GUI and Launcher.
		#
    	#Must be between 5 and 80 characters.
    	#Must not include "Splunk For" prefix. 
		#Examples of good labels:
		#	IMAP
    	#	SQL Server Integration Services
    	#	FISMA Compliance 
		[string]$label,
		
		[Parameter(ValueFromPipelineByPropertyName=$true)]
		# Indicates that the Splunk Manager can manage the app.
		[switch]$manageable,
		
		[Parameter(ValueFromPipelineByPropertyName=$true)]
		# If specified, Splunk checks Splunkbase for updates to this app. 
		[switch]$checkForUpdates,

		[Parameter(ValueFromPipelineByPropertyName=$true)]
		# Indicates if the app is visible and navigable from the UI.
		#
		# Visible apps require at least 1 view that is available from the UI 
		[switch]$visible,
		
		[Parameter(ValueFromPipelineByPropertyName=$true)]
		[ValidatePattern('^\d+(\.\d+)+( \S+)?$')]
		# Specifies the version for the app. Each release of an app must change the version number.
		# 
		# Version numbers are a number followed by a sequence of numbers or dots. Pre-release versions can append a space and a single-word suffix like "beta2". Examples:
		# 
		#     1.2
		#     11.0.34
		#     2.0 beta
		#     1.3 beta2
		#     1.0 b2
		#     12.4 alpha
		#     11.0.34.234.254 
		[String]$version,
       
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
		Write-Verbose " [Set-SplunkApplication] :: Starting..."
        $Endpoint = "/services/apps/local/$Name";
	}
	Process
	{          
		Write-Verbose " [Set-SplunkApplication] :: Parameters"
        Write-Verbose " [Set-SplunkApplication] ::  - ParameterSet = $ParamSetName"
		$PSBoundParameters.Keys | foreach{
			Write-Verbose " [Set-SplunkApplication] ::  - $_ = $($PSBoundParameters[$_])"		
		}
		$Arguments = @{};
		$nc = 'ComputerName','Port','Protocol','Timeout','Credential';
		$fields = data {
			'author'
			'check_for_updates'
			'description'
			'label'
			'manageable'
			'version'
			'visible'
		};
		
		$parameterNameMap = @{
			'checkForUpdates' = 'check_for_updates'
		}
		        
        Write-Verbose " [Set-SplunkApplication] :: checking for existance of index"
        $InvokeAPIParams = @{
        			ComputerName = $ComputerName
        			Port         = $Port
        			Protocol     = $Protocol
        			Timeout      = $Timeout
        			Credential   = $Credential
                    name		 = $Name
                }
        $ExistingApplication = Get-SplunkApplication @InvokeAPIParams -erroraction 'silentlycontinue';
        
        if(-not $ExistingApplication)
        {
            Write-Host " [Set-SplunkApplication] :: Application [$Name] does not exist and cannot be updated"
            Return
        }

		if( -not $pscmdlet.ShouldProcess( $ComputerName, "Updating Splunk index named $Name" ) )
		{
			return;
		}
		
		$intParams =  'checkForUpdates,manageable,visible' -split '\s*,\s*';
							
		$fields | foreach{			
			
			if( $nc -notcontains $_ )
			{
				#translate the powershell parameter name into its splunk REST api parameter name
				$pn = $_;
				if( $parameterNameMap.Keys -contains $_ )
				{
					$pn = $parameterNameMap[ $_ ];
				}
								
				if( $PSBoundParameters.ContainsKey($_) )
				{
					$value = $PSBoundParameters[$_];
				}
				else
				{
					$value = $ExistingApplication.$_;
				}
													
		        switch ($_)
		        {		
		            { $intParams -contains $_ }            { $Arguments[$pn] = [int]$value; continue }
		            Default                                { $Arguments[$pn] = $value; continue }
		        }
				
				Write-Verbose " [Set-SplunkApplication] ::  updating property $_ = $($ExistingApplication.$_) ; $($PSBoundParameters[$_]); $($Arguments[$pn])"		
			}
		}


		Write-Verbose "Updated application parameters: $arguments";
		
		Write-Verbose " [Set-SplunkApplication] :: Setting up Invoke-APIRequest parameters"
		$InvokeAPIParams = @{
			ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
			Endpoint 	 = $Endpoint
			Verbose      = $VerbosePreference -eq "Continue"
		}
        	
		Write-Verbose " [Set-SplunkApplication] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
		try
		{
		    [XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams -Arguments $Arguments -RequestType POST 
        }
		catch
		{
			Write-Verbose " [Set-SplunkApplication] :: Invoke-SplunkAPIRequest threw an exception: $_"
            Write-Error $_;

			return;
		}
        try
        {
			Write-Verbose " [Set-SplunkApplication] :: Checking for valid results"
			if($Results -and ($Results -is [System.Xml.XmlDocument]))
			{
				Write-Verbose " [Set-SplunkApplication] :: Fetching index $name"
                $InvokeAPIParams = @{
        			ComputerName = $ComputerName
        			Port         = $Port
        			Protocol     = $Protocol
        			Timeout      = $Timeout
        			Credential   = $Credential
                    name		 = $Name
                }
                Get-SplunkApplication @InvokeAPIParams
			}
			else
			{
				Write-Verbose " [Set-SplunkApplication] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
			}
		}
		catch
		{
			Write-Verbose " [Set-SplunkApplication] :: Set-SplunkApplication threw an exception: $_"
            Write-Error $_
		}
	}
	End
	{
		Write-Verbose " [Set-SplunkApplication] :: =========    End   ========="
	}
} # Set-SplunkApplication

#endregion

#endregion Application
