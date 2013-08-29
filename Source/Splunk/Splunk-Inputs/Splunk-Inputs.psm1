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
		[string] $inputType,
		
		[Parameter()]
		[string] $inputUrl = $inputType,

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
			$Endpoint = "/services/data/inputs/$($inputUrl.tolower())"
	        Write-Verbose " [$CurrentFunctionName] :: Starting..."	        
			
			$ParamSetName = $pscmdlet.ParameterSetName
	        #list of non-REST argument names
			$nc = @(
				'ComputerName','Port','Protocol','Timeout','Credential', 
				'OutputFields','InputType', 'InputUrl', 'Name','Filter',
				'ErrorAction', 'ErrorVariable'	
			);
			
	        switch ($ParamSetName)
	        {
	            "byFilter"  { 
					
					$WhereFilter = { $_.Name -match $Filter }
				}
	            "byName"    { 
					$Endpoint = (  '/servicesNS/nobody/system/data/inputs/{0}/{1}' -f $inputUrl.ToLower(),$Name );					
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
	                    
						$ignoreParams = ('eai:attributes,eai:acl' -split '\s*,\s*') + @($outputFields.ignore) + @('ComputerName','Name','ServiceEndpoint');
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
		[string] $inputType,
        
        [Parameter()]		
		[string] $inputUrl = $inputType,

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

        	$Endpoint = "/servicesNS/nobody/search/data/inputs/{0}/{1}" -f $inputUrl.ToLower(),$Name;					
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
                    inputUrl     = $inputUrl
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
        
        [Parameter()]		
		[string] $inputUrl = $inputType,

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
       	$Endpoint = (  '/servicesNS/nobody/system/data/inputs/{0}/{1}' -f $inputUrl.ToLower(),$Name );		
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
                    inputUrl     = $inputUrl
					outputFields = $outputFields
                }
        $ExistingInput = Get-InputProxy @InvokeAPIParams -erroraction 'silentlycontinue';
        
        if(-not $ExistingInput)
        {
            Write-Host " [$CurrentFunctionName] :: Input [$Name] of type [$inputType] does not exist on [$ComputerName] and cannot be updated"
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
				Write-Debug "Existing value of ${pn}: $value"
				if( $_.value )
				{
					$value = $_.value;
					Write-Debug "Updated value of ${pn}: $value"
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
					inputUrl     = $inputUrl
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
        
        [Parameter()]		
		[string] $inputUrl = $inputType,

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
		$nc = 'ComputerName','Port','Protocol','Timeout','Credential', 'OutputFields','InputType', 'InputUrl',  'newParameters';
		$Endpoint = "/services/data/inputs/{0}" -f $inputUrl.ToLower();
		
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
		
		$newParameters | foreach{
			Write-Verbose " [$CurrentFunctionName] :: (new parameter) $($_.Name) = $($_.Value)"		
		}
		
		Write-Verbose " [$CurrentFunctionName] ::  - Endpoint = $Endpoint"

		$Name = $newParameters | where { $_.Name -eq 'Name' } | %{ $_.Value };
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
                    inputUrl     = $inputUrl
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
                    inputUrl     = $inputUrl
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
<# .ExternalHelp ../Splunk-Help.xml #>
'@
newhelp = @'
<# .ExternalHelp ../Splunk-Help.xml #>
'@
	getExamples = @'
.Example
	Get-SplunkInputAd -ComputerName splunk9.server.com	
	
	Retrieves a list of all Windows Active Directory monitoring inputs from the server splunk9.server.com.	

.Example
	Get-SplunkInputAd -Count 5 -ComputerName splunk9.server.com -Protocol https	
	
	Retrieves information on the first 5 defined Active Directory inputs on the server splunk9.server.com. Uses the HTTPS protocol to connect to the Splunk instance.	
'@
	
		
	removeExamples = @'
.Example
	Get-SplunkInputAd | Remove-SplunkInputAd 
	
	Prompts for the removal of all existing Windows Active Directory inputs on the default Splunk connection.	
	
.Example
	Remove-SplunkInputAd -name NTDSObjectsMonitor -Computername 192.168.31.112	
	
	Removes the Active Directory monitor input called "NTDSObjectsMonitor" on the server with IP address 192.168.31.112.
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
			powerShellType='switch';
			name='monitorSubtree';
			type='Number';
			required=$False;
			desc='Whether or not to monitor the subtree(s) of a given directory tree path.'
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
			powerShellType='switch';
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
<# .ExternalHelp ../Splunk-Help.xml #>
'@
sethelp = @'
<# .ExternalHelp ../Splunk-Help.xml #>
'@

	getExamples = @'
.Example
	Get-SplunkInputWinEventLogCollections	
	
	Retrieves a list of all Windows event log data inputs on the default Splunk instance.	
	
.Example	
	Get-SplunkInputWinEventLogCollections -computername splunk005 -search security	
	
	Retrieves information on all Windows event log inputs from the server "splunk005" which contain the word "security" anywhere in the results.
'@
	removeExamples = @'
.Example
	Remove-SplunkInputWinEventLogCollections -ComputerName splunk5.server.com -Name 'perf'
	
	Removes the Windows Event Log monitoring input named 'perf' from the Splunk instance splunk5.server.com.
	
.Example
	Get-SplunkInputWinEventLogCollections | Remove-SplunkInputWinEventLogCollections
	
	Removes all Windows Event Log monitoring inputs from the default Splunk instance.
	
.Example
	Remove-SplunkInputWinWmiCollections -name WMI-CPU -ComputerName splunk10.server.com -port 7979 -protocol https	
	
	Removes the WMI input named "WMI-CPU" on the Splunk instance on server splunk10.server.com, port 7979 using the HTTPS protocol.
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
<# .ExternalHelp ../Splunk-Help.xml #>
'@
sethelp = @'
<# .ExternalHelp ../Splunk-Help.xml #>
'@
	getExamples = @'
.Example
	Get-SplunkInputMonitor -Computername splunk6.server.com -Credential $credential	
	
	Retrieves a list of all file monitoring inputs on the server splunk6.server.com, using credentials cached in the $credential variable.	
	
.Example
	Get-SplunkInputMonitor -Computername 192.168.100.5 -Count 10 -Offset 2 -Search 'stats'	
	
	Retrieves information on up to 10 file monitoring inputs on the computer 192.168.100.5, beginning with the second input, whose names contain the string 'stats'.	
'@

	removeExamples = @'
.Example
	Remove-SplunkInputMonitor -Name etcMon
	
	Prompts for the removal of an existing file monitoring data input named etcMon on the default Splunk instance.	
	
.Example
	Remove-SplunkInputMonitor -name jdodlog -ComputerName splunk23.server.com	
	
	Removes the Splunk file monitor named "jdodlog" on the server splunk23.server.com.

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
<# .ExternalHelp ../Splunk-Help.xml #>
'@


	getExamples= @'
.Example
	Get-SplunkInputOneShot	
	
	Retrieves a list of all in-progress one-shot data inputs on the default Splunk instance.
	
.Example
	Get-SplunkInputOneShot -Computername splunk5.server.com -Count 5 -SortMode desc	
	
	Retrieves information on the first 5 in-progress one-shot data inputs on the server splunk5.server.com, and sorts them in descending order.	
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
	
	disableRemove = $true;
	setParameters = $null;
};

'win-perfmon' = @{
newhelp = @'
<# .ExternalHelp ../Splunk-Help.xml #>
'@

sethelp = @'
<# .ExternalHelp ../Splunk-Help.xml #>
'@
	getExamples=@'
.Example
	Get-SplunkInputWinPerfmon	
	
	Retrieves a list of all Windows Performance Monitor inputs on the default Splunk instance.	
	
.Example
	Get-SplunkInputWinPerfmon -computername splunk21.server.com -filter disk	
	
	Retrieves information on all Windows performance monitoring inputs from server splunk21.server.com whose names contain the word "disk".	
'@

	removeExamples = @'
.Example
	Remove-SplunkInputWinPerfmon -name "CPU"
	
	Prompts for the removal of an existing Windows Performance Monitor input named "CPU" from the default Splunk instance.	
	
.Example
	Remove-SplunkInputWinPerfmon -name FreeDiskSpace -ComputerName splunk13.server.com -force	
	
	Forcibly removes the "FreeDiskSpace" Windows Performance Monitor input on splunk13.server.com.
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
<# .ExternalHelp ../Splunk-Help.xml #>
'@
sethelp = @'
<# .ExternalHelp ../Splunk-Help.xml #>
'@
	getExamples=@'
.Example
	Get-SplunkInputRegistry	
	
	Retrieves a list of all Windows Registry inputs on the default Splunk instance.	
	
.Example
	Get-SplunkInputRegistry -Computername 192.168.31.205,192.168.31.206 -Filter "User"	
	
	Retrieves information on all Windows Registry inputs from the servers 192.168.31.205 and 192.168.31.206 which contain "User" in their names.	
'@
	removeExamples=@'
.Example
	Get-SplunkInputRegistry	| Remove-SplunkInputRegistry
	
	Removes all Windows Registry inputs on the default Splunk instance.	
	
.Example
	Remove-SplunkInputRegistry -Computername 192.168.31.205,192.168.31.206 -Name "User"	
	
	Removes the Windows Registry input named "User" from the servers 192.168.31.205 and 192.168.31.206.	
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
<# .ExternalHelp ../Splunk-Help.xml #>
'@
sethelp = @'
<# .ExternalHelp ../Splunk-Help.xml #>
'@
	getExamples=@'
.Example
	Get-SplunkInputScript	
	
	Retrieves a list of all scripted inputs on the default Splunk instance.	
	
.Example	
	Get-SplunkInputScript -Computername $servers -Count 5	
	
	Retrieves information on the first 5 scripted inputs from the servers listed in the $servers variable.	
'@
	removeExamples = @'
.Example
	Get-SplunkInputScript | Remove-SplunkInputScript	
	
	Prompts for the removal of all existing scripted input from the default Splunk instance.	
	
.Example
	Remove-SplunkInputScript -name '/Application/splunk/etc/apps/myApp/bin/myScript.sh' -ComputerName $serverlist	
	
	Removes the "/Application/splunk/etc/apps/myApp/bin/myScript.sh" scripted input from the servers contained in the $serverlist variable.	
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
<# .ExternalHelp ../Splunk-Help.xml #>
'@
sethelp = @'
<# .ExternalHelp ../Splunk-Help.xml #>
'@
	getExamples=@'
.Example
	Get-SplunkInputTCPCooked	
	
	Retrieves a list of all "cooked" TCP inputs from the default Splunk connection.	
	
.Example
	Get-SplunkInputTCPCooked -computername splunk6.server.com -name 27081	
	
	Retrieves information on the cooked TCP data input named "27081" on the server splunk6.server.com.	
'@
	removeExamples=@'
.Example
	Remove-SplunkInputTCPCooked	-name 65533 
	
	Prompts for the removal of an existing "cooked" TCP input for port 65533 from the default Splunk instance..	
	
.Example
	Remove-SplunkInputTCPCooked -name 65533 -ComputerName 192.168.1.250	
	
	Removes the "cooked" TCP data input named "65533" (representing TCP port 65533) from the Splunk instance at IP address 192.168.1.250.
	
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
<# .ExternalHelp ../Splunk-Help.xml #>
'@
sethelp = @'
<# .ExternalHelp ../Splunk-Help.xml #>
'@
	getExamples = @'
.Example
	Get-SplunkInputTCPRaw	
	
	Retrieves a list of all "raw" TCP inputs from the default Splunk connection.	
	
.Example
	Get-SplunkInputTCPRaw -computername splunk6.server.com -Filter 1	
	
	Retrieves information on all raw TCP data inputs whose names contain "1".	
'@
	removeExamples = @'
.Example	
	Get-SplunkInputTCPRaw -ComputerName Horus | Remove-SplunkInputTCPRaw	
	
	Prompts for the removal of all existing "raw" TCP input from the Horus server.	
	
.Example
	Remove-SplunkInputTCPRaw -name 23	
	
	Removes the "raw" TCP data input named "23" (representing the telnet port) on the default Splunk instance.
	
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
<# .ExternalHelp ../Splunk-Help.xml #>
'@

sethelp = @'
<# .ExternalHelp ../Splunk-Help.xml #>
'@
	getExamples=@'
.Example
	Get-SplunkInputUDP	
	
	Retrieves a list of all UDP data inputs from the default Splunk connection.	
	
.Example
	Get-SplunkInputUDP -ComputerName $gameserver -Count 10 -filter 100	
	
	Retrieves information on the first 10 UDP data inputs that contain or begin with "100" on servers listed in the $gameserver variable.	
'@

	removeExamples = @'
.Example
	Remove-SplunkInputUDP -name 514
	
	Prompts for the removal of a UDP input named "514" (representing the syslogd port) from the default Splunk instance.

.Example
	Remove-SplunkInputTCP -name 514 -ComputerName splunk15.server.com -port 7995	
	
	Removes the UDP data input named "514" (representing the syslogd port) on the Splunk instance at splunk15.server.com, port 7995.		
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
<# .ExternalHelp ../Splunk-Help.xml #>
'@

sethelp = @'
<# .ExternalHelp ../Splunk-Help.xml #>
'@
	getExamples = @'
.Example
	Get-SplunkInputWinWmiCollections	
	
	Retrieves a list of all Windows Management Instrumentation data inputs on the default Splunk instance.	
	
.Example
	Get-SplunkInputWinWmiCollections -computername splunk25.server.com -name SQLServer	
	
	Retrieves information on the WMI data input named "SQLServer" on the server splunk25.server.com.	
'@

	removeExamples =@'
.Example
	Get-SplunkInputWinPerfmon | Remove-SplunkInputWinPerfmon	
	
	Prompts for the removal of all existing Windows Performance Monitor inputs from the default Splunk instance.	
	
.Example
	Remove-SplunkInputWinPerfmon -name FreeDiskSpace -ComputerName splunk13.server.com -force	
	
	Forcibly removes the "FreeDiskSpace" Windows Performance Monitor input on splunk13.server.com.

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

#endregion Inputs

#region solidified
	function Get-SplunkInputWinPerfmon
	{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[CmdletBinding(DefaultParameterSetName='byFilter')]
    Param(
		[Parameter()]
		[int]
		#Indicates the maximum number of entries to return. To return all entries, specify 0. 
		$Count = 30,
		
		[Parameter()]
		[int]
		#Index for first item to return. 
		$Offset = 0,
		
		[Parameter()]
		[string]
		#Boolean predicate to filter results
		$Search,
		
		[Parameter(Position=0,ParameterSetName='byFilter')]
		[string]
		#Regular expression used to match index name
		$Filter = '.*',
		
		[Parameter(Position=0,ParameterSetName='byName',Mandatory=$true)]
		[string]
		#The name of the input to retrieve
		$Name,
		
		[Parameter()]
		[ValidateSet("asc","desc")]
		[string]
		#Indicates whether to sort the entries returned in ascending or descending order. Valid values: (asc | desc).  Defaults to asc.
		$SortDirection = "asc",
		
		[Parameter()]
		[ValidateSet("auto","alpha","alpha_case","num")]
		[string]
		#Indicates the collating sequence for sorting the returned entries. Valid values: (auto | alpha | alpha_case | num).  Defaults to auto.
		$SortMode = "auto",
		
		[Parameter()]
		[string]
		# Field to sort by.
		$SortKey,
		
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
	}
	Process 
	{
		Get-InputProxy @PSBoundParameters -InputType "WinPerfmon" -InputUrl "win-perfmon" -OutputFields @{
			integer = @('interval', 'disabled');
			boolean = @('');
		}
	}
	End
	{
	}
}
	function Get-SplunkInputRegistry
	{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[CmdletBinding(DefaultParameterSetName='byFilter')]
    Param(
		[Parameter()]
		[int]
		#Indicates the maximum number of entries to return. To return all entries, specify 0. 
		$Count = 30,
		
		[Parameter()]
		[int]
		#Index for first item to return. 
		$Offset = 0,
		
		[Parameter()]
		[string]
		#Boolean predicate to filter results
		$Search,
		
		[Parameter(Position=0,ParameterSetName='byFilter')]
		[string]
		#Regular expression used to match index name
		$Filter = '.*',
		
		[Parameter(Position=0,ParameterSetName='byName',Mandatory=$true)]
		[string]
		#The name of the input to retrieve
		$Name,
		
		[Parameter()]
		[ValidateSet("asc","desc")]
		[string]
		#Indicates whether to sort the entries returned in ascending or descending order. Valid values: (asc | desc).  Defaults to asc.
		$SortDirection = "asc",
		
		[Parameter()]
		[ValidateSet("auto","alpha","alpha_case","num")]
		[string]
		#Indicates the collating sequence for sorting the returned entries. Valid values: (auto | alpha | alpha_case | num).  Defaults to auto.
		$SortMode = "auto",
		
		[Parameter()]
		[string]
		# Field to sort by.
		$SortKey,
		
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
	}
	Process 
	{
		Get-InputProxy @PSBoundParameters -InputType Registry -OutputFields @{
			integer = @('baseline', 'disabled', 'monitorSubnodes');
			boolean = @('');
		}
	}
	End
	{
	}
}
	function Get-SplunkInputMonitor
	{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[CmdletBinding(DefaultParameterSetName='byFilter')]
    Param(
		[Parameter()]
		[int]
		#Indicates the maximum number of entries to return. To return all entries, specify 0. 
		$Count = 30,
		
		[Parameter()]
		[int]
		#Index for first item to return. 
		$Offset = 0,
		
		[Parameter()]
		[string]
		#Boolean predicate to filter results
		$Search,
		
		[Parameter(Position=0,ParameterSetName='byFilter')]
		[string]
		#Regular expression used to match index name
		$Filter = '.*',
		
		[Parameter(Position=0,ParameterSetName='byName',Mandatory=$true)]
		[string]
		#The name of the input to retrieve
		$Name,
		
		[Parameter()]
		[ValidateSet("asc","desc")]
		[string]
		#Indicates whether to sort the entries returned in ascending or descending order. Valid values: (asc | desc).  Defaults to asc.
		$SortDirection = "asc",
		
		[Parameter()]
		[ValidateSet("auto","alpha","alpha_case","num")]
		[string]
		#Indicates the collating sequence for sorting the returned entries. Valid values: (auto | alpha | alpha_case | num).  Defaults to auto.
		$SortMode = "auto",
		
		[Parameter()]
		[string]
		# Field to sort by.
		$SortKey,
		
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
	}
	Process 
	{
		Get-InputProxy @PSBoundParameters -InputType Monitor -OutputFields @{
			integer = @('host_segment', 'time-before-close');
			boolean = @('check-index', 'check-path', 'followTail', 'recursive');
		}
	}
	End
	{
	}
}
	function Get-SplunkInputWinEventLogCollections
	{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[CmdletBinding(DefaultParameterSetName='byFilter')]
    Param(
		[Parameter()]
		[int]
		#Indicates the maximum number of entries to return. To return all entries, specify 0. 
		$Count = 30,
		
		[Parameter()]
		[int]
		#Index for first item to return. 
		$Offset = 0,
		
		[Parameter()]
		[string]
		#Boolean predicate to filter results
		$Search,
		
		[Parameter(Position=0,ParameterSetName='byFilter')]
		[string]
		#Regular expression used to match index name
		$Filter = '.*',
		
		[Parameter(Position=0,ParameterSetName='byName',Mandatory=$true)]
		[string]
		#The name of the input to retrieve
		$Name,
		
		[Parameter()]
		[ValidateSet("asc","desc")]
		[string]
		#Indicates whether to sort the entries returned in ascending or descending order. Valid values: (asc | desc).  Defaults to asc.
		$SortDirection = "asc",
		
		[Parameter()]
		[ValidateSet("auto","alpha","alpha_case","num")]
		[string]
		#Indicates the collating sequence for sorting the returned entries. Valid values: (auto | alpha | alpha_case | num).  Defaults to auto.
		$SortMode = "auto",
		
		[Parameter()]
		[string]
		# Field to sort by.
		$SortKey,
		
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
	}
	Process 
	{
		Get-InputProxy @PSBoundParameters -InputType "WinEventLogCollections" -InputUrl 'win-event-log-collections' -OutputFields @{
			integer = @('');
			boolean = @('');
		}
	}
	End
	{
	}
}
	function Get-SplunkInputTCPCooked
	{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[CmdletBinding(DefaultParameterSetName='byFilter')]
    Param(
		[Parameter()]
		[int]
		#Indicates the maximum number of entries to return. To return all entries, specify 0. 
		$Count = 30,
		
		[Parameter()]
		[int]
		#Index for first item to return. 
		$Offset = 0,
		
		[Parameter()]
		[string]
		#Boolean predicate to filter results
		$Search,
		
		[Parameter(Position=0,ParameterSetName='byFilter')]
		[string]
		#Regular expression used to match index name
		$Filter = '.*',
		
		[Parameter(Position=0,ParameterSetName='byName',Mandatory=$true)]
		[string]
		#The name of the input to retrieve
		$Name,
		
		[Parameter()]
		[ValidateSet("asc","desc")]
		[string]
		#Indicates whether to sort the entries returned in ascending or descending order. Valid values: (asc | desc).  Defaults to asc.
		$SortDirection = "asc",
		
		[Parameter()]
		[ValidateSet("auto","alpha","alpha_case","num")]
		[string]
		#Indicates the collating sequence for sorting the returned entries. Valid values: (auto | alpha | alpha_case | num).  Defaults to auto.
		$SortMode = "auto",
		
		[Parameter()]
		[string]
		# Field to sort by.
		$SortKey,
		
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
	}
	Process 
	{
		Get-InputProxy @PSBoundParameters -InputType TCPCooked -inputUrl 'tcp/cooked' -OutputFields @{
			integer = @('name');
			boolean = @('SSL', 'disabled');
		}
	}
	End
	{
	}
}
	function Get-SplunkInputTCPRaw
	{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[CmdletBinding(DefaultParameterSetName='byFilter')]
    Param(
		[Parameter()]
		[int]
		#Indicates the maximum number of entries to return. To return all entries, specify 0. 
		$Count = 30,
		
		[Parameter()]
		[int]
		#Index for first item to return. 
		$Offset = 0,
		
		[Parameter()]
		[string]
		#Boolean predicate to filter results
		$Search,
		
		[Parameter(Position=0,ParameterSetName='byFilter')]
		[string]
		#Regular expression used to match index name
		$Filter = '.*',
		
		[Parameter(Position=0,ParameterSetName='byName',Mandatory=$true)]
		[string]
		#The name of the input to retrieve
		$Name,
		
		[Parameter()]
		[ValidateSet("asc","desc")]
		[string]
		#Indicates whether to sort the entries returned in ascending or descending order. Valid values: (asc | desc).  Defaults to asc.
		$SortDirection = "asc",
		
		[Parameter()]
		[ValidateSet("auto","alpha","alpha_case","num")]
		[string]
		#Indicates the collating sequence for sorting the returned entries. Valid values: (auto | alpha | alpha_case | num).  Defaults to auto.
		$SortMode = "auto",
		
		[Parameter()]
		[string]
		# Field to sort by.
		$SortKey,
		
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
	}
	Process 
	{
		Get-InputProxy @PSBoundParameters -InputType TCPRaw -inputUrl 'tcp/raw' -OutputFields @{
			integer = @('');
			boolean = @('SSL', 'disabled');
		}
	}
	End
	{
	}
}
	function Get-SplunkInputUDP
	{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[CmdletBinding(DefaultParameterSetName='byFilter')]
    Param(
		[Parameter()]
		[int]
		#Indicates the maximum number of entries to return. To return all entries, specify 0. 
		$Count = 30,
		
		[Parameter()]
		[int]
		#Index for first item to return. 
		$Offset = 0,
		
		[Parameter()]
		[string]
		#Boolean predicate to filter results
		$Search,
		
		[Parameter(Position=0,ParameterSetName='byFilter')]
		[string]
		#Regular expression used to match index name
		$Filter = '.*',
		
		[Parameter(Position=0,ParameterSetName='byName',Mandatory=$true)]
		[string]
		#The name of the input to retrieve
		$Name,
		
		[Parameter()]
		[ValidateSet("asc","desc")]
		[string]
		#Indicates whether to sort the entries returned in ascending or descending order. Valid values: (asc | desc).  Defaults to asc.
		$SortDirection = "asc",
		
		[Parameter()]
		[ValidateSet("auto","alpha","alpha_case","num")]
		[string]
		#Indicates the collating sequence for sorting the returned entries. Valid values: (auto | alpha | alpha_case | num).  Defaults to auto.
		$SortMode = "auto",
		
		[Parameter()]
		[string]
		# Field to sort by.
		$SortKey,
		
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
	}
	Process 
	{
		Get-InputProxy @PSBoundParameters -InputType UDP -OutputFields @{
			integer = @('');
			boolean = @('no_appending_timestamp', 'no_priority_stripping');
		}
	}
	End
	{
	}
}
	function Get-SplunkInputScript
	{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[CmdletBinding(DefaultParameterSetName='byFilter')]
    Param(
		[Parameter()]
		[int]
		#Indicates the maximum number of entries to return. To return all entries, specify 0. 
		$Count = 30,
		
		[Parameter()]
		[int]
		#Index for first item to return. 
		$Offset = 0,
		
		[Parameter()]
		[string]
		#Boolean predicate to filter results
		$Search,
		
		[Parameter(Position=0,ParameterSetName='byFilter')]
		[string]
		#Regular expression used to match index name
		$Filter = '.*',
		
		[Parameter(Position=0,ParameterSetName='byName',Mandatory=$true)]
		[string]
		#The name of the input to retrieve
		$Name,
		
		[Parameter()]
		[ValidateSet("asc","desc")]
		[string]
		#Indicates whether to sort the entries returned in ascending or descending order. Valid values: (asc | desc).  Defaults to asc.
		$SortDirection = "asc",
		
		[Parameter()]
		[ValidateSet("auto","alpha","alpha_case","num")]
		[string]
		#Indicates the collating sequence for sorting the returned entries. Valid values: (auto | alpha | alpha_case | num).  Defaults to auto.
		$SortMode = "auto",
		
		[Parameter()]
		[string]
		# Field to sort by.
		$SortKey,
		
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
	}
	Process 
	{
		Get-InputProxy @PSBoundParameters -InputType Script -OutputFields @{
			integer = @('interval');
			boolean = @('disabled');
		}
	}
	End
	{
	}
}
	function Get-SplunkInputAd
	{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[CmdletBinding(DefaultParameterSetName='byFilter')]
    Param(
		[Parameter()]
		[int]
		#Indicates the maximum number of entries to return. To return all entries, specify 0. 
		$Count = 30,
		
		[Parameter()]
		[int]
		#Index for first item to return. 
		$Offset = 0,
		
		[Parameter()]
		[string]
		#Boolean predicate to filter results
		$Search,
		
		[Parameter(Position=0,ParameterSetName='byFilter')]
		[string]
		#Regular expression used to match index name
		$Filter = '.*',
		
		[Parameter(Position=0,ParameterSetName='byName',Mandatory=$true)]
		[string]
		#The name of the input to retrieve
		$Name,
		
		[Parameter()]
		[ValidateSet("asc","desc")]
		[string]
		#Indicates whether to sort the entries returned in ascending or descending order. Valid values: (asc | desc).  Defaults to asc.
		$SortDirection = "asc",
		
		[Parameter()]
		[ValidateSet("auto","alpha","alpha_case","num")]
		[string]
		#Indicates the collating sequence for sorting the returned entries. Valid values: (auto | alpha | alpha_case | num).  Defaults to auto.
		$SortMode = "auto",
		
		[Parameter()]
		[string]
		# Field to sort by.
		$SortKey,
		
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
	}
	Process 
	{
		Get-InputProxy @PSBoundParameters -InputType Ad -OutputFields @{
			integer = @('monitorSubtree', 'disabled');
			boolean = @('');
		}
	}
	End
	{
	}
}
	function Get-SplunkInputOneShot
	{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[CmdletBinding(DefaultParameterSetName='byFilter')]
    Param(
		[Parameter()]
		[int]
		#Indicates the maximum number of entries to return. To return all entries, specify 0. 
		$Count = 30,
		
		[Parameter()]
		[int]
		#Index for first item to return. 
		$Offset = 0,
		
		[Parameter()]
		[string]
		#Boolean predicate to filter results
		$Search,
		
		[Parameter(Position=0,ParameterSetName='byFilter')]
		[string]
		#Regular expression used to match index name
		$Filter = '.*',
		
		[Parameter(Position=0,ParameterSetName='byName',Mandatory=$true)]
		[string]
		#The name of the input to retrieve
		$Name,
		
		[Parameter()]
		[ValidateSet("asc","desc")]
		[string]
		#Indicates whether to sort the entries returned in ascending or descending order. Valid values: (asc | desc).  Defaults to asc.
		$SortDirection = "asc",
		
		[Parameter()]
		[ValidateSet("auto","alpha","alpha_case","num")]
		[string]
		#Indicates the collating sequence for sorting the returned entries. Valid values: (auto | alpha | alpha_case | num).  Defaults to auto.
		$SortMode = "auto",
		
		[Parameter()]
		[string]
		# Field to sort by.
		$SortKey,
		
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
	}
	Process 
	{
		Get-InputProxy @PSBoundParameters -InputType OneShot -OutputFields @{
			integer = @('host_segment');
			boolean = @('');
		}
	}
	End
	{
	}
}
	function Get-SplunkInputWinWmiCollections
	{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[CmdletBinding(DefaultParameterSetName='byFilter')]
    Param(
		[Parameter()]
		[int]
		#Indicates the maximum number of entries to return. To return all entries, specify 0. 
		$Count = 30,
		
		[Parameter()]
		[int]
		#Index for first item to return. 
		$Offset = 0,
		
		[Parameter()]
		[string]
		#Boolean predicate to filter results
		$Search,
		
		[Parameter(Position=0,ParameterSetName='byFilter')]
		[string]
		#Regular expression used to match index name
		$Filter = '.*',
		
		[Parameter(Position=0,ParameterSetName='byName',Mandatory=$true)]
		[string]
		#The name of the input to retrieve
		$Name,
		
		[Parameter()]
		[ValidateSet("asc","desc")]
		[string]
		#Indicates whether to sort the entries returned in ascending or descending order. Valid values: (asc | desc).  Defaults to asc.
		$SortDirection = "asc",
		
		[Parameter()]
		[ValidateSet("auto","alpha","alpha_case","num")]
		[string]
		#Indicates the collating sequence for sorting the returned entries. Valid values: (auto | alpha | alpha_case | num).  Defaults to auto.
		$SortMode = "auto",
		
		[Parameter()]
		[string]
		# Field to sort by.
		$SortKey,
		
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
	}
	Process 
	{
		Get-InputProxy @PSBoundParameters -InputType WinWmiCollections -inputUrl 'win-wmi-collections' -OutputFields @{
			integer = @('interval', 'disabled');
			boolean = @('');
		}
	}
	End
	{
	}
}
function Remove-SplunkInputWinPerfmon
{
	<# .ExternalHelp ../Splunk-Help.xml #>

	[CmdletBinding(DefaultParameterSetName='byFilter')]
    Param(
		[Parameter(ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
		[string]
		# The name of the input to remove.
		$Name,
		
		[Parameter()]
		[switch]
		# Specify to bypass standard PowerShell confirmation
		$Force,
		
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]
        # Name of the Splunk instance (Default is ( get-splunkconnectionobject ).ComputerName.)
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
	}
	Process 
	{
		$PSBoundParameters.Keys | foreach{
			Write-Verbose " [Remove-SplunkInput$functionTag] ::  - $_ = $($PSBoundParameters[$_])"		
		}

		Remove-InputProxy @PSBoundParameters -InputType WinPerfmon -inputUrl 'win-perfmon' -OutputFields @{
			integer = @('interval', 'disabled');
			boolean = @('');
		}
	}
	End
	{
	}
}
function Remove-SplunkInputRegistry
{
	<# .ExternalHelp ../Splunk-Help.xml #>

	[CmdletBinding(DefaultParameterSetName='byFilter')]
    Param(
		[Parameter(ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
		[string]
		# The name of the input to remove.
		$Name,
		
		[Parameter()]
		[switch]
		# Specify to bypass standard PowerShell confirmation
		$Force,
		
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]
        # Name of the Splunk instance (Default is ( get-splunkconnectionobject ).ComputerName.)
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
	}
	Process 
	{
		$PSBoundParameters.Keys | foreach{
			Write-Verbose " [Remove-SplunkInput$functionTag] ::  - $_ = $($PSBoundParameters[$_])"		
		}

		Remove-InputProxy @PSBoundParameters -InputType Registry -OutputFields @{
			integer = @('baseline', 'disabled', 'monitorSubnodes');
			boolean = @('');
		}
	}
	End
	{
	}
}
function Remove-SplunkInputMonitor
{
	<# .ExternalHelp ../Splunk-Help.xml #>

	[CmdletBinding(DefaultParameterSetName='byFilter')]
    Param(
		[Parameter(ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
		[string]
		# The name of the input to remove.
		$Name,
		
		[Parameter()]
		[switch]
		# Specify to bypass standard PowerShell confirmation
		$Force,
		
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]
        # Name of the Splunk instance (Default is ( get-splunkconnectionobject ).ComputerName.)
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
	}
	Process 
	{
		$PSBoundParameters.Keys | foreach{
			Write-Verbose " [Remove-SplunkInput$functionTag] ::  - $_ = $($PSBoundParameters[$_])"		
		}

		Remove-InputProxy @PSBoundParameters -InputType Monitor -OutputFields @{
			integer = @('host_segment', 'time-before-close');
			boolean = @('check-index', 'check-path', 'followTail', 'recursive');
		}
	}
	End
	{
	}
}
function Remove-SplunkInputWinEventLogCollections
{
	<# .ExternalHelp ../Splunk-Help.xml #>

	[CmdletBinding(DefaultParameterSetName='byFilter')]
    Param(
		[Parameter(ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
		[string]
		# The name of the input to remove.
		$Name,
		
		[Parameter()]
		[switch]
		# Specify to bypass standard PowerShell confirmation
		$Force,
		
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]
        # Name of the Splunk instance (Default is ( get-splunkconnectionobject ).ComputerName.)
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
	}
	Process 
	{
		$PSBoundParameters.Keys | foreach{
			Write-Verbose " [Remove-SplunkInput$functionTag] ::  - $_ = $($PSBoundParameters[$_])"		
		}

		Remove-InputProxy @PSBoundParameters -InputType WinEventLogCollections -inputUrl 'win-event-log-collections' -OutputFields @{
			integer = @('');
			boolean = @('');
		}
	}
	End
	{
	}
}
function Remove-SplunkInputTCPCooked
{
	<# .ExternalHelp ../Splunk-Help.xml #>

	[CmdletBinding(DefaultParameterSetName='byFilter')]
    Param(
		[Parameter(ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
		[string]
		# The name of the input to remove.
		$Name,
		
		[Parameter()]
		[switch]
		# Specify to bypass standard PowerShell confirmation
		$Force,
		
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]
        # Name of the Splunk instance (Default is ( get-splunkconnectionobject ).ComputerName.)
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
	}
	Process 
	{
		$PSBoundParameters.Keys | foreach{
			Write-Verbose " [Remove-SplunkInput$functionTag] ::  - $_ = $($PSBoundParameters[$_])"		
		}

		Remove-InputProxy @PSBoundParameters -InputType TCPCooked -inputUrl 'tcp/cooked' -OutputFields @{
			integer = @('name');
			boolean = @('SSL', 'disabled');
		}
	}
	End
	{
	}
}
function Remove-SplunkInputTCPRaw
{
	<# .ExternalHelp ../Splunk-Help.xml #>

	[CmdletBinding(DefaultParameterSetName='byFilter')]
    Param(
		[Parameter(ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
		[string]
		# The name of the input to remove.
		$Name,
		
		[Parameter()]
		[switch]
		# Specify to bypass standard PowerShell confirmation
		$Force,
		
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]
        # Name of the Splunk instance (Default is ( get-splunkconnectionobject ).ComputerName.)
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
	}
	Process 
	{
		$PSBoundParameters.Keys | foreach{
			Write-Verbose " [Remove-SplunkInput$functionTag] ::  - $_ = $($PSBoundParameters[$_])"		
		}

		Remove-InputProxy @PSBoundParameters -InputType TCPRaw -OutputFields @{
			integer = @('');
			boolean = @('SSL', 'disabled');
		}
	}
	End
	{
	}
}
function Remove-SplunkInputUDP
{
	<# .ExternalHelp ../Splunk-Help.xml #>

	[CmdletBinding(DefaultParameterSetName='byFilter')]
    Param(
		[Parameter(ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
		[string]
		# The name of the input to remove.
		$Name,
		
		[Parameter()]
		[switch]
		# Specify to bypass standard PowerShell confirmation
		$Force,
		
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]
        # Name of the Splunk instance (Default is ( get-splunkconnectionobject ).ComputerName.)
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
	}
	Process 
	{
		$PSBoundParameters.Keys | foreach{
			Write-Verbose " [Remove-SplunkInput$functionTag] ::  - $_ = $($PSBoundParameters[$_])"		
		}

		Remove-InputProxy @PSBoundParameters -InputType UDP -OutputFields @{
			integer = @('');
			boolean = @('no_appending_timestamp', 'no_priority_stripping');
		}
	}
	End
	{
	}
}
function Remove-SplunkInputScript
{
	<# .ExternalHelp ../Splunk-Help.xml #>

	[CmdletBinding(DefaultParameterSetName='byFilter')]
    Param(
		[Parameter(ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
		[string]
		# The name of the input to remove.
		$Name,
		
		[Parameter()]
		[switch]
		# Specify to bypass standard PowerShell confirmation
		$Force,
		
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]
        # Name of the Splunk instance (Default is ( get-splunkconnectionobject ).ComputerName.)
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
	}
	Process 
	{
		$PSBoundParameters.Keys | foreach{
			Write-Verbose " [Remove-SplunkInput$functionTag] ::  - $_ = $($PSBoundParameters[$_])"		
		}

		Remove-InputProxy @PSBoundParameters -InputType Script -OutputFields @{
			integer = @('interval');
			boolean = @('disabled');
		}
	}
	End
	{
	}
}
function Remove-SplunkInputAd
{
	<# .ExternalHelp ../Splunk-Help.xml #>

	[CmdletBinding(DefaultParameterSetName='byFilter')]
    Param(
		[Parameter(ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
		[string]
		# The name of the input to remove.
		$Name,
		
		[Parameter()]
		[switch]
		# Specify to bypass standard PowerShell confirmation
		$Force,
		
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]
        # Name of the Splunk instance (Default is ( get-splunkconnectionobject ).ComputerName.)
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
	}
	Process 
	{
		$PSBoundParameters.Keys | foreach{
			Write-Verbose " [Remove-SplunkInput$functionTag] ::  - $_ = $($PSBoundParameters[$_])"		
		}

		Remove-InputProxy @PSBoundParameters -InputType Ad -OutputFields @{
			integer = @('monitorSubtree', 'disabled');
			boolean = @('');
		}
	}
	End
	{
	}
}
function Remove-SplunkInputOneShot
{
	<# .ExternalHelp ../Splunk-Help.xml #>

	[CmdletBinding(DefaultParameterSetName='byFilter')]
    Param(
		[Parameter(ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
		[string]
		# The name of the input to remove.
		$Name,
		
		[Parameter()]
		[switch]
		# Specify to bypass standard PowerShell confirmation
		$Force,
		
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]
        # Name of the Splunk instance (Default is ( get-splunkconnectionobject ).ComputerName.)
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
	}
	Process 
	{
		$PSBoundParameters.Keys | foreach{
			Write-Verbose " [Remove-SplunkInput$functionTag] ::  - $_ = $($PSBoundParameters[$_])"		
		}

		Remove-InputProxy @PSBoundParameters -InputType OneShot -OutputFields @{
			integer = @('host_segment');
			boolean = @('');
		}
	}
	End
	{
	}
}
function Remove-SplunkInputWinWmiCollections
{
	<# .ExternalHelp ../Splunk-Help.xml #>

	[CmdletBinding(DefaultParameterSetName='byFilter')]
    Param(
		[Parameter(ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
		[string]
		# The name of the input to remove.
		$Name,
		
		[Parameter()]
		[switch]
		# Specify to bypass standard PowerShell confirmation
		$Force,
		
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]
        # Name of the Splunk instance (Default is ( get-splunkconnectionobject ).ComputerName.)
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
	}
	Process 
	{
		$PSBoundParameters.Keys | foreach{
			Write-Verbose " [Remove-SplunkInput$functionTag] ::  - $_ = $($PSBoundParameters[$_])"		
		}

		Remove-InputProxy @PSBoundParameters -InputType WinWmiCollections -inputUrl 'win-wmi-collections' -OutputFields @{
			integer = @('interval', 'disabled');
			boolean = @('');
		}
	}
	End
	{
	}
}
	function Set-SplunkInputWinPerfmon
	{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[CmdletBinding(SupportsShouldProcess=$true)]
    Param(
		[Parameter()]
[string[]]
#A list of all counters to monitor. A * is equivalent to all counters.
$counters,
[Parameter()]
[int]
#Disables a given monitoring stanza.
$disabled,
[Parameter()]
[string]
#The index in which to store the gathered data.
$index,
[Parameter()]
[string[]]
#A list of counter instances.  A * is equivalent to all instances.
$instances,
[Parameter()]
[int]
#How frequently to poll the performance counters.
$interval,
[Parameter()]
[string]
#A valid performance monitor object (for example, "Process," "Server," "PhysicalDisk.")
$object,
		
		[Parameter(ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
        [String]
		# The name of the input to update.
		$Name,
		
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
	}
	Process 
	{
		write-debug "Tag: WinPerfmon; InputType: win-perfmon";
		$psb = @{};
		$PSBoundParameters.Keys | foreach{ $psb[$_] = $PSBoundParameters[$_] };
		$setParameters = $inputs['win-perfmon'].setParameters;
		$newParameters = $inputs['win-perfmon'].newParameters;
		$setParameters | foreach { 
			$sp = $_;
			$key = $_.powershellname;
			$np = $newParameters | where {$_.powershellname -eq $key };
			write-debug "Removing bound parameter $key"; 

			#copy inherited property values from new-parameter set
			$u = @{};
			$_.keys | where {$sp[$_] -match 'Inherited' } | foreach {
				
				write-debug "inheriting set parameter value for key $_";
				$u[$_] = $np[$_];
			}
			$u.keys | foreach { $sp[$_] = $u[$_] };

			$_.value = $PSBoundParameters[$key]; 
			
			if( $_.value -is [array] )
			{
				$_.value = $_.value -join ',';
			}
			
			$psb.Remove($key) | out-null;
			
			write-debug "set parameter key [$key] value [$($_.value)]";
		}

		write-debug "Integer fields: interval disabled"
		write-debug "Boolean fields: "
		
		Set-InputProxy @psb -InputType WinPerfmon -inputUrl 'win-perfmon' -SetParameters $setParameters -OutputFields @{
			integer = @('interval', 'disabled');
			boolean = @('');
		}
	}
	End
	{
	}
}
	function Set-SplunkInputRegistry
	{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[CmdletBinding(SupportsShouldProcess=$true)]
    Param(
		[Parameter()]
[int]
#Specifies whether or not to establish a baseline value for the registry keys.  1 means yes, 0 no.
$baseline,
[Parameter()]
[string]
#Specifies the registry hive under which to monitor for changes.
$hive,
[Parameter()]
[string]
#Specifies a regex.  If specified, will only collected changes if a process name matches that regex.
$proc,
[Parameter()]
[string]
#A regular expression that specifies the type(s) of Registry event(s) that you want to monitor.
$type,
[Parameter()]
[int]
#Indicates whether the monitoring is disabled.
$disabled,
[Parameter()]
[string]
#The index in which to store the gathered data.
$index,
[Parameter()]
[int]
#If set to 1, will monitor all sub-nodes under a given hive.
$monitorSubnodes,
		
		[Parameter(ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
        [String]
		# The name of the input to update.
		$Name,
		
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
	}
	Process 
	{
		write-debug "Tag: Registry; InputType: Registry";
		$psb = @{};
		$PSBoundParameters.Keys | foreach{ $psb[$_] = $PSBoundParameters[$_] };
		$setParameters = $inputs['Registry'].setParameters;
		$newParameters = $inputs['Registry'].newParameters;
		$setParameters | foreach { 
			$sp = $_;
			$key = $_.powershellname;
			$np = $newParameters | where {$_.powershellname -eq $key };
			write-debug "Removing bound parameter $key"; 

			#copy inherited property values from new-parameter set
			$u = @{};
			$_.keys | where {$sp[$_] -match 'Inherited' } | foreach {
				
				write-debug "inheriting set parameter value for key $_";
				$u[$_] = $np[$_];
			}
			$u.keys | foreach { $sp[$_] = $u[$_] };

			$_.value = $PSBoundParameters[$key]; 
			
			if( $_.value -is [array] )
			{
				$_.value = $_.value -join ',';
			}
			
			$psb.Remove($key) | out-null;
			
			write-debug "set parameter key [$key] value [$($_.value)]";
		}

		write-debug "Integer fields: baseline disabled monitorSubnodes"
		write-debug "Boolean fields: "
		
		Set-InputProxy @psb -InputType Registry -SetParameters $setParameters -OutputFields @{
			integer = @('baseline', 'disabled', 'monitorSubnodes');
			boolean = @('');
		}
	}
	End
	{
	}
}
	function Set-SplunkInputMonitor
	{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[CmdletBinding(SupportsShouldProcess=$true)]
    Param(
		[Parameter()]
[string]
#Specify a regular expression for a file path. The file path that matches this regular expression is not indexed.
$blacklist,
[Parameter()]
[switch]
#If set to true, the "index" value will be checked to ensure that it is the name of a valid index.
$checkindex,
[Parameter()]
[switch]
#If set to true, the "name" value will be checked to ensure that it exists.
$checkpath,
[Parameter()]
[string]
#A string that modifies the file tracking identity for files in this input.  The magic value "<SOURCE>" invokes special behavior (see admin documentation).
$crcsalt,
[Parameter()]
[switch]
#If set to true, files that are seen for the first time will be read from the end.
$followTail,
[Parameter()]
[string]
#The value to populate in the host field for events from this data input.
$host,
[Parameter()]
[string]
#Specify a regular expression for a file path. If the path for a file matches this regular expression, the captured value is used to populate the host field for events from this data input.  The regular expression must have one capture group.
$hostregex,
[Parameter()]
[int]
#Use the specified slash-separate segment of the filepath as the host field value.
$hostsegment,
[Parameter()]
[string]
#Specify a time value. If the modification time of a file being monitored falls outside of this rolling time window, the file is no longer being monitored.
$ignoreolderthan,
[Parameter()]
[string]
#Which index events from this input should be stored in.
$index,
[Parameter()]
[switch]
#Setting this to "false" will prevent monitoring of any subdirectories encountered within this data input.
$recursive,
[Parameter()]
[string]
#The value to populate in the source field for events from this data input.  The same source should not be used for multiple data inputs.
$renamesource,
[Parameter()]
[string]
#The value to populate in the sourcetype field for incoming events.
$sourcetype,
[Parameter()]
[int]
#When Splunk reaches the end of a file that is being read, the file will be kept open for a minimum of the number of seconds specified in this value.  After this period has elapsed, the file will be checked again for more data.
$timebeforeclose,
[Parameter()]
[string]
#Specify a regular expression for a file path. Only file paths that match this regular expression are indexed.
$whitelist,
		
		[Parameter(ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
        [String]
		# The name of the input to update.
		$Name,
		
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
	}
	Process 
	{
		write-debug "Tag: Monitor; InputType: Monitor";
		$psb = @{};
		$PSBoundParameters.Keys | foreach{ $psb[$_] = $PSBoundParameters[$_] };
		$setParameters = $inputs['Monitor'].setParameters;
		$newParameters = $inputs['Monitor'].newParameters;
		$setParameters | foreach { 
			$sp = $_;
			$key = $_.powershellname;
			$np = $newParameters | where {$_.powershellname -eq $key };
			write-debug "Removing bound parameter $key"; 

			#copy inherited property values from new-parameter set
			$u = @{};
			$_.keys | where {$sp[$_] -match 'Inherited' } | foreach {
				
				write-debug "inheriting set parameter value for key $_";
				$u[$_] = $np[$_];
			}
			$u.keys | foreach { $sp[$_] = $u[$_] };

			$_.value = $PSBoundParameters[$key]; 
			
			if( $_.value -is [array] )
			{
				$_.value = $_.value -join ',';
			}
			
			$psb.Remove($key) | out-null;
			
			write-debug "set parameter key [$key] value [$($_.value)]";
		}

		write-debug "Integer fields: host_segment time-before-close"
		write-debug "Boolean fields: check-index check-path followTail recursive"
		
		Set-InputProxy @psb -InputType Monitor -SetParameters $setParameters -OutputFields @{
			integer = @('host_segment', 'time-before-close');
			boolean = @('check-index', 'check-path', 'followTail', 'recursive');
		}
	}
	End
	{
	}
}
	function Set-SplunkInputWinEventLogCollections
	{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[CmdletBinding(SupportsShouldProcess=$true)]
    Param(
		[Parameter()]
[string]
#This is a host from which we will monitor log events.  To specify additional hosts to be monitored via WMI, use the "hosts" parameter.
$lookuphost,
[Parameter()]
[string[]]
#A list of addtional hosts to be used for monitoring.  The first host should be specified with "lookup_host", and the additional ones using this parameter.
$hosts,
[Parameter()]
[string]
#The index in which to store the gathered data.
$index,
[Parameter()]
[string[]]
#A list of event log names to gather data from.
$logs,
		
		[Parameter(ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
        [String]
		# The name of the input to update.
		$Name,
		
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
	}
	Process 
	{
		write-debug "Tag: WinEventLogCollections; InputType: win-event-log-collections";
		$psb = @{};
		$PSBoundParameters.Keys | foreach{ $psb[$_] = $PSBoundParameters[$_] };
		$setParameters = $inputs['win-event-log-collections'].setParameters;
		$newParameters = $inputs['win-event-log-collections'].newParameters;
		$setParameters | foreach { 
			$sp = $_;
			$key = $_.powershellname;
			$np = $newParameters | where {$_.powershellname -eq $key };
			write-debug "Removing bound parameter $key"; 

			#copy inherited property values from new-parameter set
			$u = @{};
			$_.keys | where {$sp[$_] -match 'Inherited' } | foreach {
				
				write-debug "inheriting set parameter value for key $_";
				$u[$_] = $np[$_];
			}
			$u.keys | foreach { $sp[$_] = $u[$_] };

			$_.value = $PSBoundParameters[$key]; 
			
			if( $_.value -is [array] )
			{
				$_.value = $_.value -join ',';
			}
			
			$psb.Remove($key) | out-null;
			
			write-debug "set parameter key [$key] value [$($_.value)]";
		}

		write-debug "Integer fields: "
		write-debug "Boolean fields: "
		
		Set-InputProxy @psb -InputType WinEventLogCollections -inputUrl 'win-event-log-collections' -SetParameters $setParameters -OutputFields @{
			integer = @('');
			boolean = @('');
		}
	}
	End
	{
	}
}
	function Set-SplunkInputTCPCooked
	{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[CmdletBinding(SupportsShouldProcess=$true)]
    Param(
		[Parameter()]
[switch]
#If SSL is not already configured, error is returned
$SSL,
[Parameter()]
[string]
#Valid values: (ip | dns | none).  Set the host for the remote server that is sending data.  ip sets the host to the IP address of the remote server sending data. dns sets the host to the reverse DNS entry for the IP address of the remote server sending data. none leaves the host as specified in inputs.conf.  Default value is dns. 
$connectionhost,
[Parameter()]
[switch]
#Indicates whether the input is disabled.
$disabled,
[Parameter()]
[string]
#The default value to fill in for events lacking a host value.
$host,
[Parameter()]
[string]
#Restrict incoming connections on this port to the host specified here.
$restrictToHost,
		
		[Parameter(ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
        [String]
		# The name of the input to update.
		$Name,
		
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
	}
	Process 
	{
		write-debug "Tag: TCPCooked; InputType: TCP/Cooked";
		$psb = @{};
		$PSBoundParameters.Keys | foreach{ $psb[$_] = $PSBoundParameters[$_] };
		$setParameters = $inputs['TCP/Cooked'].setParameters;
		$newParameters = $inputs['TCP/Cooked'].newParameters;
		$setParameters | foreach { 
			$sp = $_;
			$key = $_.powershellname;
			$np = $newParameters | where {$_.powershellname -eq $key };
			write-debug "Removing bound parameter $key"; 

			#copy inherited property values from new-parameter set
			$u = @{};
			$_.keys | where {$sp[$_] -match 'Inherited' } | foreach {
				
				write-debug "inheriting set parameter value for key $_";
				$u[$_] = $np[$_];
			}
			$u.keys | foreach { $sp[$_] = $u[$_] };

			$_.value = $PSBoundParameters[$key]; 
			
			if( $_.value -is [array] )
			{
				$_.value = $_.value -join ',';
			}
			
			$psb.Remove($key) | out-null;
			
			write-debug "set parameter key [$key] value [$($_.value)]";
		}

		write-debug "Integer fields: name"
		write-debug "Boolean fields: SSL disabled"
		
		Set-InputProxy @psb -InputType TCPCooked -inputUrl 'tcp/cooked' -SetParameters $setParameters -OutputFields @{
			integer = @('name');
			boolean = @('SSL', 'disabled');
		}
	}
	End
	{
	}
}
	function Set-SplunkInputTCPRaw
	{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[CmdletBinding(SupportsShouldProcess=$true)]
    Param(
		[Parameter()]
[switch]
#	If SSL is not already configured, error is returned 
$SSL,
[Parameter()]
[string]
#Valid values: (ip | dns | none).  Specify the remote server that is the connection host.  ip: specifies the IP address of the remote server.  dns: sets the host to the DNS entry of the remote server.  none: leaves the host as specified.
$connectionhost,
[Parameter()]
[switch]
#Indicates whether the inputs are disabled.
$disabled,
[Parameter()]
[string]
#The host from which the indexer gets data.
$host,
[Parameter()]
[string]
#The index in which to store all generated events.
$index,
[Parameter()]
[string]
#Valid values: (parsingQueue | indexQueue).  Specifies where the input processor should deposit the events it reads. Defaults to parsingQueue.  Set queue to parsingQueue to apply props.conf and other parsing rules to your data. For more information about props.conf and rules for timestamping and linebreaking, refer to props.conf and the online documentation at Edit inputs.conf.  Set queue to indexQueue to send your data directly into the index.
$queue,
[Parameter()]
[string]
#Allows for restricting this input to only accept data from the host specified here.
$restrictToHost,
[Parameter()]
[string]
#Sets the source key/field for events from this input. Defaults to the input file path.  Sets the source key initial value. The key is used during parsing/indexing, in particular to set the source field during indexing. It is also the source field used at search time. As a convenience, the chosen string is prepended with "source::".  Note: Overriding the source key is generally not recommended.Typically, the input layer provides a more accurate string to aid in problem analysis and investigation, accurately recording the file from which the data was retreived. Consider use of source types, tagging, and search wildcards before overriding this value.
$source,
[Parameter()]
[string]
#Set the source type for events from this input.  "sourcetype=" is automatically prepended to <string>.  Defaults to audittrail (if signedaudit=true) or fschange (if signedaudit=false).
$sourcetype,
		
		[Parameter(ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
        [String]
		# The name of the input to update.
		$Name,
		
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
	}
	Process 
	{
		write-debug "Tag: TCPRaw; InputType: TCP/Raw";
		$psb = @{};
		$PSBoundParameters.Keys | foreach{ $psb[$_] = $PSBoundParameters[$_] };
		$setParameters = $inputs['TCP/Raw'].setParameters;
		$newParameters = $inputs['TCP/Raw'].newParameters;
		$setParameters | foreach { 
			$sp = $_;
			$key = $_.powershellname;
			$np = $newParameters | where {$_.powershellname -eq $key };
			write-debug "Removing bound parameter $key"; 

			#copy inherited property values from new-parameter set
			$u = @{};
			$_.keys | where {$sp[$_] -match 'Inherited' } | foreach {
				
				write-debug "inheriting set parameter value for key $_";
				$u[$_] = $np[$_];
			}
			$u.keys | foreach { $sp[$_] = $u[$_] };

			$_.value = $PSBoundParameters[$key]; 
			
			if( $_.value -is [array] )
			{
				$_.value = $_.value -join ',';
			}
			
			$psb.Remove($key) | out-null;
			
			write-debug "set parameter key [$key] value [$($_.value)]";
		}

		write-debug "Integer fields: "
		write-debug "Boolean fields: SSL disabled"
		
		Set-InputProxy @psb -InputType TCPRaw -inputUrl 'tcp/raw' -SetParameters $setParameters -OutputFields @{
			integer = @('');
			boolean = @('SSL', 'disabled');
		}
	}
	End
	{
	}
}
	function Set-SplunkInputUDP
	{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[CmdletBinding(SupportsShouldProcess=$true)]
    Param(
		[Parameter()]
[string]
#Valid values: (ip | dns | none).  ip: The host field for incoming events is set to the IP address of the remote server.  dns: The host field is set to the DNS entry of the remote server.  none: The host field remains unchanged.  Defaults to ip.
$connectionhost,
[Parameter()]
[string]
#The value to populate in the host field for incoming events.
$host,
[Parameter()]
[string]
#Which index events from this input should be stored in.
$index,
[Parameter()]
[switch]
#If set to true, prevents Splunk from prepending a timestamp and hostname to incoming events.
$noappendingtimestamp,
[Parameter()]
[switch]
#If set to true, Splunk will not remove the priority field from incoming syslog events.
$noprioritystripping,
[Parameter()]
[string]
#Which queue events from this input should be sent to.  Generally this does not need to be changed.
$queue,
[Parameter()]
[string]
#The value to populate in the source field for incoming events.  The same source should not be used for multiple data inputs.
$source,
[Parameter()]
[string]
#The value to populate in the sourcetype field for incoming events.
$sourcetype,
		
		[Parameter(ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
        [String]
		# The name of the input to update.
		$Name,
		
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
	}
	Process 
	{
		write-debug "Tag: UDP; InputType: UDP";
		$psb = @{};
		$PSBoundParameters.Keys | foreach{ $psb[$_] = $PSBoundParameters[$_] };
		$setParameters = $inputs['UDP'].setParameters;
		$newParameters = $inputs['UDP'].newParameters;
		$setParameters | foreach { 
			$sp = $_;
			$key = $_.powershellname;
			$np = $newParameters | where {$_.powershellname -eq $key };
			write-debug "Removing bound parameter $key"; 

			#copy inherited property values from new-parameter set
			$u = @{};
			$_.keys | where {$sp[$_] -match 'Inherited' } | foreach {
				
				write-debug "inheriting set parameter value for key $_";
				$u[$_] = $np[$_];
			}
			$u.keys | foreach { $sp[$_] = $u[$_] };

			$_.value = $PSBoundParameters[$key]; 
			
			if( $_.value -is [array] )
			{
				$_.value = $_.value -join ',';
			}
			
			$psb.Remove($key) | out-null;
			
			write-debug "set parameter key [$key] value [$($_.value)]";
		}

		write-debug "Integer fields: "
		write-debug "Boolean fields: no_appending_timestamp no_priority_stripping"
		
		Set-InputProxy @psb -InputType UDP -SetParameters $setParameters -OutputFields @{
			integer = @('');
			boolean = @('no_appending_timestamp', 'no_priority_stripping');
		}
	}
	End
	{
	}
}
	function Set-SplunkInputScript
	{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[CmdletBinding(SupportsShouldProcess=$true)]
    Param(
		[Parameter()]
[switch]
#Specifies whether the input script is disabled.
$disabled,
[Parameter()]
[string]
#Sets the host for events from this input. Defaults to whatever host sent the event.
$host,
[Parameter()]
[string]
#Sets the index for events from this input. Defaults to the main index.
$index,
[Parameter()]
[int]
#Specify an integer or cron schedule. This parameter specifies how often to execute the specified script, in seconds or a valid cron schedule. If you specify a cron schedule, the script is not executed on start-up.
$interval,
[Parameter()]
[string]
#Specify a new name for the source field for the script.
$renamesource,
[Parameter()]
[string]
#td
$source,
[Parameter()]
[string]
#td
$sourcetype,
		
		[Parameter(ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
        [String]
		# The name of the input to update.
		$Name,
		
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
	}
	Process 
	{
		write-debug "Tag: Script; InputType: Script";
		$psb = @{};
		$PSBoundParameters.Keys | foreach{ $psb[$_] = $PSBoundParameters[$_] };
		$setParameters = $inputs['Script'].setParameters;
		$newParameters = $inputs['Script'].newParameters;
		$setParameters | foreach { 
			$sp = $_;
			$key = $_.powershellname;
			$np = $newParameters | where {$_.powershellname -eq $key };
			write-debug "Removing bound parameter $key"; 

			#copy inherited property values from new-parameter set
			$u = @{};
			$_.keys | where {$sp[$_] -match 'Inherited' } | foreach {
				
				write-debug "inheriting set parameter value for key $_";
				$u[$_] = $np[$_];
			}
			$u.keys | foreach { $sp[$_] = $u[$_] };

			$_.value = $PSBoundParameters[$key]; 
			
			if( $_.value -is [array] )
			{
				$_.value = $_.value -join ',';
			}
			
			$psb.Remove($key) | out-null;
			
			write-debug "set parameter key [$key] value [$($_.value)]";
		}

		write-debug "Integer fields: interval"
		write-debug "Boolean fields: disabled"
		
		Set-InputProxy @psb -InputType Script -SetParameters $setParameters -OutputFields @{
			integer = @('interval');
			boolean = @('disabled');
		}
	}
	End
	{
	}
}
	function Set-SplunkInputAd
	{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[CmdletBinding(SupportsShouldProcess=$true)]
    Param(
		[Parameter()]
[switch]
#Whether or not to monitor the subtree(s) of a given directory tree path.
$monitorSubtree,
[Parameter()]
[switch]
#Indicates whether the monitoring is disabled.
$disabled,
[Parameter()]
[string]
#The index in which to store the gathered data.
$index,
[Parameter()]
[string]
#Where in the Active Directory directory tree to start monitoring.  If not specified, will attempt to start at the root of the directory tree.
$startingNode,
[Parameter()]
[string]
#Specifies a fully qualified domain name of a valid, network-accessible DC.  If not specified, Splunk will obtain the local computer DC.
$targetDc,
		
		[Parameter(ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
        [String]
		# The name of the input to update.
		$Name,
		
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
	}
	Process 
	{
		write-debug "Tag: Ad; InputType: Ad";
		$psb = @{};
		$PSBoundParameters.Keys | foreach{ $psb[$_] = $PSBoundParameters[$_] };
		$setParameters = $inputs['Ad'].setParameters;
		$newParameters = $inputs['Ad'].newParameters;
		$setParameters | foreach { 
			$sp = $_;
			$key = $_.powershellname;
			$np = $newParameters | where {$_.powershellname -eq $key };
			write-debug "Removing bound parameter $key"; 

			#copy inherited property values from new-parameter set
			$u = @{};
			$_.keys | where {$sp[$_] -match 'Inherited' } | foreach {
				
				write-debug "inheriting set parameter value for key $_";
				$u[$_] = $np[$_];
			}
			$u.keys | foreach { $sp[$_] = $u[$_] };

			$_.value = $PSBoundParameters[$key]; 
			
			if( $_.value -is [array] )
			{
				$_.value = $_.value -join ',';
			}
			
			$psb.Remove($key) | out-null;
			
			write-debug "set parameter key [$key] value [$($_.value)]";
		}

		write-debug "Integer fields: monitorSubtree disabled"
		write-debug "Boolean fields: "
		
		Set-InputProxy @psb -InputType Ad -SetParameters $setParameters -OutputFields @{
			integer = @('monitorSubtree', 'disabled');
			boolean = @('');
		}
	}
	End
	{
	}
}
	function Set-SplunkInputWinWmiCollections
	{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[CmdletBinding(SupportsShouldProcess=$true)]
    Param(
		[Parameter()]
[string]
#A valid WMI class name.
$classes,
[Parameter()]
[int]
#The interval at which the WMI provider(s) will be queried.
$interval,
[Parameter()]
[string]
#This is the server from which we will be gathering WMI data.  If you need to gather data from more than one machine, additional servers can be specified in the server parameter.
$lookuphost,
[Parameter()]
[int]
#Disables the given collection.
$disabled,
[Parameter()]
[string[]]
#A list of all properties that you want to gather from the given class.
$fields,
[Parameter()]
[string]
#The index in which to store the gathered data.
$index,
[Parameter()]
[string[]]
#A list of all instances of a given class for which data is to be gathered.
$instances,
[Parameter()]
[string[]]
#A list of additional servers that you want to gather data from.  Use this if you need to gather from more than a single machine.  See also lookup_host parameter.
$server,
		
		[Parameter(ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
        [String]
		# The name of the input to update.
		$Name,
		
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
	}
	Process 
	{
		write-debug "Tag: WinWmiCollections; InputType: win-wmi-collections";
		$psb = @{};
		$PSBoundParameters.Keys | foreach{ $psb[$_] = $PSBoundParameters[$_] };
		$setParameters = $inputs['win-wmi-collections'].setParameters;
		$newParameters = $inputs['win-wmi-collections'].newParameters;
		$setParameters | foreach { 
			$sp = $_;
			$key = $_.powershellname;
			$np = $newParameters | where {$_.powershellname -eq $key };
			write-debug "Removing bound parameter $key"; 

			#copy inherited property values from new-parameter set
			$u = @{};
			$_.keys | where {$sp[$_] -match 'Inherited' } | foreach {
				
				write-debug "inheriting set parameter value for key $_";
				$u[$_] = $np[$_];
			}
			$u.keys | foreach { $sp[$_] = $u[$_] };

			$_.value = $PSBoundParameters[$key]; 
			
			if( $_.value -is [array] )
			{
				$_.value = $_.value -join ',';
			}
			
			$psb.Remove($key) | out-null;
			
			write-debug "set parameter key [$key] value [$($_.value)]";
		}

		write-debug "Integer fields: interval disabled"
		write-debug "Boolean fields: "
		
		Set-InputProxy @psb -InputType WinWmiCollections -inputUrl 'win-wmi-collections' -SetParameters $setParameters -OutputFields @{
			integer = @('interval', 'disabled');
			boolean = @('');
		}
	}
	End
	{
	}
}
	function New-SplunkInputWinPerfmon
	{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[CmdletBinding(SupportsShouldProcess=$true)]
    Param(
		[Parameter(Mandatory=$True)]
[int]
#How frequently to poll the performance counters.
$interval,
[Parameter(Mandatory=$True)]
[string]
#This is the name of the collection.  This name will appear in configuration file, as well as the source and the sourcetype of the indexed data.
$name,
[Parameter(Mandatory=$True)]
[string]
#A valid performance monitor object (for example, "Process," "Server," "PhysicalDisk.")
$object,
[Parameter(Mandatory=$False)]
[string[]]
#A list of all counters to monitor. A * is equivalent to all counters.
$counters,
[Parameter(Mandatory=$False)]
[int]
#Disables a given monitoring stanza.
$disabled,
[Parameter(Mandatory=$False)]
[string]
#The index in which to store the gathered data.
$index,
[Parameter(Mandatory=$False)]
[string[]]
#A list of counter instances.  A * is equivalent to all instances.
$instances,
		
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
	}
	Process 
	{
		write-debug "Tag: WinPerfmon; InputType: win-perfmon";
		$psb = @{};
		$PSBoundParameters.Keys | foreach{ $psb[$_] = $PSBoundParameters[$_] };
		$newParameters = $inputs['win-perfmon'].newParameters;
		$newParameters | foreach { 
			$key = $_.powershellname;
			write-debug "Removing bound parameter $key"; 
			
			$_.value = $PSBoundParameters[$key]; 
			if( $_.value -is [array] )
			{
				$_.value = $_.value -join ',';
			}

			$psb.Remove($key) | out-null;
			
			write-debug "new parameter key [$key] value [$($_.value)]";
		}
		
		write-debug "Integer fields: interval disabled"
		write-debug "Boolean fields: "
		New-InputProxy @psb -InputType WinPerfmon -inputUrl 'win-perfmon' -NewParameters $newParameters -OutputFields @{
			integer = @('interval', 'disabled');
			boolean = @('');
		}
	}
	End
	{
	}
}
	function New-SplunkInputRegistry
	{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[CmdletBinding(SupportsShouldProcess=$true)]
    Param(
		[Parameter(Mandatory=$True)]
[int]
#Specifies whether or not to establish a baseline value for the registry keys.  1 means yes, 0 no.
$baseline,
[Parameter(Mandatory=$True)]
[string]
#Specifies the registry hive under which to monitor for changes.
$hive,
[Parameter(Mandatory=$True)]
[string]
#Name of the configuration stanza.
$name,
[Parameter(Mandatory=$True)]
[string]
#Specifies a regex.  If specified, will only collected changes if a process name matches that regex.
$proc,
[Parameter(Mandatory=$True)]
[string]
#A regular expression that specifies the type(s) of Registry event(s) that you want to monitor.
$type,
[Parameter(Mandatory=$False)]
[int]
#Indicates whether the monitoring is disabled.
$disabled,
[Parameter(Mandatory=$False)]
[string]
#The index in which to store the gathered data.
$index,
[Parameter(Mandatory=$False)]
[int]
#If set to 1, will monitor all sub-nodes under a given hive.
$monitorSubnodes,
		
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
	}
	Process 
	{
		write-debug "Tag: Registry; InputType: Registry";
		$psb = @{};
		$PSBoundParameters.Keys | foreach{ $psb[$_] = $PSBoundParameters[$_] };
		$newParameters = $inputs['Registry'].newParameters;
		$newParameters | foreach { 
			$key = $_.powershellname;
			write-debug "Removing bound parameter $key"; 
			
			$_.value = $PSBoundParameters[$key]; 
			if( $_.value -is [array] )
			{
				$_.value = $_.value -join ',';
			}

			$psb.Remove($key) | out-null;
			
			write-debug "new parameter key [$key] value [$($_.value)]";
		}
		
		write-debug "Integer fields: baseline disabled monitorSubnodes"
		write-debug "Boolean fields: "
		New-InputProxy @psb -InputType Registry -NewParameters $newParameters -OutputFields @{
			integer = @('baseline', 'disabled', 'monitorSubnodes');
			boolean = @('');
		}
	}
	End
	{
	}
}
	function New-SplunkInputMonitor
	{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[CmdletBinding(SupportsShouldProcess=$true)]
    Param(
		[Parameter(Mandatory=$True)]
[string]
#The file or directory path to monitor on the system.
$name,
[Parameter(Mandatory=$False)]
[string]
#Specify a regular expression for a file path. The file path that matches this regular expression is not indexed.
$blacklist,
[Parameter(Mandatory=$False)]
[switch]
#If set to true, the "index" value will be checked to ensure that it is the name of a valid index.
$checkindex,
[Parameter(Mandatory=$False)]
[switch]
#If set to true, the "name" value will be checked to ensure that it exists.
$checkpath,
[Parameter(Mandatory=$False)]
[string]
#A string that modifies the file tracking identity for files in this input.  The magic value "<SOURCE>" invokes special behavior (see admin documentation).
$crcsalt,
[Parameter(Mandatory=$False)]
[switch]
#If set to true, files that are seen for the first time will be read from the end.
$followTail,
[Parameter(Mandatory=$False)]
[string]
#The value to populate in the host field for events from this data input.
$host,
[Parameter(Mandatory=$False)]
[string]
#Specify a regular expression for a file path. If the path for a file matches this regular expression, the captured value is used to populate the host field for events from this data input.  The regular expression must have one capture group.
$hostregex,
[Parameter(Mandatory=$False)]
[int]
#Use the specified slash-separate segment of the filepath as the host field value.
$hostsegment,
[Parameter(Mandatory=$False)]
[string]
#Specify a time value. If the modification time of a file being monitored falls outside of this rolling time window, the file is no longer being monitored.
$ignoreolderthan,
[Parameter(Mandatory=$False)]
[string]
#Which index events from this input should be stored in.
$index,
[Parameter(Mandatory=$False)]
[switch]
#Setting this to "false" will prevent monitoring of any subdirectories encountered within this data input.
$recursive,
[Parameter(Mandatory=$False)]
[string]
#The value to populate in the source field for events from this data input.  The same source should not be used for multiple data inputs.
$renamesource,
[Parameter(Mandatory=$False)]
[string]
#The value to populate in the sourcetype field for incoming events.
$sourcetype,
[Parameter(Mandatory=$False)]
[int]
#When Splunk reaches the end of a file that is being read, the file will be kept open for a minimum of the number of seconds specified in this value.  After this period has elapsed, the file will be checked again for more data.
$timebeforeclose,
[Parameter(Mandatory=$False)]
[string]
#Specify a regular expression for a file path. Only file paths that match this regular expression are indexed.
$whitelist,
		
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
	}
	Process 
	{
		write-debug "Tag: Monitor; InputType: Monitor";
		$psb = @{};
		$PSBoundParameters.Keys | foreach{ $psb[$_] = $PSBoundParameters[$_] };
		$newParameters = $inputs['Monitor'].newParameters;
		$newParameters | foreach { 
			$key = $_.powershellname;
			write-debug "Removing bound parameter $key"; 
			
			$_.value = $PSBoundParameters[$key]; 
			if( $_.value -is [array] )
			{
				$_.value = $_.value -join ',';
			}

			$psb.Remove($key) | out-null;
			
			write-debug "new parameter key [$key] value [$($_.value)]";
		}
		
		write-debug "Integer fields: host_segment time-before-close"
		write-debug "Boolean fields: check-index check-path followTail recursive"
		New-InputProxy @psb -InputType Monitor -NewParameters $newParameters -OutputFields @{
			integer = @('host_segment', 'time-before-close');
			boolean = @('check-index', 'check-path', 'followTail', 'recursive');
		}
	}
	End
	{
	}
}
	function New-SplunkInputWinEventLogCollections
	{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[CmdletBinding(SupportsShouldProcess=$true)]
    Param(
		[Parameter(Mandatory=$True)]
[string]
#This is a host from which we will monitor log events.  To specify additional hosts to be monitored via WMI, use the "hosts" parameter.
$lookuphost,
[Parameter(Mandatory=$True)]
[string]
#This is the name of the collection.  This name will appear in configuration file, as well as the source and the sourcetype of the indexed data.  If the value is "localhost", it will use native event log collection; otherwise, it will use WMI.
$name,
[Parameter(Mandatory=$False)]
[string[]]
#A list of addtional hosts to be used for monitoring.  The first host should be specified with "lookup_host", and the additional ones using this parameter.
$hosts,
[Parameter(Mandatory=$False)]
[string]
#The index in which to store the gathered data.
$index,
[Parameter(Mandatory=$False)]
[string[]]
#A list of event log names to gather data from.
$logs,
		
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
	}
	Process 
	{
		write-debug "Tag: WinEventLogCollections; InputType: win-event-log-collections";
		$psb = @{};
		$PSBoundParameters.Keys | foreach{ $psb[$_] = $PSBoundParameters[$_] };
		$newParameters = $inputs['win-event-log-collections'].newParameters;
		$newParameters | foreach { 
			$key = $_.powershellname;
			write-debug "Removing bound parameter $key"; 
			
			$_.value = $PSBoundParameters[$key]; 
			if( $_.value -is [array] )
			{
				$_.value = $_.value -join ',';
			}

			$psb.Remove($key) | out-null;
			
			write-debug "new parameter key [$key] value [$($_.value)]";
		}
		
		write-debug "Integer fields: "
		write-debug "Boolean fields: "
		New-InputProxy @psb -InputType WinEventLogCollections -inputUrl 'win-event-log-collections' -NewParameters $newParameters -OutputFields @{
			integer = @('');
			boolean = @('');
		}
	}
	End
	{
	}
}
	function New-SplunkInputTCPCooked
	{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[CmdletBinding(SupportsShouldProcess=$true)]
    Param(
		[Parameter(Mandatory=$True)]
[int]
#The port number of this input.
$name,
[Parameter(Mandatory=$False)]
[switch]
#If SSL is not already configured, error is returned
$SSL,
[Parameter(Mandatory=$False)]
[string]
#Valid values: (ip | dns | none).  Set the host for the remote server that is sending data.  ip sets the host to the IP address of the remote server sending data. dns sets the host to the reverse DNS entry for the IP address of the remote server sending data. none leaves the host as specified in inputs.conf.  Default value is dns. 
$connectionhost,
[Parameter(Mandatory=$False)]
[switch]
#Indicates whether the input is disabled.
$disabled,
[Parameter(Mandatory=$False)]
[string]
#The default value to fill in for events lacking a host value.
$host,
[Parameter(Mandatory=$False)]
[string]
#Restrict incoming connections on this port to the host specified here.
$restrictToHost,
		
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
	}
	Process 
	{
		write-debug "Tag: TCPCooked; InputType: TCP/Cooked";
		$psb = @{};
		$PSBoundParameters.Keys | foreach{ $psb[$_] = $PSBoundParameters[$_] };
		$newParameters = $inputs['TCP/Cooked'].newParameters;
		$newParameters | foreach { 
			$key = $_.powershellname;
			write-debug "Removing bound parameter $key"; 
			
			$_.value = $PSBoundParameters[$key]; 
			if( $_.value -is [array] )
			{
				$_.value = $_.value -join ',';
			}

			$psb.Remove($key) | out-null;
			
			write-debug "new parameter key [$key] value [$($_.value)]";
		}
		
		write-debug "Integer fields: name"
		write-debug "Boolean fields: SSL disabled"
		New-InputProxy @psb -InputType TCPCooked -inputUrl 'tcp/cooked' -NewParameters $newParameters -OutputFields @{
			integer = @('name');
			boolean = @('SSL', 'disabled');
		}
	}
	End
	{
	}
}
	function New-SplunkInputTCPRaw
	{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[CmdletBinding(SupportsShouldProcess=$true)]
    Param(
		[Parameter(Mandatory=$True)]
[string]
#The input port which splunk receives raw data in.
$name,
[Parameter(Mandatory=$False)]
[switch]
#	If SSL is not already configured, error is returned 
$SSL,
[Parameter(Mandatory=$False)]
[string]
#Valid values: (ip | dns | none).  Specify the remote server that is the connection host.  ip: specifies the IP address of the remote server.  dns: sets the host to the DNS entry of the remote server.  none: leaves the host as specified.
$connectionhost,
[Parameter(Mandatory=$False)]
[switch]
#Indicates whether the inputs are disabled.
$disabled,
[Parameter(Mandatory=$False)]
[string]
#The host from which the indexer gets data.
$host,
[Parameter(Mandatory=$False)]
[string]
#The index in which to store all generated events.
$index,
[Parameter(Mandatory=$False)]
[string]
#Valid values: (parsingQueue | indexQueue).  Specifies where the input processor should deposit the events it reads. Defaults to parsingQueue.  Set queue to parsingQueue to apply props.conf and other parsing rules to your data. For more information about props.conf and rules for timestamping and linebreaking, refer to props.conf and the online documentation at Edit inputs.conf.  Set queue to indexQueue to send your data directly into the index.
$queue,
[Parameter(Mandatory=$False)]
[string]
#Allows for restricting this input to only accept data from the host specified here.
$restrictToHost,
[Parameter(Mandatory=$False)]
[string]
#Sets the source key/field for events from this input. Defaults to the input file path.  Sets the source key initial value. The key is used during parsing/indexing, in particular to set the source field during indexing. It is also the source field used at search time. As a convenience, the chosen string is prepended with "source::".  Note: Overriding the source key is generally not recommended.Typically, the input layer provides a more accurate string to aid in problem analysis and investigation, accurately recording the file from which the data was retreived. Consider use of source types, tagging, and search wildcards before overriding this value.
$source,
[Parameter(Mandatory=$False)]
[string]
#Set the source type for events from this input.  "sourcetype=" is automatically prepended to <string>.  Defaults to audittrail (if signedaudit=true) or fschange (if signedaudit=false).
$sourcetype,
		
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
	}
	Process 
	{
		write-debug "Tag: TCPRaw; InputType: TCP/Raw";
		$psb = @{};
		$PSBoundParameters.Keys | foreach{ $psb[$_] = $PSBoundParameters[$_] };
		$newParameters = $inputs['TCP/Raw'].newParameters;
		$newParameters | foreach { 
			$key = $_.powershellname;
			write-debug "Removing bound parameter $key"; 
			
			$_.value = $PSBoundParameters[$key]; 
			if( $_.value -is [array] )
			{
				$_.value = $_.value -join ',';
			}

			$psb.Remove($key) | out-null;
			
			write-debug "new parameter key [$key] value [$($_.value)]";
		}
		
		write-debug "Integer fields: "
		write-debug "Boolean fields: SSL disabled"
		New-InputProxy @psb -InputType TCPRaw -InputURL 'tcp/raw' -NewParameters $newParameters -OutputFields @{
			integer = @('');
			boolean = @('SSL', 'disabled');
		}
	}
	End
	{
	}
}
	function New-SplunkInputUDP
	{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[CmdletBinding(SupportsShouldProcess=$true)]
    Param(
		[Parameter(Mandatory=$True)]
[string]
#The UDP port that this input should listen on.
$name,
[Parameter(Mandatory=$False)]
[string]
#Valid values: (ip | dns | none).  ip: The host field for incoming events is set to the IP address of the remote server.  dns: The host field is set to the DNS entry of the remote server.  none: The host field remains unchanged.  Defaults to ip.
$connectionhost,
[Parameter(Mandatory=$False)]
[string]
#The value to populate in the host field for incoming events.
$host,
[Parameter(Mandatory=$False)]
[string]
#Which index events from this input should be stored in.
$index,
[Parameter(Mandatory=$False)]
[switch]
#If set to true, prevents Splunk from prepending a timestamp and hostname to incoming events.
$noappendingtimestamp,
[Parameter(Mandatory=$False)]
[switch]
#If set to true, Splunk will not remove the priority field from incoming syslog events.
$noprioritystripping,
[Parameter(Mandatory=$False)]
[string]
#Which queue events from this input should be sent to.  Generally this does not need to be changed.
$queue,
[Parameter(Mandatory=$False)]
[string]
#The value to populate in the source field for incoming events.  The same source should not be used for multiple data inputs.
$source,
[Parameter(Mandatory=$False)]
[string]
#The value to populate in the sourcetype field for incoming events.
$sourcetype,
		
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
	}
	Process 
	{
		write-debug "Tag: UDP; InputType: UDP";
		$psb = @{};
		$PSBoundParameters.Keys | foreach{ $psb[$_] = $PSBoundParameters[$_] };
		$newParameters = $inputs['UDP'].newParameters;
		$newParameters | foreach { 
			$key = $_.powershellname;
			write-debug "Removing bound parameter $key"; 
			
			$_.value = $PSBoundParameters[$key]; 
			if( $_.value -is [array] )
			{
				$_.value = $_.value -join ',';
			}

			$psb.Remove($key) | out-null;
			
			write-debug "new parameter key [$key] value [$($_.value)]";
		}
		
		write-debug "Integer fields: "
		write-debug "Boolean fields: no_appending_timestamp no_priority_stripping"
		New-InputProxy @psb -InputType UDP -NewParameters $newParameters -OutputFields @{
			integer = @('');
			boolean = @('no_appending_timestamp', 'no_priority_stripping');
		}
	}
	End
	{
	}
}
	function New-SplunkInputScript
	{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[CmdletBinding(SupportsShouldProcess=$true)]
    Param(
		[Parameter(Mandatory=$True)]
[int]
#Specify an integer or cron schedule. This parameter specifies how often to execute the specified script, in seconds or a valid cron schedule. If you specify a cron schedule, the script is not executed on start-up.
$interval,
[Parameter(Mandatory=$True)]
[string]
#Specify the name of the scripted input.
$name,
[Parameter(Mandatory=$False)]
[switch]
#Specifies whether the input script is disabled.
$disabled,
[Parameter(Mandatory=$False)]
[string]
#Sets the host for events from this input. Defaults to whatever host sent the event.
$host,
[Parameter(Mandatory=$False)]
[string]
#Sets the index for events from this input. Defaults to the main index.
$index,
[Parameter(Mandatory=$False)]
[string]
#Specify a new name for the source field for the script.
$renamesource,
[Parameter(Mandatory=$False)]
[string]
#td
$source,
[Parameter(Mandatory=$False)]
[string]
#td
$sourcetype,
		
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
	}
	Process 
	{
		write-debug "Tag: Script; InputType: Script";
		$psb = @{};
		$PSBoundParameters.Keys | foreach{ $psb[$_] = $PSBoundParameters[$_] };
		$newParameters = $inputs['Script'].newParameters;
		$newParameters | foreach { 
			$key = $_.powershellname;
			write-debug "Removing bound parameter $key"; 
			
			$_.value = $PSBoundParameters[$key]; 
			if( $_.value -is [array] )
			{
				$_.value = $_.value -join ',';
			}

			$psb.Remove($key) | out-null;
			
			write-debug "new parameter key [$key] value [$($_.value)]";
		}
		
		write-debug "Integer fields: interval"
		write-debug "Boolean fields: disabled"
		New-InputProxy @psb -InputType Script -NewParameters $newParameters -OutputFields @{
			integer = @('interval');
			boolean = @('disabled');
		}
	}
	End
	{
	}
}
	function New-SplunkInputAd
	{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[CmdletBinding(SupportsShouldProcess=$true)]
    Param(
		[Parameter(Mandatory=$False)]
[switch]
#Whether or not to monitor the subtree(s) of a given directory tree path.
$monitorSubtree,
[Parameter(Mandatory=$True)]
[string]
#A unique name that represents a configuration or set of configurations for a specific domain controller (DC).
$name,
[Parameter(Mandatory=$False)]
[switch]
#Indicates whether the monitoring is disabled.
$disabled,
[Parameter(Mandatory=$False)]
[string]
#The index in which to store the gathered data.
$index,
[Parameter(Mandatory=$False)]
[string]
#Where in the Active Directory directory tree to start monitoring.  If not specified, will attempt to start at the root of the directory tree.
$startingNode,
[Parameter(Mandatory=$False)]
[string]
#Specifies a fully qualified domain name of a valid, network-accessible DC.  If not specified, Splunk will obtain the local computer DC.
$targetDc,
		
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
	}
	Process 
	{
		write-debug "Tag: Ad; InputType: Ad";
		$psb = @{};
		$PSBoundParameters.Keys | foreach{ $psb[$_] = $PSBoundParameters[$_] };
		$newParameters = $inputs['Ad'].newParameters;
		$newParameters | foreach { 
			$key = $_.powershellname;
			write-debug "Removing bound parameter $key"; 
			
			$_.value = $PSBoundParameters[$key]; 
			if( $_.value -is [array] )
			{
				$_.value = $_.value -join ',';
			}

			$psb.Remove($key) | out-null;
			
			write-debug "new parameter key [$key] value [$($_.value)]";
		}
		
		write-debug "Integer fields: monitorSubtree disabled"
		write-debug "Boolean fields: "
		New-InputProxy @psb -InputType Ad -NewParameters $newParameters -OutputFields @{
			integer = @('monitorSubtree', 'disabled');
			boolean = @('');
		}
	}
	End
	{
	}
}
	function New-SplunkInputOneShot
	{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[CmdletBinding(SupportsShouldProcess=$true)]
    Param(
		[Parameter(Mandatory=$True)]
[string]
#The path to the file to be indexed. The file must be locally accessible by the server.
$name,
[Parameter(Mandatory=$False)]
[string]
#The value of the "host" field to be applied to data from this file.
$host,
[Parameter(Mandatory=$False)]
[string]
#td
$hostregex,
[Parameter(Mandatory=$False)]
[int]
#Use the specified slash-separate segment of the path as the host field value.
$hostsegment,
[Parameter(Mandatory=$False)]
[string]
#The destination index for data processed from this file.
$index,
[Parameter(Mandatory=$False)]
[string]
#The value of the "source" field to be applied to data from this file.
$renamesource,
[Parameter(Mandatory=$False)]
[string]
#The value of the "sourcetype" field to be applied to data from this file.
$sourcetype,
		
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
	}
	Process 
	{
		write-debug "Tag: OneShot; InputType: OneShot";
		$psb = @{};
		$PSBoundParameters.Keys | foreach{ $psb[$_] = $PSBoundParameters[$_] };
		$newParameters = $inputs['OneShot'].newParameters;
		$newParameters | foreach { 
			$key = $_.powershellname;
			write-debug "Removing bound parameter $key"; 
			
			$_.value = $PSBoundParameters[$key]; 
			if( $_.value -is [array] )
			{
				$_.value = $_.value -join ',';
			}

			$psb.Remove($key) | out-null;
			
			write-debug "new parameter key [$key] value [$($_.value)]";
		}
		
		write-debug "Integer fields: host_segment"
		write-debug "Boolean fields: "
		New-InputProxy @psb -InputType OneShot -NewParameters $newParameters -OutputFields @{
			integer = @('host_segment');
			boolean = @('');
		}
	}
	End
	{
	}
}
	function New-SplunkInputWinWmiCollections
	{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[CmdletBinding(SupportsShouldProcess=$true)]
    Param(
		[Parameter(Mandatory=$True)]
[string]
#A valid WMI class name.
$classes,
[Parameter(Mandatory=$True)]
[int]
#The interval at which the WMI provider(s) will be queried.
$interval,
[Parameter(Mandatory=$True)]
[string]
#This is the server from which we will be gathering WMI data.  If you need to gather data from more than one machine, additional servers can be specified in the server parameter.
$lookuphost,
[Parameter(Mandatory=$True)]
[string]
#This is the name of the collection.  This name will appear in configuration file, as well as the source and the sourcetype of the indexed data.
$name,
[Parameter(Mandatory=$False)]
[int]
#Disables the given collection.
$disabled,
[Parameter(Mandatory=$False)]
[string[]]
#A list of all properties that you want to gather from the given class.
$fields,
[Parameter(Mandatory=$False)]
[string]
#The index in which to store the gathered data.
$index,
[Parameter(Mandatory=$False)]
[string[]]
#A list of all instances of a given class for which data is to be gathered.
$instances,
[Parameter(Mandatory=$False)]
[string[]]
#A list of additional servers that you want to gather data from.  Use this if you need to gather from more than a single machine.  See also lookup_host parameter.
$server,
		
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
	}
	Process 
	{
		write-debug "Tag: WinWmiCollections; InputType: win-wmi-collections";
		$psb = @{};
		$PSBoundParameters.Keys | foreach{ $psb[$_] = $PSBoundParameters[$_] };
		$newParameters = $inputs['win-wmi-collections'].newParameters;
		$newParameters | foreach { 
			$key = $_.powershellname;
			write-debug "Removing bound parameter $key"; 
			
			$_.value = $PSBoundParameters[$key]; 
			if( $_.value -is [array] )
			{
				$_.value = $_.value -join ',';
			}

			$psb.Remove($key) | out-null;
			
			write-debug "new parameter key [$key] value [$($_.value)]";
		}
		
		write-debug "Integer fields: interval disabled"
		write-debug "Boolean fields: "
		New-InputProxy @psb -InputType 'WinWmiCollections' -InputURL 'Win-Wmi-Collections' -NewParameters $newParameters -OutputFields @{
			integer = @('interval', 'disabled');
			boolean = @('');
		}
	}
	End
	{
	}
}

#endregion solidified
Export-ModuleMember -Function *splunk*;

