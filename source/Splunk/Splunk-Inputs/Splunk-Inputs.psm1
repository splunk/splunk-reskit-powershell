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

#region Inputs

#region Get-InputProxy
function Get-InputProxy
{
	[CmdletBinding(DefaultParameterSetName='byFilter')]
    Param(

		[Parameter(Mandatory=$true)]
		[Hashtable[]]$outputFields,
		
		[Parameter(Mandatory=$true)]
		[ValidateSet( 'ad','monitor','oneshot','registry','script','tcp/cooked','tcp/raw','tcp/ssl','udp','win-wmi-collections','win-event-log-collections','win-perfmon' )]
		[string] $inputType,
		
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
			$Endpoint = "/services/data/inputs/$($inputType.tolower())"
	        Write-Verbose " [$CurrentFunctionName] :: Starting..."	        
			
			$ParamSetName = $pscmdlet.ParameterSetName
	        #list of non-REST argument names
			$nc = @(
				'ComputerName','Port','Protocol','Timeout','Credential', 
				'OutputFields','InputType','Name','Filter',
				'ErrorAction', 'ErrorVariable'	
			);
			
	        switch ($ParamSetName)
	        {
	            "byFilter"  { 
					
					$WhereFilter = { $_.Name -match $Filter }
				}
	            "byName"    { 
					$Endpoint = (  '/servicesNS/nobody/system/data/inputs/{0}/{1}' -f $inputType.ToLower(),$Name );					
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
					$sdkTypeName = "Splunk.SDK.Input.$inputType"
	                Write-Verbose " [$CurrentFunctionName] :: Creating Hash Table to be used to create $sdkTypeName"
	                
	                foreach($Entry in $Results.feed.entry)
	                {
	                    $MyObj = @{
	                        ComputerName                = $ComputerName
	                        Name                 		= $Entry.Title
	                        ServiceEndpoint             = $Entry.link | ?{$_.rel -eq "edit"} | select -ExpandProperty href
	                    }
	                    
						$ignoreParams = ('eai:attributes,eai:acl' -split '\s*,\s*') + @($outputFields.ignore);
						$booleanParams = @($outputFields.boolean);
						$intParams = @($outputFields.integer);
												
	                    switch ($Entry.content.dict.key)
	                    {
							{ $ignoreParams -contains $_.name }         { Write-Debug "ignoring key $_"; continue; }
	                        { $booleanParams -contains $_.name }        { Write-Debug "taking boolean action on key $_"; $Myobj.Add( $_.Name, [bool]([int]$_.'#text') ); continue;}													
	                        { $intParams -contains $_.name }            { Write-Debug "taking integer action on key $_"; $Myobj.Add( $_.Name, ([int]$_.'#text') ); continue; }
	                        Default                                     { 
																			Write-Debug "taking default action on key $_";
																			
																			#translate list XML to array
																			if( $_.list -and $_.list.item )
																			{
																				Write-Debug "taking array action on key $_";
																				[string[]]$i = $_.list.item | %{ 
																					write-debug "item: $_"
																					$_;
																				}
																				$Myobj.Add($_.Name,$i); 
																			}
																			# assume single string value
																			else
																			{
																				Write-Debug "taking default string action on key $_";
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
	            Write-Verbose " [$CurrentFunctionName] :: Get-InputProxy threw an exception: $_"
	            Write-Error $_
	        }
	    
	}
	End 
    {
	        Write-Verbose " [$CurrentFunctionName] :: =========    End   ========="	    
	}
}
#endregion Get-InputProxy

#region Remove-SplunkInput

function Remove-InputProxy
{	
	[Cmdletbinding(SupportsShouldProcess=$true,ConfirmImpact='high')]
    Param(
	
		[Parameter(Mandatory=$true)]
		[Hashtable[]]$outputFields,

		[Parameter(Mandatory=$true)]
		[ValidateSet( 'ad','monitor','oneshot','registry','script','tcp/cooked','tcp/raw','tcp/ssl','udp','win-event-log-collections','win-perfmon' )]
		[string] $inputType,

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

        	$Endpoint = "/servicesNS/nobody/search/data/inputs/{0}/{1}" -f $inputType.ToLower(),$Name;					
	}
	Process
	{          
		Write-Verbose " [$CurrentFunctionName] :: Parameters"
        Write-Verbose " [$CurrentFunctionName] ::  - ParameterSet = $ParamSetName"

		$Arguments = @{};
		
		$PSBoundParameters.Keys | foreach{
			Write-Verbose " [$CurrentFunctionName] ::  - $_ = $PSBoundParameters[$_]"		
			if( $nc -notcontains $_ )
			{
				$arguments.Add( $_, $PSBoundParameters[$_] );
			}
		}
		
		Write-Verbose " [$CurrentFunctionName] ::  - Endpoint = $Endpoint"
		        
		if( -not( $Force -or $pscmdlet.ShouldProcess( $ComputerName, "Removing Splunk $inputType input named $Name" ) ) )
		{
			return;
		}
        
        Write-Verbose " [$CurrentFunctionName] :: checking for existance of [$inputType] input [$Name]"
        $InvokeAPIParams = @{
        			ComputerName = $ComputerName
        			Port         = $Port
        			Protocol     = $Protocol
        			Timeout      = $Timeout
        			Credential   = $Credential
                    name		 = $Name
					inputType	 = $inputType
					outputFields = $outputFields
                }
        $ExistingApplication = Get-InputProxy @InvokeAPIParams -erroraction 'silentlycontinue';
        
        if( -not $ExistingApplication )
        {
            Write-Debug " [$CurrentFunctionName] :: Input [$Name] of type [$inputType] does not exist on computer [$ComputerName]"
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

#region Set-InputProxy
function Set-InputProxy
{
	[Cmdletbinding(SupportsShouldProcess=$true)]
    Param(
	
		[Parameter(Mandatory=$true)]
		[Hashtable[]]$outputFields,

		[Parameter(Mandatory=$true)]
		[Hashtable[]] $setParameters,
		
		[Parameter(Mandatory=$true)]
		[string] $inputType,

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
       	$Endpoint = (  '/servicesNS/nobody/system/data/inputs/{0}/{1}' -f $inputType.ToLower(),$Name );		
	}
	Process
	{          
		Write-Verbose " [$CurrentFunctionName] :: Parameters"
        Write-Verbose " [$CurrentFunctionName] ::  - ParameterSet = $ParamSetName"
		$PSBoundParameters.Keys | foreach{
			Write-Verbose " [$CurrentFunctionName] ::  - $_ = $($PSBoundParameters[$_])"		
		}
		$Arguments = @{};		
		
		Write-Verbose " [$CurrentFunctionName] :: checking for existance of input type [$inputType] with name [$name]"
        $InvokeAPIParams = @{
        			ComputerName = $ComputerName
        			Port         = $Port
        			Protocol     = $Protocol
        			Timeout      = $Timeout
        			Credential   = $Credential
                    name		 = $Name
					inputType	 = $inputType
					outputFields = $outputFields
                }
        $ExistingInput = Get-InputProxy @InvokeAPIParams -erroraction 'silentlycontinue';
        
        if(-not $ExistingInput)
        {
            Write-Host " [$CurrentFunctionName] :: Input [$Name] of type [$inputType] does not exist and cannot be updated"
            Return
        }

		if( -not $pscmdlet.ShouldProcess( $ComputerName, "Updating $inputType Splunk input named $Name" ) )
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
					inputType	 = $InputType
					outputFields = $outputFields
                }
                Get-InputProxy @InvokeAPIParams 
			}
			else
			{
				Write-Verbose " [$CurrentFunctionName] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
			}
		}
		catch
		{
			Write-Verbose " [$CurrentFunctionName] :: Set-InputProxy threw an exception: $_"
            Write-Error $_
		}
	}
	End
	{
		Write-Verbose " [$CurrentFunctionName] :: =========    End   ========="
	}
} # Set-InputProxy

#endregion Set-InputProxy

#region New-InputProxy

function New-InputProxy
{
	[Cmdletbinding(SupportsShouldProcess=$true)]
    Param(
	
		[Parameter(Mandatory=$true)]
		[Hashtable[]]$outputFields,

		[Parameter(Mandatory=$true)]
		[Hashtable[]] $newParameters,
		
		[Parameter(Mandatory=$true)]
		[string] $inputType,

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
		$nc = 'ComputerName','Port','Protocol','Timeout','Credential', 'OutputFields','InputType', 'newParameters';
		$Endpoint = "/services/data/inputs/{0}" -f $inputType.ToLower();
		
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

		$Name = $newParameters.Name;
		if( -not $pscmdlet.ShouldProcess( $ComputerName, "Creating new Splunk application named $Name" ) )
		{
			return;
		}
        
        Write-Verbose " [$CurrentFunctionName] :: checking for existance of input of type [$InputType] with name [$Name]"
        $InvokeAPIParams = @{
        			ComputerName = $ComputerName
        			Port         = $Port
        			Protocol     = $Protocol
        			Timeout      = $Timeout
        			Credential   = $Credential
                    name		 = $Name
					inputType	 = $InputType
					outputFields = $outputFields
                }
        $ExistingInput = Get-InputProxy @InvokeAPIParams -erroraction 'silentlycontinue';
        
        if($ExistingInput)
        {
            Write-Host " [$CurrentFunctionName] :: Input of type [$inputType] with name [$Name] already exists: [ $($ExistingInput.ServiceEndpoint) ]"
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
					inputType	 = $InputType
					outputFields = $outputFields
                }
                Get-InputProxy @InvokeAPIParams
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
#region input parameter table
$inputs = @{

'Ad' = @{
sethelp = @'
<#
    .Synopsis 
        Modifies a given AD monitoring stanza.
        
    .Description
        Modifies a given AD monitoring stanza.
        
    .Example

    .Inputs
        This function does not accept pipeline input.
        
    .Outputs
        This function does not output data to the pipeline.
        
    .Notes
        NAME:      {{NAME}} 
	    AUTHOR:    Splunk\bshell
	    Website:   www.splunk.com
	    #Requires -Version 2.0
#>
'@
gethelp = @'
<#
    .Synopsis 
        Gets current AD monitoring configuration.
        
    .Description
        Gets current AD monitoring configuration.
        
    .Example

    .Inputs
        This function does not accept pipeline input.
        
    .Outputs
        This function does not output data to the pipeline.
        
    .Notes
        NAME:      {{NAME}} 
	    AUTHOR:    Splunk\bshell
	    Website:   www.splunk.com
	    #Requires -Version 2.0
#>
'@
newhelp = @'
<#
    .Synopsis 
        Creates new or modifies existing performance monitoring settings.
        
    .Description
        Creates new or modifies existing performance monitoring settings.
        
    .Example

    .Inputs
        This function does not accept pipeline input.
        
    .Outputs
        This function does not output data to the pipeline.
        
    .Notes
        NAME:      {{NAME}} 
	    AUTHOR:    Splunk\bshell
	    Website:   www.splunk.com
	    #Requires -Version 2.0
#>
'@
	setParameters = @(
		@{
			powerShellName='monitorSubtree';
			powerShellType=' Inherited ';
			name='monitorSubtree';
			type='Inherited';
			required=$True;
			desc='Inherited'
		}
		@{
			powerShellName='disabled';
			powerShellType=' Inherited ';
			name='disabled';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='index';
			powerShellType=' Inherited ';
			name='index';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='startingNode';
			powerShellType=' Inherited ';
			name='startingNode';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='targetDc';
			powerShellType=' Inherited ';
			name='targetDc';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
	);
	newParameters = @(
		@{
			powerShellName='monitorSubtree';
			powerShellType='int';
			name='monitorSubtree';
			type='Number';
			required=$True;
			desc='Whether or not to monitor the subtree(s) of a given directory tree path.  1 means yes, 0 means no.'
		}
		@{
			powerShellName='name';
			powerShellType='string';
			name='name';
			type='String';
			required=$True;
			desc='A unique name that represents a configuration or set of configurations for a specific domain controller (DC).'
		}
		@{
			powerShellName='disabled';
			powerShellType='int';
			name='disabled';
			type='Number';
			required=$False;
			desc='Indicates whether the monitoring is disabled.'
		}
		@{
			powerShellName='index';
			powerShellType='string';
			name='index';
			type='String';
			required=$False;
			desc='The index in which to store the gathered data.'
		}
		@{
			powerShellName='startingNode';
			powerShellType='string';
			name='startingNode';
			type='String';
			required=$False;
			desc='Where in the Active Directory directory tree to start monitoring.  If not specified, will attempt to start at the root of the directory tree.'
		}
		@{
			powerShellName='targetDc';
			powerShellType='string';
			name='targetDc';
			type='String';
			required=$False;
			desc='Specifies a fully qualified domain name of a valid, network-accessible DC.  If not specified, Splunk will obtain the local computer DC.'
		}
	);
};

'win-event-log-collections' = @{
newhelp = @'
<#
    .Synopsis 
        Creates of modifies existing event log collection settings.  You can configure both native and WMI collection with this endpoint.

        
    .Description
        Creates of modifies existing event log collection settings.  You can configure both native and WMI collection with this endpoint.

        
    .Example

    .Inputs
        This function does not accept pipeline input.
        
    .Outputs
        This function does not output data to the pipeline.
        
    .Notes
        NAME:      {{NAME}} 
	    AUTHOR:    Splunk\bshell
	    Website:   www.splunk.com
	    #Requires -Version 2.0
#>
'@
sethelp = @'
<#
    .Synopsis 
        Modifies existing event log collection.

        
    .Description
        Modifies existing event log collection.

        
    .Example

    .Inputs
        This function does not accept pipeline input.
        
    .Outputs
        This function does not output data to the pipeline.
        
    .Notes
        NAME:      {{NAME}} 
	    AUTHOR:    Splunk\bshell
	    Website:   www.splunk.com
	    #Requires -Version 2.0
#>
'@
	newParameters = @(
		@{
			powerShellName='lookuphost';
			powerShellType='string';
			name='lookup_host';
			type='String';
			required=$True;
			desc='This is a host from which we will monitor log events.  To specify additional hosts to be monitored via WMI, use the "hosts" parameter.'
		}
		@{
			powerShellName='name';
			powerShellType='string';
			name='name';
			type='String';
			required=$True;
			desc='This is the name of the collection.  This name will appear in configuration file, as well as the source and the sourcetype of the indexed data.  If the value is "localhost", it will use native event log collection; otherwise, it will use WMI.'
		}
		@{
			powerShellName='hosts';
			powerShellType='string[]';
			name='hosts';
			type='String';
			required=$False;
			desc='A list of addtional hosts to be used for monitoring.  The first host should be specified with "lookup_host", and the additional ones using this parameter.'
		}
		@{
			powerShellName='index';
			powerShellType='string';
			name='index';
			type='String';
			required=$False;
			desc='The index in which to store the gathered data.'
		}
		@{
			powerShellName='logs';
			powerShellType='string[]';
			name='logs';
			type='String';
			required=$False;
			desc='A list of event log names to gather data from.'
		}
	);
	setParameters = @(
		@{
			powerShellName='lookuphost';
			powerShellType=' Inherited ';
			name='lookup_host';
			type='Inherited';
			required=$True;
			desc='Inherited'
		}
		@{
			powerShellName='hosts';
			powerShellType=' Inherited ';
			name='hosts';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='index';
			powerShellType=' Inherited ';
			name='index';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='logs';
			powerShellType=' Inherited ';
			name='logs';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
	);
};

'Monitor' = @{
newhelp = @'
<#
    .Synopsis 
        Create a new file or directory monitor input.

        
    .Description
        Create a new file or directory monitor input.

        
    .Example

    .Inputs
        This function does not accept pipeline input.
        
    .Outputs
        This function does not output data to the pipeline.
        
    .Notes
        NAME:      {{NAME}} 
	    AUTHOR:    Splunk\bshell
	    Website:   www.splunk.com
	    #Requires -Version 2.0
#>
'@
sethelp = @'
<#
    .Synopsis 
        Update properties of the named monitor input.

        
    .Description
        Update properties of the named monitor input.

        
    .Example

    .Inputs
        This function does not accept pipeline input.
        
    .Outputs
        This function does not output data to the pipeline.
        
    .Notes
        NAME:      {{NAME}} 
	    AUTHOR:    Splunk\bshell
	    Website:   www.splunk.com
	    #Requires -Version 2.0
#>
'@
	newParameters = @(
		@{
			powerShellName='name';
			powerShellType='string';
			name='name';
			type='String';
			required=$True;
			desc='The file or directory path to monitor on the system.'
		}
		@{
			powerShellName='blacklist';
			powerShellType='string';
			name='blacklist';
			type='String';
			required=$False;
			desc='Specify a regular expression for a file path. The file path that matches this regular expression is not indexed.'
		}
		@{
			powerShellName='checkindex';
			powerShellType='switch';
			name='check-index';
			type='Boolean';
			required=$False;
			desc='If set to true, the "index" value will be checked to ensure that it is the name of a valid index.'
		}
		@{
			powerShellName='checkpath';
			powerShellType='switch';
			name='check-path';
			type='Boolean';
			required=$False;
			desc='If set to true, the "name" value will be checked to ensure that it exists.'
		}
		@{
			powerShellName='crcsalt';
			powerShellType='string';
			name='crc-salt';
			type='String';
			required=$False;
			desc='A string that modifies the file tracking identity for files in this input.  The magic value "<SOURCE>" invokes special behavior (see admin documentation).'
		}
		@{
			powerShellName='followTail';
			powerShellType='switch';
			name='followTail';
			type='Boolean';
			required=$False;
			desc='If set to true, files that are seen for the first time will be read from the end.'
		}
		@{
			powerShellName='host';
			powerShellType='string';
			name='host';
			type='String';
			required=$False;
			desc='The value to populate in the host field for events from this data input.'
		}
		@{
			powerShellName='hostregex';
			powerShellType='string';
			name='host_regex';
			type='String';
			required=$False;
			desc='Specify a regular expression for a file path. If the path for a file matches this regular expression, the captured value is used to populate the host field for events from this data input.  The regular expression must have one capture group.'
		}
		@{
			powerShellName='hostsegment';
			powerShellType='int';
			name='host_segment';
			type='Number';
			required=$False;
			desc='Use the specified slash-separate segment of the filepath as the host field value.'
		}
		@{
			powerShellName='ignoreolderthan';
			powerShellType='string';
			name='ignore-older-than';
			type='String';
			required=$False;
			desc='Specify a time value. If the modification time of a file being monitored falls outside of this rolling time window, the file is no longer being monitored.'
		}
		@{
			powerShellName='index';
			powerShellType='string';
			name='index';
			type='String';
			required=$False;
			desc='Which index events from this input should be stored in.'
		}
		@{
			powerShellName='recursive';
			powerShellType='switch';
			name='recursive';
			type='Boolean';
			required=$False;
			desc='Setting this to "false" will prevent monitoring of any subdirectories encountered within this data input.'
		}
		@{
			powerShellName='renamesource';
			powerShellType='string';
			name='rename-source';
			type='String';
			required=$False;
			desc='The value to populate in the source field for events from this data input.  The same source should not be used for multiple data inputs.'
		}
		@{
			powerShellName='sourcetype';
			powerShellType='string';
			name='sourcetype';
			type='String';
			required=$False;
			desc='The value to populate in the sourcetype field for incoming events.'
		}
		@{
			powerShellName='timebeforeclose';
			powerShellType='int';
			name='time-before-close';
			type='Number';
			required=$False;
			desc='When Splunk reaches the end of a file that is being read, the file will be kept open for a minimum of the number of seconds specified in this value.  After this period has elapsed, the file will be checked again for more data.'
		}
		@{
			powerShellName='whitelist';
			powerShellType='string';
			name='whitelist';
			type='String';
			required=$False;
			desc='Specify a regular expression for a file path. Only file paths that match this regular expression are indexed.'
		}
	);
	
	setParameters = @(
		@{
			powerShellName='blacklist';
			powerShellType=' Inherited ';
			name='blacklist';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='checkindex';
			powerShellType=' Inherited ';
			name='check-index';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='checkpath';
			powerShellType=' Inherited ';
			name='check-path';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='crcsalt';
			powerShellType=' Inherited ';
			name='crc-salt';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='followTail';
			powerShellType=' Inherited ';
			name='followTail';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='host';
			powerShellType=' Inherited ';
			name='host';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='hostregex';
			powerShellType=' Inherited ';
			name='host_regex';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='hostsegment';
			powerShellType=' Inherited ';
			name='host_segment';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='ignoreolderthan';
			powerShellType=' Inherited ';
			name='ignore-older-than';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='index';
			powerShellType=' Inherited ';
			name='index';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='recursive';
			powerShellType=' Inherited ';
			name='recursive';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='renamesource';
			powerShellType=' Inherited ';
			name='rename-source';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='sourcetype';
			powerShellType=' Inherited ';
			name='sourcetype';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='timebeforeclose';
			powerShellType=' Inherited ';
			name='time-before-close';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='whitelist';
			powerShellType=' Inherited ';
			name='whitelist';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
	);
};

'OneShot' = @{
newhelp = @'
<#
    .Synopsis 
        Queues a file for immediate indexing by the file input subsystem. The file must be locally accessible from the server.
This endpoint can handle any single file: plain, compressed or archive. The file is indexed in full, regardless of whether it has been indexed before.

        
    .Description
        Queues a file for immediate indexing by the file input subsystem. The file must be locally accessible from the server.
This endpoint can handle any single file: plain, compressed or archive. The file is indexed in full, regardless of whether it has been indexed before.

        
    .Example

    .Inputs
        This function does not accept pipeline input.
        
    .Outputs
        This function does not output data to the pipeline.
        
    .Notes
        NAME:      {{NAME}} 
	    AUTHOR:    Splunk\bshell
	    Website:   www.splunk.com
	    #Requires -Version 2.0
#>
'@

	newParameters = @(
		@{
			powerShellName='name';
			powerShellType='string';
			name='name';
			type='String';
			required=$True;
			desc='The path to the file to be indexed. The file must be locally accessible by the server.'
		}
		@{
			powerShellName='host';
			powerShellType='string';
			name='host';
			type='String';
			required=$False;
			desc='The value of the "host" field to be applied to data from this file.'
		}
		@{
			powerShellName='hostregex';
			powerShellType='string';
			name='host_regex';
			type='String';
			required=$False;
			desc='td'
		}
		@{
			powerShellName='hostsegment';
			powerShellType='int';
			name='host_segment';
			type='Number';
			required=$False;
			desc='Use the specified slash-separate segment of the path as the host field value.'
		}
		@{
			powerShellName='index';
			powerShellType='string';
			name='index';
			type='String';
			required=$False;
			desc='The destination index for data processed from this file.'
		}
		@{
			powerShellName='renamesource';
			powerShellType='string';
			name='rename-source';
			type='String';
			required=$False;
			desc='The value of the "source" field to be applied to data from this file.'
		}
		@{
			powerShellName='sourcetype';
			powerShellType='string';
			name='sourcetype';
			type='String';
			required=$False;
			desc='The value of the "sourcetype" field to be applied to data from this file.'
		}
	);
	
	setParameters = $null;
};

'win-perfmon' = @{
newhelp = @'
<#
    .Synopsis 
        Creates new or modifies existing performance monitoring collection settings.

        
    .Description
        Creates new or modifies existing performance monitoring collection settings.

        
    .Example

    .Inputs
        This function does not accept pipeline input.
        
    .Outputs
        This function does not output data to the pipeline.
        
    .Notes
        NAME:      {{NAME}} 
	    AUTHOR:    Splunk\bshell
	    Website:   www.splunk.com
	    #Requires -Version 2.0
#>
'@

sethelp = @'
<#
    .Synopsis 
        Modifies existing monitoring stanza

        
    .Description
        Modifies existing monitoring stanza

        
    .Example

    .Inputs
        This function does not accept pipeline input.
        
    .Outputs
        This function does not output data to the pipeline.
        
    .Notes
        NAME:      {{NAME}} 
	    AUTHOR:    Splunk\bshell
	    Website:   www.splunk.com
	    #Requires -Version 2.0
#>
'@
	newParameters = @(
		@{
			powerShellName='interval';
			powerShellType='int';
			name='interval';
			type='Number';
			required=$True;
			desc='How frequently to poll the performance counters.'
		}
		@{
			powerShellName='name';
			powerShellType='string';
			name='name';
			type='String';
			required=$True;
			desc='This is the name of the collection.  This name will appear in configuration file, as well as the source and the sourcetype of the indexed data.'
		}
		@{
			powerShellName='object';
			powerShellType='string';
			name='object';
			type='String';
			required=$True;
			desc='A valid performance monitor object (for example, "Process," "Server," "PhysicalDisk.")'
		}
		@{
			powerShellName='counters';
			powerShellType='string[]';
			name='counters';
			type='String';
			required=$False;
			desc='A list of all counters to monitor. A * is equivalent to all counters.'
		}
		@{
			powerShellName='disabled';
			powerShellType='int';
			name='disabled';
			type='Number';
			required=$False;
			desc='Disables a given monitoring stanza.'
		}
		@{
			powerShellName='index';
			powerShellType='string';
			name='index';
			type='String';
			required=$False;
			desc='The index in which to store the gathered data.'
		}
		@{
			powerShellName='instances';
			powerShellType='string[]';
			name='instances';
			type='String';
			required=$False;
			desc='A list of counter instances.  A * is equivalent to all instances.'
		}
	);
	
	setParameters = @(
		@{
			powerShellName='counters';
			powerShellType=' Inherited ';
			name='counters';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='disabled';
			powerShellType=' Inherited ';
			name='disabled';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='index';
			powerShellType=' Inherited ';
			name='index';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='instances';
			powerShellType=' Inherited ';
			name='instances';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='interval';
			powerShellType=' Inherited ';
			name='interval';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='object';
			powerShellType=' Inherited ';
			name='object';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
	);
};

'Registry' = @{
newhelp = @'
<#
    .Synopsis 
        Creates new or modifies existing registry monitoring settings.

        
    .Description
        Creates new or modifies existing registry monitoring settings.

        
    .Example

    .Inputs
        This function does not accept pipeline input.
        
    .Outputs
        This function does not output data to the pipeline.
        
    .Notes
        NAME:      {{NAME}} 
	    AUTHOR:    Splunk\bshell
	    Website:   www.splunk.com
	    #Requires -Version 2.0
#>
'@
sethelp = @'
<#
    .Synopsis 
        Modifies given registry monitoring stanza.

        
    .Description
        Modifies given registry monitoring stanza.

        
    .Example

    .Inputs
        This function does not accept pipeline input.
        
    .Outputs
        This function does not output data to the pipeline.
        
    .Notes
        NAME:      {{NAME}} 
	    AUTHOR:    Splunk\bshell
	    Website:   www.splunk.com
	    #Requires -Version 2.0
#>
'@

	newParameters = @(
		@{
			powerShellName='baseline';
			powerShellType='int';
			name='baseline';
			type='Number';
			required=$True;
			desc='Specifies whether or not to establish a baseline value for the registry keys.  1 means yes, 0 no.'
		}
		@{
			powerShellName='hive';
			powerShellType='string';
			name='hive';
			type='String';
			required=$True;
			desc='Specifies the registry hive under which to monitor for changes.'
		}
		@{
			powerShellName='name';
			powerShellType='string';
			name='name';
			type='String';
			required=$True;
			desc='Name of the configuration stanza.'
		}
		@{
			powerShellName='proc';
			powerShellType='string';
			name='proc';
			type='String';
			required=$True;
			desc='Specifies a regex.  If specified, will only collected changes if a process name matches that regex.'
		}
		@{
			powerShellName='type';
			powerShellType='string';
			name='type';
			type='String';
			required=$True;
			desc='A regular expression that specifies the type(s) of Registry event(s) that you want to monitor.'
		}
		@{
			powerShellName='disabled';
			powerShellType='int';
			name='disabled';
			type='Number';
			required=$False;
			desc='Indicates whether the monitoring is disabled.'
		}
		@{
			powerShellName='index';
			powerShellType='string';
			name='index';
			type='String';
			required=$False;
			desc='The index in which to store the gathered data.'
		}
		@{
			powerShellName='monitorSubnodes';
			powerShellType='int';
			name='monitorSubnodes';
			type='Number';
			required=$False;
			desc='If set to 1, will monitor all sub-nodes under a given hive.'
		}
	);

	setParameters = @(
		@{
			powerShellName='baseline';
			powerShellType=' Inherited ';
			name='baseline';
			type='Inherited';
			required=$True;
			desc='Inherited'
		}
		@{
			powerShellName='hive';
			powerShellType=' Inherited ';
			name='hive';
			type='Inherited';
			required=$True;
			desc='Inherited'
		}
		@{
			powerShellName='proc';
			powerShellType=' Inherited ';
			name='proc';
			type='Inherited';
			required=$True;
			desc='Inherited'
		}
		@{
			powerShellName='type';
			powerShellType=' Inherited ';
			name='type';
			type='Inherited';
			required=$True;
			desc='Inherited'
		}
		@{
			powerShellName='disabled';
			powerShellType=' Inherited ';
			name='disabled';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='index';
			powerShellType=' Inherited ';
			name='index';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='monitorSubnodes';
			powerShellType=' Inherited ';
			name='monitorSubnodes';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
	);
};

'Script' = @{
newhelp = @'
<#
    .Synopsis 
        Configures settings for new scripted inputs.

        
    .Description
        Configures settings for new scripted inputs.

        
    .Example

    .Inputs
        This function does not accept pipeline input.
        
    .Outputs
        This function does not output data to the pipeline.
        
    .Notes
        NAME:      {{NAME}} 
	    AUTHOR:    Splunk\bshell
	    Website:   www.splunk.com
	    #Requires -Version 2.0
#>
'@
sethelp = @'
<#
    .Synopsis 
        Configures settings for scripted input specified by {name}.

        
    .Description
        Configures settings for scripted input specified by {name}.

        
    .Example

    .Inputs
        This function does not accept pipeline input.
        
    .Outputs
        This function does not output data to the pipeline.
        
    .Notes
        NAME:      {{NAME}} 
	    AUTHOR:    Splunk\bshell
	    Website:   www.splunk.com
	    #Requires -Version 2.0
#>
'@
	newParameters = @(
		@{
			powerShellName='interval';
			powerShellType='int';
			name='interval';
			type='Number';
			required=$True;
			desc='Specify an integer or cron schedule. This parameter specifies how often to execute the specified script, in seconds or a valid cron schedule. If you specify a cron schedule, the script is not executed on start-up.'
		}
		@{
			powerShellName='name';
			powerShellType='string';
			name='name';
			type='String';
			required=$True;
			desc='Specify the name of the scripted input.'
		}
		@{
			powerShellName='disabled';
			powerShellType='switch';
			name='disabled';
			type='Boolean';
			required=$False;
			desc='Specifies whether the input script is disabled.'
		}
		@{
			powerShellName='host';
			powerShellType='string';
			name='host';
			type='String';
			required=$False;
			desc='Sets the host for events from this input. Defaults to whatever host sent the event.'
		}
		@{
			powerShellName='index';
			powerShellType='string';
			name='index';
			type='String';
			required=$False;
			desc='Sets the index for events from this input. Defaults to the main index.'
		}
		@{
			powerShellName='renamesource';
			powerShellType='string';
			name='rename-source';
			type='String';
			required=$False;
			desc='Specify a new name for the source field for the script.'
		}
		@{
			powerShellName='source';
			powerShellType='string';
			name='source';
			type='String';
			required=$False;
			desc='td'
		}
		@{
			powerShellName='sourcetype';
			powerShellType='string';
			name='sourcetype';
			type='String';
			required=$False;
			desc='td'
		}
	);
	setParameters = @(
		@{
			powerShellName='disabled';
			powerShellType=' Inherited ';
			name='disabled';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='host';
			powerShellType=' Inherited ';
			name='host';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='index';
			powerShellType=' Inherited ';
			name='index';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='interval';
			powerShellType=' Inherited ';
			name='interval';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='renamesource';
			powerShellType=' Inherited ';
			name='rename-source';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='source';
			powerShellType=' Inherited ';
			name='source';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='sourcetype';
			powerShellType=' Inherited ';
			name='sourcetype';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
	);	
};

'TCP/Cooked' = @{
newhelp = @'
<#
    .Synopsis 
        Creates a new container for managing cooked data.

        
    .Description
        Creates a new container for managing cooked data.

        
    .Example

    .Inputs
        This function does not accept pipeline input.
        
    .Outputs
        This function does not output data to the pipeline.
        
    .Notes
        NAME:      {{NAME}} 
	    AUTHOR:    Splunk\bshell
	    Website:   www.splunk.com
	    #Requires -Version 2.0
#>
'@
sethelp = @'
<#
    .Synopsis 
        Updates the container for managaing cooked data.

        
    .Description
        Updates the container for managaing cooked data.

        
    .Example

    .Inputs
        This function does not accept pipeline input.
        
    .Outputs
        This function does not output data to the pipeline.
        
    .Notes
        NAME:      {{NAME}} 
	    AUTHOR:    Splunk\bshell
	    Website:   www.splunk.com
	    #Requires -Version 2.0
#>
'@

	newParameters = @(
		@{
			powerShellName='name';
			powerShellType='int';
			name='name';
			type='Number';
			required=$True;
			desc='The port number of this input.'
		}
		@{
			powerShellName='SSL';
			powerShellType='switch';
			name='SSL';
			type='Boolean';
			required=$False;
			desc='If SSL is not already configured, error is returned'
		}
		@{
			powerShellName='connectionhost';
			powerShellType='string';
			name='connection_host';
			type='string';
			required=$False;
			desc='Valid values: (ip | dns | none).  Set the host for the remote server that is sending data.  ip sets the host to the IP address of the remote server sending data. dns sets the host to the reverse DNS entry for the IP address of the remote server sending data. none leaves the host as specified in inputs.conf.  Default value is dns. '
		}
		@{
			powerShellName='disabled';
			powerShellType='switch';
			name='disabled';
			type='Boolean';
			required=$False;
			desc='Indicates whether the input is disabled.'
		}
		@{
			powerShellName='host';
			powerShellType='string';
			name='host';
			type='String';
			required=$False;
			desc='The default value to fill in for events lacking a host value.'
		}
		@{
			powerShellName='restrictToHost';
			powerShellType='string';
			name='restrictToHost';
			type='String';
			required=$False;
			desc='Restrict incoming connections on this port to the host specified here.'
		}
	);
	
	setParameters = @(
		@{
			powerShellName='SSL';
			powerShellType=' Inherited ';
			name='SSL';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='connectionhost';
			powerShellType=' Inherited ';
			name='connection_host';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='disabled';
			powerShellType=' Inherited ';
			name='disabled';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='host';
			powerShellType=' Inherited ';
			name='host';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='restrictToHost';
			powerShellType=' Inherited ';
			name='restrictToHost';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
	);
};

'TCP/Raw' = @{
newhelp = @'
<#
    .Synopsis 
        Creates a new data input for accepting raw TCP data.

        
    .Description
        Creates a new data input for accepting raw TCP data.

        
    .Example

    .Inputs
        This function does not accept pipeline input.
        
    .Outputs
        This function does not output data to the pipeline.
        
    .Notes
        NAME:      {{NAME}} 
	    AUTHOR:    Splunk\bshell
	    Website:   www.splunk.com
	    #Requires -Version 2.0
#>
'@
sethelp = @'
<#
    .Synopsis 
        Updates the container for managing raw data.

        
    .Description
        Updates the container for managing raw data.

        
    .Example

    .Inputs
        This function does not accept pipeline input.
        
    .Outputs
        This function does not output data to the pipeline.
        
    .Notes
        NAME:      {{NAME}} 
	    AUTHOR:    Splunk\bshell
	    Website:   www.splunk.com
	    #Requires -Version 2.0
#>
'@

	newParameters = @(
		@{
			powerShellName='name';
			powerShellType='string';
			name='name';
			type='String';
			required=$True;
			desc='The input port which splunk receives raw data in.'
		}
		@{
			powerShellName='SSL';
			powerShellType='switch';
			name='SSL';
			type='Boolean';
			required=$False;
			desc='	If SSL is not already configured, error is returned '
		}
		@{
			powerShellName='connectionhost';
			powerShellType='string';
			name='connection_host';
			type='string';
			required=$False;
			desc='Valid values: (ip | dns | none).  Specify the remote server that is the connection host.  ip: specifies the IP address of the remote server.  dns: sets the host to the DNS entry of the remote server.  none: leaves the host as specified.'
		}
		@{
			powerShellName='disabled';
			powerShellType='switch';
			name='disabled';
			type='Boolean';
			required=$False;
			desc='Indicates whether the inputs are disabled.'
		}
		@{
			powerShellName='host';
			powerShellType='string';
			name='host';
			type='String';
			required=$False;
			desc='The host from which the indexer gets data.'
		}
		@{
			powerShellName='index';
			powerShellType='string';
			name='index';
			type='String';
			required=$False;
			desc='The index in which to store all generated events.'
		}
		@{
			powerShellName='queue';
			powerShellType='string';
			name='queue';
			type='string';
			required=$False;
			desc='Valid values: (parsingQueue | indexQueue).  Specifies where the input processor should deposit the events it reads. Defaults to parsingQueue.  Set queue to parsingQueue to apply props.conf and other parsing rules to your data. For more information about props.conf and rules for timestamping and linebreaking, refer to props.conf and the online documentation at Edit inputs.conf.  Set queue to indexQueue to send your data directly into the index.'
		}
		@{
			powerShellName='restrictToHost';
			powerShellType='string';
			name='restrictToHost';
			type='String';
			required=$False;
			desc='Allows for restricting this input to only accept data from the host specified here.'
		}
		@{
			powerShellName='source';
			powerShellType='string';
			name='source';
			type='String';
			required=$False;
			desc='Sets the source key/field for events from this input. Defaults to the input file path.  Sets the source key initial value. The key is used during parsing/indexing, in particular to set the source field during indexing. It is also the source field used at search time. As a convenience, the chosen string is prepended with "source::".  Note: Overriding the source key is generally not recommended.Typically, the input layer provides a more accurate string to aid in problem analysis and investigation, accurately recording the file from which the data was retreived. Consider use of source types, tagging, and search wildcards before overriding this value.'
		}
		@{
			powerShellName='sourcetype';
			powerShellType='string';
			name='sourcetype';
			type='String';
			required=$False;
			desc='Set the source type for events from this input.  "sourcetype=" is automatically prepended to <string>.  Defaults to audittrail (if signedaudit=true) or fschange (if signedaudit=false).'
		}
	);
	
	setParameters = @(
		@{
			powerShellName='SSL';
			powerShellType=' Inherited ';
			name='SSL';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='connectionhost';
			powerShellType=' Inherited ';
			name='connection_host';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='disabled';
			powerShellType=' Inherited ';
			name='disabled';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='host';
			powerShellType=' Inherited ';
			name='host';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='index';
			powerShellType=' Inherited ';
			name='index';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='queue';
			powerShellType=' Inherited ';
			name='queue';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='restrictToHost';
			powerShellType=' Inherited ';
			name='restrictToHost';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='source';
			powerShellType=' Inherited ';
			name='source';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='sourcetype';
			powerShellType=' Inherited ';
			name='sourcetype';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
	);
};

'UDP' = @{
newhelp = @'
<#
    .Synopsis 
        Create a new UDP data input.

        
    .Description
        Create a new UDP data input.

        
    .Example

    .Inputs
        This function does not accept pipeline input.
        
    .Outputs
        This function does not output data to the pipeline.
        
    .Notes
        NAME:      {{NAME}} 
	    AUTHOR:    Splunk\bshell
	    Website:   www.splunk.com
	    #Requires -Version 2.0
#>
'@

sethelp = @'
<#
    .Synopsis 
        Edit properties of the named UDP data input.

        
    .Description
        Edit properties of the named UDP data input.

        
    .Example

    .Inputs
        This function does not accept pipeline input.
        
    .Outputs
        This function does not output data to the pipeline.
        
    .Notes
        NAME:      {{NAME}} 
	    AUTHOR:    Splunk\bshell
	    Website:   www.splunk.com
	    #Requires -Version 2.0
#>
'@
	newParameters = @(
		@{
			powerShellName='name';
			powerShellType='string';
			name='name';
			type='String';
			required=$True;
			desc='The UDP port that this input should listen on.'
		}
		@{
			powerShellName='connectionhost';
			powerShellType='string';
			name='connection_host';
			type='string';
			required=$False;
			desc='Valid values: (ip | dns | none).  ip: The host field for incoming events is set to the IP address of the remote server.  dns: The host field is set to the DNS entry of the remote server.  none: The host field remains unchanged.  Defaults to ip.'
		}
		@{
			powerShellName='host';
			powerShellType='string';
			name='host';
			type='String';
			required=$False;
			desc='The value to populate in the host field for incoming events.'
		}
		@{
			powerShellName='index';
			powerShellType='string';
			name='index';
			type='String';
			required=$False;
			desc='Which index events from this input should be stored in.'
		}
		@{
			powerShellName='noappendingtimestamp';
			powerShellType='switch';
			name='no_appending_timestamp';
			type='Boolean';
			required=$False;
			desc='If set to true, prevents Splunk from prepending a timestamp and hostname to incoming events.'
		}
		@{
			powerShellName='noprioritystripping';
			powerShellType='switch';
			name='no_priority_stripping';
			type='Boolean';
			required=$False;
			desc='If set to true, Splunk will not remove the priority field from incoming syslog events.'
		}
		@{
			powerShellName='queue';
			powerShellType='string';
			name='queue';
			type='String';
			required=$False;
			desc='Which queue events from this input should be sent to.  Generally this does not need to be changed.'
		}
		@{
			powerShellName='source';
			powerShellType='string';
			name='source';
			type='String';
			required=$False;
			desc='The value to populate in the source field for incoming events.  The same source should not be used for multiple data inputs.'
		}
		@{
			powerShellName='sourcetype';
			powerShellType='string';
			name='sourcetype';
			type='String';
			required=$False;
			desc='The value to populate in the sourcetype field for incoming events.'
		}
	);
	
	setParameters = @(
		@{
			powerShellName='connectionhost';
			powerShellType=' Inherited ';
			name='connection_host';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='host';
			powerShellType=' Inherited ';
			name='host';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='index';
			powerShellType=' Inherited ';
			name='index';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='noappendingtimestamp';
			powerShellType=' Inherited ';
			name='no_appending_timestamp';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='noprioritystripping';
			powerShellType=' Inherited ';
			name='no_priority_stripping';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='queue';
			powerShellType=' Inherited ';
			name='queue';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='source';
			powerShellType=' Inherited ';
			name='source';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
		@{
			powerShellName='sourcetype';
			powerShellType=' Inherited ';
			name='sourcetype';
			type='Inherited';
			required=$False;
			desc='Inherited'
		}
	);
};

'win-wmi-collections' = @{
newhelp = @'
<#
    .Synopsis 
        Creates of modifies existing WMI collection settings.

        
    .Description
        Creates of modifies existing WMI collection settings.

        
    .Example

    .Inputs
        This function does not accept pipeline input.
        
    .Outputs
        This function does not output data to the pipeline.
        
    .Notes
        NAME:      {{NAME}} 
	    AUTHOR:    Splunk\bshell
	    Website:   www.splunk.com
	    #Requires -Version 2.0
#>
'@

sethelp = @'
<#
    .Synopsis 
        Updates existing WMI collection settings.

        
    .Description
        Updates existing WMI collection settings.

        
    .Example

    .Inputs
        This function does not accept pipeline input.
        
    .Outputs
        This function does not output data to the pipeline.
        
    .Notes
        NAME:      {{NAME}} 
	    AUTHOR:    Splunk\bshell
	    Website:   www.splunk.com
	    #Requires -Version 2.0
#>
'@
	newParameters = @(
		@{
			powerShellName='classes';
			powerShellType='string';
			name='classes';
			type='String';
			required=$True;
			desc='A valid WMI class name.'
		}
		@{
			powerShellName='interval';
			powerShellType='int';
			name='interval';
			type='Number';
			required=$True;
			desc='The interval at which the WMI provider(s) will be queried.'
		}
		@{
			powerShellName='lookuphost';
			powerShellType='string';
			name='lookup_host';
			type='String';
			required=$True;
			desc='This is the server from which we will be gathering WMI data.  If you need to gather data from more than one machine, additional servers can be specified in the server parameter.'
		}
		@{
			powerShellName='name';
			powerShellType='string';
			name='name';
			type='String';
			required=$True;
			desc='This is the name of the collection.  This name will appear in configuration file, as well as the source and the sourcetype of the indexed data.'
		}
		@{
			powerShellName='disabled';
			powerShellType='int';
			name='disabled';
			type='Number';
			required=$False;
			desc='Disables the given collection.'
		}
		@{
			powerShellName='fields';
			powerShellType='string[]';
			name='fields';
			type='String';
			required=$False;
			desc='A list of all properties that you want to gather from the given class.'
		}
		@{
			powerShellName='index';
			powerShellType='string';
			name='index';
			type='String';
			required=$False;
			desc='The index in which to store the gathered data.'
		}
		@{
			powerShellName='instances';
			powerShellType='string[]';
			name='instances';
			type='String';
			required=$False;
			desc='A list of all instances of a given class for which data is to be gathered.'
		}
		@{
			powerShellName='server';
			powerShellType='string[]';
			name='server';
			type='String';
			required=$False;
			desc='A list of additional servers that you want to gather data from.  Use this if you need to gather from more than a single machine.  See also lookup_host parameter.'
		}
	);
	
	setParameters = @(
		@{
			powerShellName='classes';
			powerShellType='string';
			name='classes';
			type='String';
			required=$True;
			desc='A valid WMI class name.'
		}
		@{
			powerShellName='interval';
			powerShellType='int';
			name='interval';
			type='Number';
			required=$True;
			desc='The interval at which the WMI provider(s) will be queried.'
		}
		@{
			powerShellName='lookuphost';
			powerShellType='string';
			name='lookup_host';
			type='String';
			required=$True;
			desc='This is the server from which we will be gathering WMI data.  If you need to gather data from more than one machine, additional servers can be specified in the server parameter.'
		}
		@{
			powerShellName='disabled';
			powerShellType='int';
			name='disabled';
			type='Number';
			required=$False;
			desc='Disables the given collection.'
		}
		@{
			powerShellName='fields';
			powerShellType='string[]';
			name='fields';
			type='String';
			required=$False;
			desc='A list of all properties that you want to gather from the given class.'
		}
		@{
			powerShellName='index';
			powerShellType='string';
			name='index';
			type='String';
			required=$False;
			desc='The index in which to store the gathered data.'
		}
		@{
			powerShellName='instances';
			powerShellType='string[]';
			name='instances';
			type='String';
			required=$False;
			desc='A list of all instances of a given class for which data is to be gathered.'
		}
		@{
			powerShellName='server';
			powerShellType='string[]';
			name='server';
			type='String';
			required=$False;
			desc='A list of additional servers that you want to gather data from.  Use this if you need to gather from more than a single machine.  See also lookup_host parameter.'
		}
	);
};

};
#endregion input parameter table

#region generative gets
$inputs | select -ExpandProperty keys | foreach {
	$inputType = $_;
	$functionTag = ( $inputType -split '[-/]' | foreach { $_[0].toString().ToUpper() + ($_[1..($_.length-1)] -join '') } ) -join '';
	
	$newp = $inputs[$_].newParameters
	$p = $newp | foreach { new-object psobject -prop $_ } | group type;
	$integerFields = @();
	$booleanFields = @();
	switch ($p)
	{
		{ $_.Name -eq 'Number' } { 
			$integerFields = $_.group | select -ExpandProperty name; 
			continue; 
		}
		{ $_.Name -eq 'Boolean' } { 
			$booleanFields = $_.group | select -ExpandProperty name; 
			continue; 
		}
		default {}
	}		
	
@"
	function Get-SplunkInput$functionTag
	{
	<#
        .Synopsis 
            Obtains the specified Splunk input.
            
        .Description
            Obtains the specified Splunk input.
            
		.OUTPUTS
            This function does not produce pipeline output.
            
        .Notes
	        NAME:      Get-SplunkInput$functionTag
	        AUTHOR:    Splunk\bshell
	        Website:   www.splunk.com
	        #Requires -Version 2.0
    #>
	[CmdletBinding(DefaultParameterSetName='byFilter')]
    Param(
		[Parameter()]
		#Indicates the maximum number of entries to return. To return all entries, specify 0. 
		[int]`$Count = 30,
		
		[Parameter()]
		#Index for first item to return. 
		[int]`$Offset = 0,
		
		[Parameter()]
		#Boolean predicate to filter results
		[string]`$Search,
		
		[Parameter(Position=0,ParameterSetName='byFilter')]
		#Regular expression used to match index name
		[string]`$Filter = '.*',
		
		[Parameter(Position=0,ParameterSetName='byName',Mandatory=`$true)]
		#The name of the input to retrieve
		[string]`$Name,
		
		[Parameter()]
		[ValidateSet("asc","desc")]
		#Indicates whether to sort the entries returned in ascending or descending order. Valid values: (asc | desc).  Defaults to asc.
		[string]`$SortDirection = "asc",
		
		[Parameter()]
		[ValidateSet("auto","alpha","alpha_case","num")]
		#Indicates the collating sequence for sorting the returned entries. Valid values: (auto | alpha | alpha_case | num).  Defaults to auto.
		[string]`$SortMode = "auto",
		
		[Parameter()]
		# Field to sort by.
		[string]`$SortKey,
		
                [Parameter(ValueFromPipelineByPropertyName=`$true,ValueFromPipeline=`$true)]
        [String]
        # Name of the Splunk instance to get the settings for (Default is ( get-splunkconnectionobject ).ComputerName.)
		`$ComputerName = ( get-splunkconnectionobject ).ComputerName,
        
        [Parameter()]
        [int]
		# Port of the REST Instance (i.e. 8089) (Default is ( get-splunkconnectionobject ).Port.)
		`$Port            = ( get-splunkconnectionobject ).Port,
        
        [Parameter()]
        [ValidateSet("http", "https")]
        [STRING]
        # Protocol to use to access the REST API must be 'http' or 'https' (Default is ( get-splunkconnectionobject ).Protocol.)
		`$Protocol     = ( get-splunkconnectionobject ).Protocol,
        
        [Parameter()]
        [int]
        # How long to wait for the REST API to respond (Default is ( get-splunkconnectionobject ).Timeout.)	
		`$Timeout         = ( get-splunkconnectionobject ).Timeout,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        # Credential object with the user name and password used to access the REST API.	
		`$Credential = ( get-splunkconnectionobject ).Credential        
    )
	Begin 
	{
	}
	Process 
	{
		Get-InputProxy @PSBoundParameters -InputType $inputType -OutputFields @{
			integer = @('$($integerFields -join "', '" )');
			boolean = @('$($booleanFields -join "', '" )');
		}
	}
	End
	{
	}
}
"@
} | Invoke-Expression ;
#endregion

#region generative removes
$inputs | select -ExpandProperty keys | foreach {
	$inputType = $_;
	$functionTag = ( $inputType -split '[-/]' | foreach { $_[0].toString().ToUpper() + ($_[1..($_.length-1)] -join '') } ) -join '';
		
	$newp = $inputs[$_].newParameters
	$p = $newp | foreach { new-object psobject -prop $_ } | group type;
	
	$integerFields = @();
	$booleanFields = @();
	switch ($p)
	{
		{ $_.Name -eq 'Number' } { 
			$integerFields = $_.group | select -ExpandProperty name; 
			continue; 
		}
		{ $_.Name -eq 'Boolean' } { 
			$booleanFields = $_.group | select -ExpandProperty name; 
			continue; 
		}
		default {}
	}		

@"
function Remove-SplunkInput$functionTag
{
	<#
        .Synopsis 
            Removes the specified Splunk input.
            
        .Description
            Removes the specified Splunk input.
            
		.OUTPUTS
            This function does not produce pipeline output.
            
        .Notes
	        NAME:      Remove-SplunkInput$functionTag
	        AUTHOR:    Splunk\bshell
	        Website:   www.splunk.com
	        #Requires -Version 2.0
    #>

	[CmdletBinding(DefaultParameterSetName='byFilter')]
    Param(
		[Parameter(ValueFromPipelineByPropertyName=`$true,Mandatory=`$true)]
		# The name of the input to remove.
		[string]`$Name,
		
		[Parameter()]
		# Specify to bypass standard PowerShell confirmation
		[switch]`$Force,
		
        [Parameter(ValueFromPipelineByPropertyName=`$true,ValueFromPipeline=`$true)]
        [String]
        # Name of the Splunk instance to get the settings for (Default is ( get-splunkconnectionobject ).ComputerName.)
		`$ComputerName = ( get-splunkconnectionobject ).ComputerName,
        
        [Parameter()]
        [int]
		# Port of the REST Instance (i.e. 8089) (Default is ( get-splunkconnectionobject ).Port.)
		`$Port            = ( get-splunkconnectionobject ).Port,
        
        [Parameter()]
        [ValidateSet("http", "https")]
        [STRING]
        # Protocol to use to access the REST API must be 'http' or 'https' (Default is ( get-splunkconnectionobject ).Protocol.)
		`$Protocol     = ( get-splunkconnectionobject ).Protocol,
        
        [Parameter()]
        [int]
        # How long to wait for the REST API to respond (Default is ( get-splunkconnectionobject ).Timeout.)	
		`$Timeout         = ( get-splunkconnectionobject ).Timeout,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        # Credential object with the user name and password used to access the REST API.	
		`$Credential = ( get-splunkconnectionobject ).Credential        

    )
	Begin 
	{
	}
	Process 
	{
		Remove-InputProxy @PSBoundParameters -InputType $inputType -OutputFields @{
			integer = @('$($integerFields -join "', '" )');
			boolean = @('$($booleanFields -join "', '" )');
		}
	}
	End
	{
	}
}
"@
} | Invoke-Expression ;
#endregion

#region generative sets
$inputs | select -ExpandProperty keys | where { $inputs[$_].setParameters } | foreach {
	
	$inputType = $_;
	$functionTag = ( $inputType -split '[-/]' | foreach { $_[0].toString().ToUpper() + ($_[1..($_.length-1)] -join '') } ) -join '';
	$functionName = "Set-SplunkInput$functionTag"
	$help = $inputs[$_].sethelp -replace '{{NAME}}',$functionName 
	$newp = $inputs[$_].newParameters
	$p = $newp | foreach { new-object psobject -prop $_ } | group type;
	
	$integerFields = @();
	$booleanFields = @();
	switch ($p)
	{
		{ $_.Name -eq 'Number' } { 
			$integerFields = $_.group | select -ExpandProperty name; 
			continue; 
		}
		{ $_.Name -eq 'Boolean' } { 
			$booleanFields = $_.group | select -ExpandProperty name; 
			continue; 
		}
		default {}
	}		

	$setParameterDeclarations = $inputs[$_].setParameters | foreach {
		$setParam = $_;
		$np = $newp | where {$_.name -eq $setParam.Name };
		$pstype = $np.powerShellType
		$psname = $np.powerShellName
		$desc = $np.desc -replace "[`r`n]+",' ';
		"[Parameter()]`n[$pstype]`n#$desc`n`$$psname"
	}
	
	$setParameterDeclarations = $setParameterDeclarations -join ",`n";
	
	$setParameterDeclarations | Write-Debug
	
	$setParameters = $inputs[$_].setParameters | foreach {
		$setParam = $_;
		$np = $newp | where {$_.name -eq $setParam.Name };
		$pstype = $np.powerShellType
		$psname = $np.powerShellName		
		"$psname = `$PSBoundParameters['$psname'];"
	}
	
	$setParameters | Write-Debug;

@"
	function $functionName
	{
	$help
	[CmdletBinding(SupportsShouldProcess=`$true)]
    Param(
		$setParameterDeclarations,
		
		[Parameter(ValueFromPipelineByPropertyName=`$true,Mandatory=`$true)]
        [String]
		# The name of the input to update.
		`$Name,
		
        [Parameter(ValueFromPipelineByPropertyName=`$true,ValueFromPipeline=`$true)]
        [String]
        # Name of the Splunk instance to get the settings for (Default is ( get-splunkconnectionobject ).ComputerName.)
		`$ComputerName = ( get-splunkconnectionobject ).ComputerName,
        
        [Parameter()]
        [int]
		# Port of the REST Instance (i.e. 8089) (Default is ( get-splunkconnectionobject ).Port.)
		`$Port            = ( get-splunkconnectionobject ).Port,
        
        [Parameter()]
        [ValidateSet("http", "https")]
        [STRING]
        # Protocol to use to access the REST API must be 'http' or 'https' (Default is ( get-splunkconnectionobject ).Protocol.)
		`$Protocol     = ( get-splunkconnectionobject ).Protocol,
        
        [Parameter()]
        [int]
        # How long to wait for the REST API to respond (Default is ( get-splunkconnectionobject ).Timeout.)	
		`$Timeout         = ( get-splunkconnectionobject ).Timeout,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        # Credential object with the user name and password used to access the REST API.	
		`$Credential = ( get-splunkconnectionobject ).Credential        		
    )
	Begin 
	{
	}
	Process 
	{
		write-debug "Tag: $functionTag; InputType: $inputType";
		`$setParameters = `$inputs['$inputType'].setParameters;
		`$newParameters = `$inputs['$inputType'].newParameters;
		`$setParameters | foreach { 
			`$sp = `$_;
			`$key = `$_.powershellname;
			`$np = `$newParameters | where {`$_.powershellname -eq `$key };
			write-debug "Removing bound parameter `$key"; 

			#copy inherited property values from new-parameter set
			`$u = @{};
			`$_.keys | where {`$sp[`$_] -match 'Inherited' } | foreach {
				
				write-debug "inheriting set parameter value for key `$_";
				`$u[`$_] = `$np[`$_];
			}
			`$u.keys | foreach { `$sp[`$_] = `$u[`$_] };

			`$_.value = `$PSBoundParameters[`$key]; 
			
			if( `$_.value -is [array] )
			{
				`$_.value = `$_.value -join ',';
			}
			
			`$PSBoundParameters.Remove(`$key) | out-null;
			
			write-debug "set parameter key [`$key] value [`$(`$_.value)]";
		}

		write-debug "Integer fields: $integerFields"
		write-debug "Boolean fields: $booleanFields"
		
		Set-InputProxy @PSBoundParameters -InputType $inputType -SetParameters `$setParameters -OutputFields @{
			integer = @('$($integerFields -join "', '" )');
			boolean = @('$($booleanFields -join "', '" )');
		}
	}
	End
	{
	}
}
"@
} | %{ $_ | write-debug; $_ | Invoke-Expression };
#endregion generative sets

#region generative news
$inputs | select -ExpandProperty keys | where { $inputs[$_].newParameters } | foreach {
	
	$inputType = $_;
	$functionTag = ( $inputType -split '[-/]' | foreach { $_[0].toString().ToUpper() + ($_[1..($_.length-1)] -join '') } ) -join '';
	$functionName = "New-SplunkInput$functionTag"
	$newp = $inputs[$_].newParameters
	$p = $newp | foreach { new-object psobject -prop $_ } | group type;
	$help = $inputs[$_].newhelp -replace '{{NAME}}',$functionName;
	$integerFields = @();
	$booleanFields = @();
	switch ($p)
	{
		{ $_.Name -eq 'Number' } { 
			$integerFields = $_.group | select -ExpandProperty name; 
			continue; 
		}
		{ $_.Name -eq 'Boolean' } { 
			$booleanFields = $_.group | select -ExpandProperty name; 
			continue; 
		}
		default {}
	}		

	$newParameterDeclarations = $inputs[$_].newParameters | foreach {	
		$pstype = $_.powerShellType
		$psname = $_.powerShellName
		$mandatory = $_.required;
		$desc = $_.desc -replace "[`r`n]+",' ';
		"[Parameter(Mandatory=`$$mandatory)]`n[$pstype]`n#$desc`n`$$psname"
		#"[Parameter()][$pstype] `$$psname"
	}
	
	$newParameterDeclarations = $newParameterDeclarations -join ",`n";
	
	$newParameterDeclarations | Write-Debug
	
	$newParameters = $inputs[$_].newParameters | foreach {
		$pstype = $_.powerShellType
		$psname = $_.powerShellName
		"$psname = `$PSBoundParameters['$psname'];"
	}
	
	$newParameters | Write-Debug;

@"
	function $functionName
	{
	$help
	[CmdletBinding(SupportsShouldProcess=`$true)]
    Param(
		$newParameterDeclarations,
		
        [Parameter(ValueFromPipelineByPropertyName=`$true,ValueFromPipeline=`$true)]
        [String]
        # Name of the Splunk instance to get the settings for (Default is ( get-splunkconnectionobject ).ComputerName.)
		`$ComputerName = ( get-splunkconnectionobject ).ComputerName,
        
        [Parameter()]
        [int]
		# Port of the REST Instance (i.e. 8089) (Default is ( get-splunkconnectionobject ).Port.)
		`$Port            = ( get-splunkconnectionobject ).Port,
        
        [Parameter()]
        [ValidateSet("http", "https")]
        [STRING]
        # Protocol to use to access the REST API must be 'http' or 'https' (Default is ( get-splunkconnectionobject ).Protocol.)
		`$Protocol     = ( get-splunkconnectionobject ).Protocol,
        
        [Parameter()]
        [int]
        # How long to wait for the REST API to respond (Default is ( get-splunkconnectionobject ).Timeout.)	
		`$Timeout         = ( get-splunkconnectionobject ).Timeout,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        # Credential object with the user name and password used to access the REST API.	
		`$Credential = ( get-splunkconnectionobject ).Credential        
    )
	Begin 
	{
	}
	Process 
	{
		write-debug "Tag: $functionTag; InputType: $inputType";
		`$newParameters = `$inputs['$inputType'].newParameters;
		`$newParameters | foreach { 
			`$key = `$_.powershellname;
			write-debug "Removing bound parameter `$key"; 
			
			`$_.value = `$PSBoundParameters[`$key]; 
			if( `$_.value -is [array] )
			{
				`$_.value = `$_.value -join ',';
			}

			`$PSBoundParameters.Remove(`$key) | out-null;
			
			write-debug "new parameter key [`$key] value [`$(`$_.value)]";
		}
		
		write-debug "Integer fields: $integerFields"
		write-debug "Boolean fields: $booleanFields"
		New-InputProxy @PSBoundParameters -InputType $inputType -NewParameters `$newParameters -OutputFields @{
			integer = @('$($integerFields -join "', '" )');
			boolean = @('$($booleanFields -join "', '" )');
		}
	}
	End
	{
	}
}
"@
} | %{ $_ | write-debug; $_ | Invoke-Expression };
#endregion generative news

#$inputs = $null;

#endregion Inputs

Export-ModuleMember -Function *splunk*;