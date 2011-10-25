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

#region Outputs

#region Get-OutputProxy
function Get-OutputProxy
{
	[CmdletBinding(DefaultParameterSetName='byFilter')]
    Param(

		[Parameter(Mandatory=$true)]
		[Hashtable]$outputFields,
		
		[Parameter(Mandatory=$true)]
		[string] $outputType,
		
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
			$CurrentFunctionName = $MyInvocation.MyCommand;
			$Endpoint = "/services/data/outputs/tcp/$($outputType.tolower())"
	        Write-Verbose " [$CurrentFunctionName] :: Starting..."	        
			
			$ParamSetName = $pscmdlet.ParameterSetName
	        #list of non-REST argument names
			$nc = @(
				'ComputerName','Port','Protocol','Timeout','Credential', 
				'OutputFields','OutputType','Name','Filter',
				'ErrorAction', 'ErrorVariable'	
			);
			
	        switch ($ParamSetName)
	        {
	            "byFilter"  { 
					
					$WhereFilter = { $_.Name -match $Filter }
				}
	            "byName"    { 
					$Endpoint = (  "/services/data/outputs/tcp/{0}/{1}" -f $outputType.ToLower(),$Name );					
					$WhereFilter = { [bool]$_ }
				}
	        }	        
	}
	Process 
	{
	        Write-Verbose " [$CurrentFunctionName] :: Parameters"
			Write-Verbose " [$CurrentFunctionName] ::  - ParameterSet = $ParamSetName"
			$PSBoundParameters.Keys | foreach{
				Write-Verbose " [$CurrentFunctionName] ::  - $_ = $($PSBoundParameters[$_])"		
			}
			Write-Verbose " [$CurrentFunctionName] ::  - Endpoint		 = $Endpoint"
			
			#the table of REST API arguments
			$Arguments = @{};
			#map of powershell parameter names to REST API parameter names
			$parameterNameMap = @{
				'SortDirection' = 'sort_dir';
				'SortKey' = 'sort_key';
				'SortMode' = 'sort_mode'
			}			
			
			# generate REST API arguments from powershell arguments							
			$PSBoundParameters.Keys | where { $nc -notcontains $_ } | foreach{			
									
				#translate the powershell parameter name into its splunk REST api parameter name
				$pn = $_;
				if( $parameterNameMap.Keys -contains $_ )
				{
					$pn = $parameterNameMap[ $_ ];
				}
								
				$value = $PSBoundParameters[$_];
													
		        $Arguments[$pn.tolower()] = $value;
				
				Write-Verbose " [$CurrentFunctionName] ::  REST API parameter $pn ($_) = $value"		
			}
		
			
	        Write-Verbose " [$CurrentFunctionName] :: Setting up Invoke-APIRequest parameters"
	        $InvokeAPIParams = @{
	            ComputerName = $ComputerName
	            Port         = $Port
	            Protocol     = $Protocol
	            Timeout      = $Timeout
	            Credential   = $Credential
	            Endpoint     = $Endpoint
	            Verbose      = $VerbosePreference -eq "Continue"
	        }

			
	        Write-Verbose " [$CurrentFunctionName] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
	        try
	        {
	            [XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams -Arguments $Arguments;
	        }
	        catch
	        {
	            Write-Verbose " [$CurrentFunctionName] :: Invoke-SplunkAPIRequest threw an exception: $_"
	            Write-Error $_
	        }
			
	        try
	        {
	            if($Results -and ($Results -is [System.Xml.XmlDocument] -and ($Results.feed.entry)))
	            {
					$sdkTypeName = "Splunk.SDK.Output.$outputType"
	                Write-Verbose " [$CurrentFunctionName] :: Creating Hash Table to be used to create $sdkTypeName"

					$ignoreParams = ('eai:attributes,eai:acl' -split '\s*,\s*') + @($outputFields.ignore);
					$booleanParams = @($outputFields.boolean);
					$intParams = @($outputFields.integer);
					
	                foreach($Entry in $Results.feed.entry)
	                {
	                    $MyObj = @{
	                        ComputerName                = $ComputerName
	                        Name                 		= $Entry.Title
	                        ServiceEndpoint             = $Entry.link | ?{$_.rel -eq "edit"} | select -ExpandProperty href
	                    }
	                    												
	                    switch ($Entry.content.dict.key)
	                    {
							{ $ignoreParams -contains $_.name }         { Write-Debug "ignoring key $($_.name)"; continue; }
	                        { $booleanParams -contains $_.name }        { Write-Debug "taking boolean action on key $($_.name)"; $Myobj.Add( $_.Name, [bool]([int]$_.'#text') ); continue;}													
	                        { $intParams -contains $_.name }            { Write-Debug "taking integer action on key $($_.name)"; $Myobj.Add( $_.Name, ([int]$_.'#text') ); continue; }
	                        Default                                     { 
																			Write-Debug "taking default action on key $($_.name)";
																			
																			#translate list XML to array
																			if( $_.list -and $_.list.item )
																			{
																				Write-Debug "taking array action on key $($_.name)";
																				[string[]]$i = $_.list.item | %{ 
																					write-debug "item: $_"
																					$_;
																				}
																				$Myobj.Add($_.Name,$i); 
																			}
																			# assume single string value
																			else
																			{
																				Write-Debug "taking default string action on key $($_.name)";
																				$Myobj.Add($_.Name,$_.'#text'); 
																			}
																			continue; 
																		}
	                    }
	                    	                    
	                    $obj = New-Object PSObject -Property $MyObj
	                    $obj.PSTypeNames.Clear()
	                    $obj.PSTypeNames.Add($sdkTypeName)
	                    $obj | Where $WhereFilter;
	                }
	            }
	            else
	            {
	                Write-Verbose " [$CurrentFunctionName] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
	            }
	        }
	        catch
	        {
	            Write-Verbose " [$CurrentFunctionName] :: Get-OutputProxy threw an exception: $_"
	            Write-Error $_
	        }
	    
	}
	End 
    {
	        Write-Verbose " [$CurrentFunctionName] :: =========    End   ========="	    
	}
}
#endregion Get-OutputProxy

#region Remove-SplunkOutput

function Remove-OutputProxy
{	
	[Cmdletbinding(SupportsShouldProcess=$true,ConfirmImpact='high')]
    Param(
	
		[Parameter(Mandatory=$true)]
		[Hashtable]$outputFields,

		[Parameter(Mandatory=$true)]
		[string] $outputType,

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
			$CurrentFunctionName = $MyInvocation.MyCommand;

	        Write-Verbose " [$CurrentFunctionName] :: Starting..."	        		

        	$Endpoint = "/services/data/outputs/tcp/{0}/{1}" -f $outputType.ToLower(),$Name;					
	}
	Process
	{          
		Write-Verbose " [$CurrentFunctionName] :: Parameters"
        Write-Verbose " [$CurrentFunctionName] ::  - ParameterSet = $ParamSetName"

		$Arguments = @{};
		
		$PSBoundParameters.Keys | foreach{
			Write-Verbose " [$CurrentFunctionName] ::  - $_ = $($PSBoundParameters[$_])"		
			if( $nc -notcontains $_ )
			{
				$arguments.Add( $_, $PSBoundParameters[$_] );
			}
		}
		
		Write-Verbose " [$CurrentFunctionName] ::  - Endpoint = $Endpoint"
		        
		if( -not( $Force -or $pscmdlet.ShouldProcess( $ComputerName, "Removing Splunk $outputType output named $Name" ) ) )
		{
			return;
		}
        
        Write-Verbose " [$CurrentFunctionName] :: checking for existance of [$outputType] output [$Name]"
        $InvokeAPIParams = @{
        			ComputerName = $ComputerName
        			Port         = $Port
        			Protocol     = $Protocol
        			Timeout      = $Timeout
        			Credential   = $Credential
                    name		 = $Name
					outputType	 = $outputType
					outputFields = $outputFields
                }
        $ExistingApplication = Get-OutputProxy @InvokeAPIParams -erroraction 'silentlycontinue';
        
        if( -not $ExistingApplication )
        {
            Write-Debug " [$CurrentFunctionName] :: Output [$Name] of type [$outputType] does not exist on computer [$ComputerName]"
            Return
        }

		Write-Verbose " [$CurrentFunctionName] :: Setting up Invoke-APIRequest parameters"
		$InvokeAPIParams = @{
			ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
			Endpoint 	 = $Endpoint
			Verbose      = $VerbosePreference -eq "Continue"
		}
        	
		Write-Verbose " [$CurrentFunctionName] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
		try
		{
		    [XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams -Arguments $Arguments -RequestType DELETE 
        }
		catch
		{
			Write-Verbose " [$CurrentFunctionName] :: Invoke-SplunkAPIRequest threw an exception: $_"
            Write-Error $_;

			return;
		}
	}
	End
	{
		Write-Verbose " [$CurrentFunctionName] :: =========    End   ========="
	}
} # Remove-InputProxy

#endregion

#region Set-OutputProxy
function Set-OutputProxy
{
	[Cmdletbinding(SupportsShouldProcess=$true)]
    Param(
	
		[Parameter(Mandatory=$true)]
		[Hashtable]$outputFields,

		[Parameter(Mandatory=$true)]
		[Hashtable[]] $setParameters,
		
		[Parameter(Mandatory=$true)]
		[string] $outputType,

		[Parameter(ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
		[string] $name,
		
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
		$CurrentFunctionName = $MyInvocation.MyCommand;

        Write-Verbose " [$CurrentFunctionName] :: Starting..."	        		
		$nc = 'ComputerName','Port','Protocol','Timeout','Credential','Name';
       	$Endpoint = (  '/services/data/outputs/tcp/{0}/{1}' -f $outputType.ToLower(),$Name );		
	}
	Process
	{          
		Write-Verbose " [$CurrentFunctionName] :: Parameters"
        Write-Verbose " [$CurrentFunctionName] ::  - ParameterSet = $ParamSetName"
		$PSBoundParameters.Keys | foreach{
			Write-Verbose " [$CurrentFunctionName] ::  - $_ = $($PSBoundParameters[$_])"		
		}
		$Arguments = @{};		
		
		Write-Verbose " [$CurrentFunctionName] :: checking for existance of output type [$outputType] with name [$name]"
        $InvokeAPIParams = @{
        			ComputerName = $ComputerName
        			Port         = $Port
        			Protocol     = $Protocol
        			Timeout      = $Timeout
        			Credential   = $Credential
                    name		 = $Name
					outputType	 = $outputType
					outputFields = $outputFields
                }
		
        $ExistingInput = Get-OutputProxy @InvokeAPIParams -erroraction 'silentlycontinue';
        
        if(-not $ExistingInput)
        {
            Write-Host " [$CurrentFunctionName] :: Input [$Name] of type [$outputType] does not exist and cannot be updated"
            Return
        }

		if( -not $pscmdlet.ShouldProcess( $ComputerName, "Updating $outputType Splunk input named $Name" ) )
		{
			return;
		}
											
		$setParameters | foreach{			
			
				#translate the powershell parameter name into its splunk REST api parameter name
				$pn = $_.name;
				
				$value = $ExistingInput.($_.PowerShellName);
				Write-Debug "Existing value of $pn: $value"
				if( $_.value )
				{
					$value = $_.value;
					Write-Debug "Updated value of $pn: $value"
				}
										
				if( $value )
				{
			        switch ($_.powershellType)
			        {		
						{ $_ -match '\[\]' }						{ $Arguments[$pn] = $value -join ',' ; break; }
			            { 'int','switch' -contains $_ }            	{ $Arguments[$pn] = [int]$value; break; }
			            Default                                		{ $Arguments[$pn] = $value; break; }
			        }
				
					Write-Verbose " [$CurrentFunctionName] ::  updating parameter $pn = $($ExistingInput.$($_.PowerShellName)) ; $($_.value); $($Arguments[$pn])"		
				}
		}


		Write-Verbose "Updated input parameters: $arguments";
		
		Write-Verbose " [$CurrentFunctionName] :: Setting up Invoke-APIRequest parameters"
		$InvokeAPIParams = @{
			ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
			Endpoint 	 = $Endpoint
			Verbose      = $VerbosePreference -eq "Continue"
		}
        	
		Write-Verbose " [$CurrentFunctionName] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
		try
		{
		    [XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams -Arguments $Arguments -RequestType POST 
        }
		catch
		{
			Write-Verbose " [$CurrentFunctionName] :: Invoke-SplunkAPIRequest threw an exception: $_"
            Write-Error $_;

			return;
		}
        try
        {
			Write-Verbose " [$CurrentFunctionName] :: Checking for valid results"
			if($Results -and ($Results -is [System.Xml.XmlDocument]))
			{
				Write-Verbose " [Set-InputProxy] :: Fetching index $name"
                $InvokeAPIParams = @{
        			ComputerName = $ComputerName
        			Port         = $Port
        			Protocol     = $Protocol
        			Timeout      = $Timeout
        			Credential   = $Credential
                    name		 = $Name
					outputType	 = $outputType
					outputFields = $outputFields
                }
                Get-OutputProxy @InvokeAPIParams 
			}
			else
			{
				Write-Verbose " [$CurrentFunctionName] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
			}
		}
		catch
		{
			Write-Verbose " [$CurrentFunctionName] :: threw an exception: $_"
            Write-Error $_
		}
	}
	End
	{
		Write-Verbose " [$CurrentFunctionName] :: =========    End   ========="
	}
} # Set-OutputProxy

#endregion Set-OutputProxy

#region New-InputProxy

function New-InputProxy
{
	[Cmdletbinding(SupportsShouldProcess=$true)]
    Param(
	
		[Parameter(Mandatory=$true)]
		[Hashtable]$outputFields,

		[Parameter(Mandatory=$true)]
		[Hashtable] $newParameters,
		
		[Parameter(Mandatory=$true)]
		[string] $outputType,

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
		$CurrentFunctionName = $MyInvocation.MyCommand;

        Write-Verbose " [$CurrentFunctionName] :: Starting..."	        		
		$nc = 'ComputerName','Port','Protocol','Timeout','Credential', 'OutputFields','OutputType', 'newParameters';
		$Endpoint = "/services/data/inputs/{0}" -f $outputType.ToLower();
		
	}
	Process
	{          
		Write-Verbose " [$CurrentFunctionName] :: Parameters"
        Write-Verbose " [$CurrentFunctionName] ::  - ParameterSet = $ParamSetName"
		$Arguments = @{};
		
		$PSBoundParameters.Keys | foreach{
			Write-Verbose " [$CurrentFunctionName] ::  - $_ = $($PSBoundParameters[$_])"		
			if( $nc -notcontains $_ )
			{
				$arguments.Add( $_, $PSBoundParameters[$_] );
			}
		}
		
		Write-Verbose " [$CurrentFunctionName] ::  - Endpoint = $Endpoint"
		        
		if( -not $pscmdlet.ShouldProcess( $ComputerName, "Creating new Splunk application named $Name" ) )
		{
			return;
		}
        
        Write-Verbose " [$CurrentFunctionName] :: checking for existance of input of type [$OutputType] with name [$Name]"
        $InvokeAPIParams = @{
        			ComputerName = $ComputerName
        			Port         = $Port
        			Protocol     = $Protocol
        			Timeout      = $Timeout
        			Credential   = $Credential
                    name		 = $Name
					outputType	 = $outputType
					outputFields = $outputFields
                }
        $ExistingInput = Get-OutputProxy @InvokeAPIParams -erroraction 'silentlycontinue';
        
        if($ExistingInput)
        {
            Write-Host " [$CurrentFunctionName] :: Output of type [$outputType] with name [$Name] already exists: [ $($ExistingInput.ServiceEndpoint) ]"
            Return
        }

		Write-Verbose " [$CurrentFunctionName] :: Setting up Invoke-APIRequest parameters"
		$InvokeAPIParams = @{
			ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
			Endpoint 	 = $Endpoint
			Verbose      = $VerbosePreference -eq "Continue"
		}
        	
		$newParameters | foreach{			
				
				Write-Verbose "[$CurrentFunctionName] ::  processing parameter $($_.name)"
				$newp = $_;				
				
				$pn = $newp.name;				
				$value = $newp.value;

		        switch ($newp.type)
		        {		
		            { 'Number','Boolean' -contains $_}    { $Arguments[$pn] = [int]$value; break; }
		            Default                               { $Arguments[$pn] = $value; break; }
		        }
				
				Write-Verbose " [$CurrentFunctionName] ::  updating property [$pn] = [$($Arguments[$pn])]"		
		}


		Write-Verbose "Updated input parameters: $arguments";
		Write-Verbose " [$CurrentFunctionName] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
		try
		{
		    [XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams -Arguments $Arguments -RequestType POST 
        }
		catch
		{
			Write-Verbose " [$CurrentFunctionName] :: Invoke-SplunkAPIRequest threw an exception: $_"
            Write-Error $_;

			return;
		}
        try
        {
			Write-Verbose " [$CurrentFunctionName] :: Checking for valid results"
			if($Results -and ($Results -is [System.Xml.XmlDocument]))
			{
				Write-Verbose " [$CurrentFunctionName] :: Fetching Application $name"
                $InvokeAPIParams = @{
        			ComputerName = $ComputerName
        			Port         = $Port
        			Protocol     = $Protocol
        			Timeout      = $Timeout
        			Credential   = $Credential
                    name		 = $Name
					outputType	 = $outputType
					outputFields = $outputFields
                }
                Get-OutputProxy @InvokeAPIParams
			}
			else
			{
				Write-Verbose " [$CurrentFunctionName] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
			}
		}
		catch
		{
			Write-Verbose " [$CurrentFunctionName] :: New-InputProxy threw an exception: $_"
            Write-Error $_
		}
	}
	End
	{
		Write-Verbose " [$CurrentFunctionName] :: =========    End   ========="
	}
} # New-InputProxy

#endregion

function Get-SplunkOutputDefault
{
	<#
        .Synopsis 
            Obtains global Splunk TCP output properties.
            
        .Description
            Obtains global Splunk TCP output properties.
            
		.OUTPUTS
            This function does not produce pipeline output.
            
        .Notes
	        NAME:      Get-SplunkOutputGlobal
	        AUTHOR:    Splunk\bshell
	        Website:   www.splunk.com
	        #Requires -Version 2.0
    #>
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
		#The name of the input to retrieve
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
        [String]
        # Name of the Splunk instance to get the settings for (Default is ( get-splunkconnectionobject ).ComputerName.)
		$ComputerName = ( get-splunkconnectionobject ).ComputerName,
        
        [Parameter()]
        [int]
		# Port of the REST Instance (i.e. 8089) (Default is ( get-splunkconnectionobject ).Port.)
		$Port            = ( get-splunkconnectionobject ).Port,
        
        [Parameter()]
        [ValidateSet("http", "https")]
        [STRING]
        # Protocol to use to access the REST API must be 'http' or 'https' (Default is ( get-splunkconnectionobject ).Protocol.)
		$Protocol     = ( get-splunkconnectionobject ).Protocol,
        
        [Parameter()]
        [int]
        # How long to wait for the REST API to respond (Default is ( get-splunkconnectionobject ).Timeout.)	
		$Timeout         = ( get-splunkconnectionobject ).Timeout,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        # Credential object with the user name and password used to access the REST API.	
		$Credential = ( get-splunkconnectionobject ).Credential        
    )
	Begin 
	{
		$integerFields = 'dropEventsOnQueueFull,heartbeatFrequency' -split ',';
		$booleanFields = 'blockOnQueueFull,disabled,indexAndForward,sendCookedData' -split ',';
		
		$of = @{
			'integer' = $integerFields;
			'boolean' = $booleanFields;
		};
		$ot = 'default';		
	}
	Process 
	{
		
				
		Get-OutputProxy @PSBoundParameters -OutputType $ot -OutputFields $of
	}
	End
	{
	}
}

function Disable-SplunkOutputDefault()
{
	<#
        .Synopsis 
            Disables default Splunk forwarding settings.
            
        .Description
            Disables default Splunk forwarding settings.
            
		.OUTPUTS
            This function does not produce pipeline output.
            
        .Notes
	        NAME:      Get-SplunkOutputGlobal
	        AUTHOR:    Splunk\bshell
	        Website:   www.splunk.com
	        #Requires -Version 2.0
    #>
	[CmdletBinding(SupportsShouldProcess=$true)]
    Param(	
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]
        # Name of the Splunk instance to get the settings for (Default is ( get-splunkconnectionobject ).ComputerName.)
		$ComputerName = ( get-splunkconnectionobject ).ComputerName,
        
        [Parameter()]
        [int]
		# Port of the REST Instance (i.e. 8089) (Default is ( get-splunkconnectionobject ).Port.)
		$Port            = ( get-splunkconnectionobject ).Port,
        
        [Parameter()]
        [ValidateSet("http", "https")]
        [STRING]
        # Protocol to use to access the REST API must be 'http' or 'https' (Default is ( get-splunkconnectionobject ).Protocol.)
		$Protocol     = ( get-splunkconnectionobject ).Protocol,
        
        [Parameter()]
        [int]
        # How long to wait for the REST API to respond (Default is ( get-splunkconnectionobject ).Timeout.)	
		$Timeout         = ( get-splunkconnectionobject ).Timeout,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        # Credential object with the user name and password used to access the REST API.	
		$Credential = ( get-splunkconnectionobject ).Credential        
    )

	
	begin
	{
	}
	
	process
	{
		$integerFields = 'dropEventsOnQueueFull,heartbeatFrequency' -split ',';
		$booleanFields = 'blockOnQueueFull,disabled,indexAndForward,sendCookedData' -split ',';
		$outputType = 'default';
		
		Remove-OutputProxy @PSBoundParameters -OutputType $outputType -Name 'tcpout' -OutputFields @{
			integer = $integerFields;
			boolean = $booleanFields;
		}

	}
	
	end
	{
	}
}

function Enable-SplunkOutputDefault()
{
	<#
        .Synopsis 
            Enables default Splunk forwarding settings.
            
        .Description
            Enables default Splunk forwarding settings.
            
		.OUTPUTS
            This function does not produce pipeline output.
    #>
	[CmdletBinding(SupportsShouldProcess=$true)]
    Param(	
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]
        # Name of the Splunk instance to get the settings for (Default is ( get-splunkconnectionobject ).ComputerName.)
		$ComputerName = ( get-splunkconnectionobject ).ComputerName,
        
        [Parameter()]
        [int]
		# Port of the REST Instance (i.e. 8089) (Default is ( get-splunkconnectionobject ).Port.)
		$Port            = ( get-splunkconnectionobject ).Port,
        
        [Parameter()]
        [ValidateSet("http", "https")]
        [STRING]
        # Protocol to use to access the REST API must be 'http' or 'https' (Default is ( get-splunkconnectionobject ).Protocol.)
		$Protocol     = ( get-splunkconnectionobject ).Protocol,
        
        [Parameter()]
        [int]
        # How long to wait for the REST API to respond (Default is ( get-splunkconnectionobject ).Timeout.)	
		$Timeout         = ( get-splunkconnectionobject ).Timeout,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        # Credential object with the user name and password used to access the REST API.	
		$Credential = ( get-splunkconnectionobject ).Credential        
    )

	
	begin
	{
	}
	
	process
	{
		set-splunkOutputDefault @PSBoundParameters -disabled:$false | Out-Null
	}
	
	end
	{
	}
}

function Set-SplunkOutputDefault
{
[CmdletBinding(SupportsShouldProcess=$true)]
    Param(	

		[Parameter()]
		[switch] 
		# If disabled, data destined for forwarders will be thrown away if no forwarders in the group are reachable.
		$blockOnQueueFull,
		
		[Parameter()]
		[string[]] 
		# one or more target group names, specified later in [tcpout:<target_group>] stanzas of outputs.conf.spec file.
		# The forwarder sends all data to the specified groups. If you don't want to forward data automatically, don't set this attribute. Can be overridden by an inputs.conf _TCP_ROUTING setting, which in turn can be overridden by a props.conf/transforms.conf modifier.
		# Starting with 4.2, this attribute is no longer required.
		$defaultGroup,
		
		[Parameter()]
		[switch]
		# Disables default tcpout settings
		$disabled,
		
		[Parameter()]
		[int]
		# If set to a positive number, wait the specified number of seconds before throwing out all new events until the output queue has space. Defaults to -1 (do not drop events).
		# CAUTION: Do not set this value to a positive integer if you are monitoring files.
		# Setting this to -1 or 0 causes the output queue to block when it gets full, whih causes further blocking up the processing chain. If any target group's queue is blocked, no more data reaches any other target group.
		# Using auto load-balancing is the best way to minimize this condition, because, in that case, multiple receivers must be down (or jammed up) before queue blocking can occur.
		$dropEventsOnQueueFull,
		
		[Parameter()]
		[int]
		# How often (in seconds) to send a heartbeat packet to the receiving server.
		# Heartbeats are only sent if sendCookedData=true. Defaults to 30 seconds.
		$heartbeatFrequency,
		
		[Parameter()]
		[switch]
		# Specifies whether to index all data locally, in addition to forwarding it. Defaults to false.
		# This is known as an "index-and-forward" configuration. This attribute is only available for heavy forwarders. It is available only at the top level [tcpout] stanza in outputs.conf. It cannot be overridden in a target group.
		$indexAndForward 	,
		
		[Parameter()]
		[string]
		[ValidatePattern( '\d+(KB|MB|GB)?' )]
		# Sets the maximum size of the forwarder's output queue. It also sets the maximum size of the wait queue to 3x this value, if you have enabled indexer acknowledgment (useACK=true).
		# Although the wait queue and the output queues are both configured by this attribute, they are separate queues. The setting determines the maximum size of the queue's in-memory (RAM) buffer.
		# For heavy forwarders sending parsed data, maxQueueSize is the maximum number of events. Since events are typically much shorter than data blocks, the memory consumed by the queue on a parsing forwarder will likely be much smaller than on a non-parsing forwarder, if you use this version of the setting.
		# If specified as a lone integer (for example, maxQueueSize=100), maxQueueSize indicates the maximum number of queued events (for parsed data) or blocks of data (for unparsed data). A block of data is approximately 64KB. For non-parsing forwarders, such as universal forwarders, that send unparsed data, maxQueueSize is the maximum number of data blocks.
		# If specified as an integer followed by KB, MB, or GB (for example, maxQueueSize=100MB), maxQueueSize indicates the maximum RAM allocated to the queue buffer. Defaults to 500KB (which means a maximum size of 500KB for the output queue and 1500KB for the wait queue, if any).	
		$maxQueueSize,
		
		[Parameter()]
		[switch]
		# If true, events are cooked (have been processed by Splunk). If false, events are raw and untouched prior to sending. Defaults to true.
		# Set to false if you are sending to a third-party system. 
		$sendCookedData,
		
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]
        # Name of the Splunk instance to get the settings for (Default is ( get-splunkconnectionobject ).ComputerName.)
		$ComputerName = ( get-splunkconnectionobject ).ComputerName,
        
        [Parameter()]
        [int]
		# Port of the REST Instance (i.e. 8089) (Default is ( get-splunkconnectionobject ).Port.)
		$Port            = ( get-splunkconnectionobject ).Port,
        
        [Parameter()]
        [ValidateSet("http", "https")]
        [STRING]
        # Protocol to use to access the REST API must be 'http' or 'https' (Default is ( get-splunkconnectionobject ).Protocol.)
		$Protocol     = ( get-splunkconnectionobject ).Protocol,
        
        [Parameter()]
        [int]
        # How long to wait for the REST API to respond (Default is ( get-splunkconnectionobject ).Timeout.)	
		$Timeout         = ( get-splunkconnectionobject ).Timeout,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        # Credential object with the user name and password used to access the REST API.	
		$Credential = ( get-splunkconnectionobject ).Credential        
    )

	begin
	{
		$nc = @(
			'ComputerName','Port','Protocol','Timeout','Credential', 
			'OutputFields','OutputType','Name','Filter',
			'ErrorAction', 'ErrorVariable'	
		);
		
		$booleanFields = 'blockOnQueueFull,disabled,indexAndForward,sendCookedData' -split ',';
		$integerFields = 'heartbeatFrequency,dropEventsOnQueueFull' -split ',';
		
		write-debug "Integer fields: $integerFields"
		write-debug "Boolean fields: $booleanFields"
	}
	
	process
	{
		$setParameters = $MyInvocation.myCommand.Parameters.Values | where { $nc -notcontains $_.name } |		
			foreach {
				Write-Debug "creating set parameter $($_.name) with type $($_.type)"
				@{
					powerShellName=$_.name;
					powerShellType=$_.parametertype.tostring();
					name=$_.name;
					type=$_.parametertype.tostring();
				}
			};
			
			
		$setParameters | foreach { 
			$sp = $_;
			$key = $_.powershellname;
			$_.value = $PSBoundParameters[$key]; 
			
			if( $_.value -is [array] )
			{
				$_.value = $_.value -join ',';
			}
			
			$PSBoundParameters.Remove($key) | out-null;
			
			write-debug "set parameter key [$key] value [$($_.value)]";
		}
						
		Set-OutputProxy @PSBoundParameters -name 'tcpout' -OutputType 'default' -SetParameters $setParameters -OutputFields @{
			'integer' = $integerFields;
			'boolean' = $booleanFields;
		}
	}
	
	end
	{
	}

}

Export-ModuleMember -Function *splunk*;