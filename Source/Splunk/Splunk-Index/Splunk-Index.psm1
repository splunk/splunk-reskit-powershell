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

#region Get-SplunkIndex
function Get-SplunkIndex
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
#Boolean predicate to filter results
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
		
		[Parameter()]
		[Alias( "Summary", "Short", "Fast" )]
		[switch]
# If true, leaves out certain index details in order to provide a faster response. 
$Summarize,
       
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

	        Write-Verbose " [Get-SplunkIndex] :: Starting..."	        
			
			$ParamSetName = $pscmdlet.ParameterSetName
	        
	        switch ($ParamSetName)
	        {
	            "byFilter"  { 
					$Endpoint = '/services/data/indexes'
					$WhereFilter = { $_.Name -match $Filter }
				}
	            "byName"    { 
					$Endpoint = "/services/data/indexes/$Name"
					$WhereFilter = { $_ }
				}
	        }	        
	}
	Process 
	{
	        Write-Verbose " [Get-SplunkIndex] :: Parameters"
	        Write-Verbose " [Get-SplunkIndex] ::  - ComputerName = $ComputerName"
	        Write-Verbose " [Get-SplunkIndex] ::  - Port         = $Port"
	        Write-Verbose " [Get-SplunkIndex] ::  - Protocol     = $Protocol"
	        Write-Verbose " [Get-SplunkIndex] ::  - Timeout      = $Timeout"
	        Write-Verbose " [Get-SplunkIndex] ::  - Credential   = $Credential"
	        Write-Verbose " [Get-SplunkIndex] ::  - Count		 = $Count"
	        Write-Verbose " [Get-SplunkIndex] ::  - Offset 		 = $Offset"
	        Write-Verbose " [Get-SplunkIndex] ::  - Filter		 = $Filter"
			Write-Verbose " [Get-SplunkIndex] ::  - Name		 = $Name"
			Write-Verbose " [Get-SplunkIndex] ::  - SortDir		 = $SortDir"
			Write-Verbose " [Get-SplunkIndex] ::  - SortMode	 = $SortMode"
			Write-Verbose " [Get-SplunkIndex] ::  - SortKey		 = $SortKey"
			Write-Verbose " [Get-SplunkIndex] ::  - Summarize	 = $Summarize"
			Write-Verbose " [Get-SplunkIndex] ::  - WhereFilter	 = $WhereFilter"
			
			Write-Verbose " [Get-SplunkIndex] ::  - Endpoint		 = $Endpoint"
			
	        Write-Verbose " [Get-SplunkIndex] :: Setting up Invoke-APIRequest parameters"
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
				summarize	 = $summarise
			}
			
	        Write-Verbose " [Get-SplunkIndex] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
	        try
	        {
$Results = Invoke-SplunkAPIRequest @InvokeAPIParams -Arguments $restArgs;
	        }
	        catch
	        {
	            Write-Verbose " [Get-SplunkIndex] :: Invoke-SplunkAPIRequest threw an exception: $_"
	            Write-Error $_
	        }
			
	        try
	        {
	            if($Results -and ($Results -is [System.Xml.XmlDocument] -and ($Results.feed.entry)))
	            {
	                Write-Verbose " [Get-SplunkIndex] :: Creating Hash Table to be used to create Splunk.SDK.Index"
	                
	                foreach($Entry in $Results.feed.entry)
	                {
	                    $MyObj = @{
	                        ComputerName                = $ComputerName
	                        Name                 		= $Entry.Title
	                        ServiceEndpoint             = $Entry.link | ?{$_.rel -eq "edit"} | select -ExpandProperty href
	                    }
	                    
						$ignoreParams = 'eai:attributes,eai:acl' -split '\s*,\s*';
						$booleanParams = 'assureUTF8, compressRawdata, disabled, enableRealtimeSearch, isInternal, sync' -split '\s*,\s*';
						$intParams = 
							'blockSignSize, currentDBSizeMB, frozenTimePeriodInSecs, maxConcurrentOptimizes, maxHotBuckets, maxHotIdleSecs, maxHitSpanSecs, maxMemDB, maxMetaEntries,' +
							'maxRunningProcessGroups, maxTotalDataSizeMB, maxWarmDBCount, partialServiceMetaPeriod, quarantineFutureSecs, quarantinePastSecs, rawChuckSizeBytes,' +
							'rotatePeriodInSecs, serviceMetaPeriod, throttleCheckPeriod, totalEventCount' -split '\s*,\s*';
						
	                    switch ($Entry.content.dict.key)
	                    {
							{ $ignoreParams -contains $_.name }            { continue }
	                        { $booleanParams -contains $_.name }        { $Myobj.Add( $_.Name, [bool]([int]$_.'#text') ); continue }													
	                        { $intParams -contains $_.name }            { $Myobj.Add( $_.Name, ([int]$_.'#text') ); continue }
	                        Default                                     { $Myobj.Add($_.Name,$_.'#text'); continue }
	                    }
	                    
	                    # Creating Splunk.SDK.ServiceStatus
	                    $obj = New-Object PSObject -Property $MyObj
	                    $obj.PSTypeNames.Clear()
	                    $obj.PSTypeNames.Add('Splunk.SDK.Index')
	                    $obj | Where $WhereFilter;
	                }
	            }
	            else
	            {
	                Write-Verbose " [Get-SplunkIndex] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
	            }
	        }
	        catch
	        {
	            Write-Verbose " [Get-SplunkIndex] :: Get-SplunkIndex threw an exception: $_"
	            Write-Error $_
	        }
	    
	}
	End 
    {

	        Write-Verbose " [Get-SplunkIndex] :: =========    End   ========="
	    
	}
}
#endregion Get-SplunkIndex

#region New-SplunkIndex

function New-SplunkIndex
{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[Cmdletbinding(SupportsShouldProcess=$true)]
    Param(
	
		[Parameter(Mandatory=$true)]
		[Alias("Index","IndexName")]
		[string] 
		# The name of the new index
		$name,
		
		[Parameter()]
		[switch]
# Verifies that all data retreived from the index is proper UTF8.  Will degrade indexing performance when enabled (set to true).
$assureUTF8, 	

		[Parameter()]
		[int]
# Controls how many events make up a block for block signatures.  If this is set to 0, block signing is disabled for this index. A recommended value is 100.
$blockSignSize,

		[Parameter()]
		[string]
# An absolute path that contains the colddbs for the index. The path must be readable and writable. Cold databases are opened as needed when searching. May be defined in terms of a volume definition.  Splunk will not start if an index lacks a valid coldPath.
$coldPath, 	
		
		[Parameter()]
		[string]
# Destination path for the frozen archive. Use as an alternative to a coldToFrozenScript. Splunk automatically puts frozen buckets in this directory.
		#		
		#Bucket freezing policy is as follows:
		#
		#New style buckets (4.2 and on): removes all files but the rawdata 
		#
		#To thaw, run splunk rebuild <bucket dir> on the bucket, then move to the thawed directory 
		#
		#Old style buckets (Pre-4.2): gzip all the .data and .tsidx files 
		#
		#To thaw, gunzip the zipped files and move the bucket into the thawed directory 
		#
		#If both coldToFrozenDir and coldToFrozenScript are specified, coldToFrozenDir takes precedence
$coldToFrozenDir,

		[Parameter()]
		[string] 
		# Path to the archiving script.  If your script requires a program to run it (for example, python), specify the program followed by the path. The script must be in $SPLUNK_HOME/bin or one of its subdirectories.  Splunk ships with an example archiving script in $SPLUNK_HOME/bin called coldToFrozenExample.py. Splunk DOES NOT recommend using this example script directly. It uses a default path, and if modified in place any changes will be overwritten on upgrade.  Splunk recommends copying the example script to a new file in bin and modifying it for your system. Most importantly, change the default archive path to an existing directory that fits your needs.  If your new script in bin/ is named myColdToFrozen.py, set this key to the following: "$SPLUNK_HOME/bin/python" "$SPLUNK_HOME/bin/myColdToFrozen.py".  By default, the example script has two possible behaviors when archiving:  For buckets created from version 4.2 and on, it removes all files except for rawdata. To thaw: cd to the frozen bucket and type splunk rebuild ., then copy the bucket to thawed for that index. We recommend using the coldToFrozenDir parameter unless you need to perform a more advanced operation upon freezing buckets.  For older-style buckets, we simply gzip all the .tsidx files. To thaw: cd to the frozen bucket and unzip the tsidx files, then copy the bucket to thawed for that index 
		$coldToFrozenScript,


		[Parameter()]
		[switch]
		# This parameter is ignored. The splunkd process always compresses raw data.
		$compressRawdata,

		[Parameter()]
		[int]
# Number of seconds after which indexed data rolls to frozen. Defaults to 188697600 (6 years).  Freezing data means it is removed from the index. If you need to archive your data, refer to coldToFrozenDir and coldToFrozenScript parameter documentation.
$frozenTimePeriodInSecs,

		[Parameter()]
		[string]
# An absolute path that contains the hot and warm buckets for the index.  Required. Splunk will not start if an index lacks a valid homePath.  CAUTION: Path MUST be readable and writable.
$homePath,

		[Parameter()]
		[int]
# The number of concurrent optimize processes that can run against a hot bucket.  This number should be increased if instructed by Splunk Support. Typically the default value should suffice.
$maxConcurrentOptimizes,

		[Parameter()]
		[string]
# The maximum size in MB for a hot DB to reach before a roll to warm is triggered. Specifying "auto" or "auto_high_volume" causes Splunk to autotune this parameter (recommended).Use "auto_high_volume" for high volume indexes (such as the main index); otherwise, use "auto". A "high volume index" would typically be considered one that gets over 10GB of data per day.  "auto" sets the size to 750MB.  "auto_high_volume" sets the size to 10GB on 64-bit, and 1GB on 32-bit systems.  Although the maximum value you can set this is 1048576 MB, which corresponds to 1 TB, a reasonable number ranges anywhere from 100 - 50000. Any number outside this range should be approved by Splunk Support before proceeding.  If you specify an invalid number or string, maxDataSize will be auto tuned.  NOTE: The precise size of your warm buckets may vary from maxDataSize, due to post-processing and timing issues with the rolling policy.
$maxDataSize,

		[Parameter()]
		[int]
# Maximum hot buckets that can exist per index. Defaults to 3.  When maxHotBuckets is exceeded, Splunk rolls the least recently used (LRU) hot bucket to warm. Both normal hot buckets and quarantined hot buckets count towards this total. This setting operates independently of maxHotIdleSecs, which can also cause hot buckets to roll.
$maxHotBuckets, 	

		[Parameter()]
		[int]
# Maximum life, in seconds, of a hot bucket. Defaults to 0.  If a hot bucket exceeds maxHotIdleSecs, Splunk rolls it to warm. This setting operates independently of maxHotBuckets, which can also cause hot buckets to roll. A value of 0 turns off the idle check (equivalent to INFINITE idle time).
$maxHotIdleSecs, 	

		[Parameter()]
		[int]
# Upper bound of target maximum timespan of hot/warm buckets in seconds. Defaults to 7776000 seconds (90 days).  NOTE: if you set this too small, you can get an explosion of hot/warm buckets in the filesystem. The system sets a lower bound implicitly for this parameter at 3600, but this is an advanced parameter that should be set with care and understanding of the characteristics of your data.
$maxHotSpanSecs,

		[Parameter()]
		[int]
# The amount of memory, expressed in MB, to allocate for buffering a single tsidx file into memory before flushing to disk. Defaults to 5. The default is recommended for all environments.  IMPORTANT: Calculate this number carefully. Setting this number incorrectly may have adverse effects on your systems memory and/or splunkd stability/performance.
$maxMemMB, 	

		[Parameter()]
		[int] 
		# Sets the maximum number of unique lines in .data files in a bucket, which may help to reduce memory consumption. If set to 0, this setting is ignored (it is treated as infinite).  If exceeded, a hot bucket is rolled to prevent further increase. If your buckets are rolling due to Strings.data hitting this limit, the culprit may be the punct field in your data. If you don't use punct, it may be best to simply disable this (see props.conf.spec in $SPLUNK_HOME/etc/system/README).  There is a small time delta between when maximum is exceeded and bucket is rolled. This means a bucket may end up with epsilon more lines than specified, but this is not a major concern unless excess is significant.
		$maxMetaEntries, 	
		
		[Parameter()]
		[int]
# The indexer fires off helper processes like splunk-optimize, recover-metadata, and others. This parameter controls how many processes the indexer fires off at any given time. CAUTION: This is an advanced parameter, do NOT set this unless instructed by Splunk Support.
$maxRunningProcessGroups, 	

		[Parameter()]
		[int]
# The maximum size of an index (in MB). If an index grows larger than the maximum size, the oldest data is frozen.
$maxTotalDataSizeMB, 	
		
		[Parameter()]
		[int]
# The maximum number of warm buckets. If this number is exceeded, the warm bucket/s with the lowest value for their latest times will be moved to cold.
$maxWarmDBCount, 	

		[Parameter()]
		[string]
# Specify an integer (or "disable") for this parameter.  This parameter sets how frequently splunkd forces a filesystem sync while compressing journal slices. During this interval, uncompressed slices are left on disk even after they are compressed. Then splunkd forces a filesystem sync of the compressed journal and removes the accumulated uncompressed files. If 0 is specified, splunkd forces a filesystem sync after every slice completes compressing. Specifying "disable" disables syncing entirely: uncompressed slices are removed as soon as compression is complete. NOTE: Some filesystems are very inefficient at performing sync operations, so only enable this if you are sure it is needed.
$minRawFileSyncSecs,

		[Parameter()]
		[int]
# Related to serviceMetaPeriod. If set, it enables metadata sync every <integer> seconds, but only for records where the sync can be done efficiently in-place, without requiring a full re-write of the metadata file. Records that require full re-write are be sync'ed at serviceMetaPeriod.  specifies, in seconds, how frequently it should sync. Zero means that this feature is turned off and serviceMetaPeriod is the only time when metadata sync happens.  If the value of partialServiceMetaPeriod is greater than serviceMetaPeriod, this setting has no effect.  By default it is turned off (zero).
$partialServiceMetaPeriod,

		[Parameter()]
		[int]
# Events with timestamp of quarantineFutureSecs newer than "now" are dropped into quarantine bucket. Defaults to 2592000 (30 days).  This is a mechanism to prevent main hot buckets from being polluted with fringe events.
$quarantineFutureSecs,

		[Parameter()]
		[int]
# Events with timestamp of quarantinePastSecs older than "now" are dropped into quarantine bucket. Defaults to 77760000 (900 days).  This is a mechanism to prevent the main hot buckets from being polluted with fringe events.
$quarantinePastSecs, 	

		[Parameter()]
		[int]
# Target uncompressed size in bytes for individual raw slice in the rawdata journal of the index. Defaults to 131072 (128KB). 0 is not a valid value. If 0 is specified, rawChunkSizeBytes is set to the default value.  NOTE: rawChunkSizeBytes only specifies a target chunk size. The actual chunk size may be slightly larger by an amount proportional to an individual event size.  WARNING: This is an advanced parameter. Only change it if you are instructed to do so by Splunk Support.
$rawChunkSizeBytes,
		
		[Parameter()]
		[int]
# How frequently (in seconds) to check if a new hot bucket needs to be created. Also, how frequently to check if there are any warm/cold buckets that should be rolled/frozen.
$rotatePeriodInSecs,

		[Parameter()]
		[int]
#Defines how frequently metadata is synced to disk, in seconds. Defaults to 25 (seconds). You may want to set this to a higher value if the sum of your metadata file sizes is larger than many tens of megabytes, to avoid the hit on I/O in the indexing fast path.
$serviceMetaPeriod,
		
		[Parameter()]
		[string[]]
# Specify a comma-separated list of indexes. This parameter suppresses index missing warning banner messages for the specified indexes. Defaults to empty.
$suppressBannerList, 	

		[Parameter()]
		[switch]
# When true, a sync operation is called before file descriptor is closed on metadata file updates. This functionality improves integrity of metadata files, especially in regards to operating system crashes/machine failures.  Do not change this parameter without the input of a Splunk Support.
$syncMeta = $true, 

		[Parameter()]
		[string]
# An absolute path that contains the thawed (resurrected) databases for the index.  Cannot be defined in terms of a volume definition.  Splunk will not start if an index lacks a valid thawedPath
$thawedPath, 	


		[Parameter()]
		[int]
#  	Defines how frequently Splunk checks for index throttling condition, in seconds. Defaults to 15 (seconds).  Do not change this parameter without the input of a Splunk Support. 	    
$throttleCheckPeriod,
       
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
		Write-Verbose " [New-SplunkIndex] :: Starting..."
        
	}
	Process
	{          
		Write-Verbose " [New-SplunkIndex] :: Parameters"
        Write-Verbose " [New-SplunkIndex] ::  - ParameterSet = $ParamSetName"
		$Arguments = @{};
		$nc = 'ComputerName','Port','Protocol','Timeout','Credential';
		
		$PSBoundParameters.Keys | foreach{
			Write-Verbose " [New-SplunkIndex] ::  - $_ = $PSBoundParameters[$_]"		
			if( $nc -notcontains $_ )
			{
				$arguments.Add( $_, $PSBoundParameters[$_] );
			}
		}
		        
		if( -not $pscmdlet.ShouldProcess( $ComputerName, "Creating new Splunk index named $Name" ) )
		{
			return;
		}
        
        Write-Verbose " [New-SplunkIndex] :: checking for existance of index"
        $InvokeAPIParams = @{
        			ComputerName = $ComputerName
        			Port         = $Port
        			Protocol     = $Protocol
        			Timeout      = $Timeout
        			Credential   = $Credential
                    name		 = $Name
                }
        $ExistingIndex = Get-SplunkIndex @InvokeAPIParams -erroraction 'silentlycontinue';
        
        if($ExistingIndex)
        {
            Write-Host " [New-SplunkIndex] :: Index [$Name] already exists: [ $($ExistingIndex.ServiceEndpoint) ]"
            Return
        }

		Write-Verbose " [New-SplunkIndex] :: Setting up Invoke-APIRequest parameters"
		$InvokeAPIParams = @{
			ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
			Endpoint 	 = '/services/data/indexes'
			Verbose      = $VerbosePreference -eq "Continue"
		}
        	
		Write-Verbose " [New-SplunkIndex] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
		try
		{
		    [XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams -Arguments $Arguments -RequestType POST 
        }
		catch
		{
			Write-Verbose " [New-SplunkIndex] :: Invoke-SplunkAPIRequest threw an exception: $_"
            Write-Error $_;

			return;
		}
        try
        {
			Write-Verbose " [New-SplunkIndex] :: Checking for valid results"
			if($Results -and ($Results -is [System.Xml.XmlDocument]))
			{
				Write-Verbose " [New-SplunkIndex] :: Fetching index $name"
                $InvokeAPIParams = @{
        			ComputerName = $ComputerName
        			Port         = $Port
        			Protocol     = $Protocol
        			Timeout      = $Timeout
        			Credential   = $Credential
                    name		 = $Name
                }
                Get-SplunkIndex @InvokeAPIParams
			}
			else
			{
				Write-Verbose " [New-SplunkIndex] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
			}
		}
		catch
		{
			Write-Verbose " [New-SplunkIndex] :: New-SplunkIndex threw an exception: $_"
            Write-Error $_
		}
	}
	End
	{
		Write-Verbose " [New-SplunkIndex] :: =========    End   ========="
	}
} # New-SplunkIndex

#endregion

#region Set-SplunkIndex

function Set-SplunkIndex
{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[Cmdletbinding(SupportsShouldProcess=$true)]
    Param(
	
		[Parameter(Mandatory=$true)]
		[Alias("Index","IndexName")]
		[string] 
		# The name of the index to update.
		$name,
		
		[Parameter()]
		[switch]
# Verifies that all data retreived from the index is proper UTF8.  Will degrade indexing performance when enabled (set to true).
$assureUTF8, 	

		[Parameter()]
		[int]
# Controls how many events make up a block for block signatures.  If this is set to 0, block signing is disabled for this index. A recommended value is 100.
$blockSignSize,

		[Parameter()]
		[string]
# Destination path for the frozen archive. Use as an alternative to a coldToFrozenScript. Splunk automatically puts frozen buckets in this directory.
		#		
		#Bucket freezing policy is as follows:
		#
		#New style buckets (4.2 and on): removes all files but the rawdata 
		#
		#To thaw, run splunk rebuild <bucket dir> on the bucket, then move to the thawed directory 
		#
		#Old style buckets (Pre-4.2): gzip all the .data and .tsidx files 
		#
		#To thaw, gunzip the zipped files and move the bucket into the thawed directory 
		#
		#If both coldToFrozenDir and coldToFrozenScript are specified, coldToFrozenDir takes precedence
$coldToFrozenDir,

		[Parameter()]		
		[string] 
		# Path to the archiving script.  If your script requires a program to run it (for example, python), specify the program followed by the path. The script must be in $SPLUNK_HOME/bin or one of its subdirectories.  Splunk ships with an example archiving script in $SPLUNK_HOME/bin called coldToFrozenExample.py. Splunk DOES NOT recommend using this example script directly. It uses a default path, and if modified in place any changes will be overwritten on upgrade.  Splunk recommends copying the example script to a new file in bin and modifying it for your system. Most importantly, change the default archive path to an existing directory that fits your needs.  If your new script in bin/ is named myColdToFrozen.py, set this key to the following: "$SPLUNK_HOME/bin/python" "$SPLUNK_HOME/bin/myColdToFrozen.py".  By default, the example script has two possible behaviors when archiving:  For buckets created from version 4.2 and on, it removes all files except for rawdata. To thaw: cd to the frozen bucket and type splunk rebuild ., then copy the bucket to thawed for that index. We recommend using the coldToFrozenDir parameter unless you need to perform a more advanced operation upon freezing buckets.  For older-style buckets, we simply gzip all the .tsidx files. To thaw: cd to the frozen bucket and unzip the tsidx files, then copy the bucket to thawed for that index 
		$coldToFrozenScript,


		[Parameter()]
		[switch]
# This parameter is ignored. The splunkd process always compresses raw data.
$compressRawdata,

		[Parameter()]
		[int]
# Number of seconds after which indexed data rolls to frozen. Defaults to 188697600 (6 years).  Freezing data means it is removed from the index. If you need to archive your data, refer to coldToFrozenDir and coldToFrozenScript parameter documentation.
$frozenTimePeriodInSecs,

		[Parameter()]
		[string]
# An absolute path that contains the hot and warm buckets for the index.  Required. Splunk will not start if an index lacks a valid homePath.  CAUTION: Path MUST be readable and writable.
$homePath,

		[Parameter()]
		[int]
# The number of concurrent optimize processes that can run against a hot bucket.  This number should be increased if instructed by Splunk Support. Typically the default value should suffice.
$maxConcurrentOptimizes,

		[Parameter()]
		[string]
# The maximum size in MB for a hot DB to reach before a roll to warm is triggered. Specifying "auto" or "auto_high_volume" causes Splunk to autotune this parameter (recommended).Use "auto_high_volume" for high volume indexes (such as the main index); otherwise, use "auto". A "high volume index" would typically be considered one that gets over 10GB of data per day.  "auto" sets the size to 750MB.  "auto_high_volume" sets the size to 10GB on 64-bit, and 1GB on 32-bit systems.  Although the maximum value you can set this is 1048576 MB, which corresponds to 1 TB, a reasonable number ranges anywhere from 100 - 50000. Any number outside this range should be approved by Splunk Support before proceeding.  If you specify an invalid number or string, maxDataSize will be auto tuned.  NOTE: The precise size of your warm buckets may vary from maxDataSize, due to post-processing and timing issues with the rolling policy.
$maxDataSize,

		[Parameter()]
		[int]
# Maximum hot buckets that can exist per index. Defaults to 3.  When maxHotBuckets is exceeded, Splunk rolls the least recently used (LRU) hot bucket to warm. Both normal hot buckets and quarantined hot buckets count towards this total. This setting operates independently of maxHotIdleSecs, which can also cause hot buckets to roll.
$maxHotBuckets, 	

		[Parameter()]
		[int]
# Maximum life, in seconds, of a hot bucket. Defaults to 0.  If a hot bucket exceeds maxHotIdleSecs, Splunk rolls it to warm. This setting operates independently of maxHotBuckets, which can also cause hot buckets to roll. A value of 0 turns off the idle check (equivalent to INFINITE idle time).
$maxHotIdleSecs, 	

		[Parameter()]
		[int]
# Upper bound of target maximum timespan of hot/warm buckets in seconds. Defaults to 7776000 seconds (90 days).  NOTE: if you set this too small, you can get an explosion of hot/warm buckets in the filesystem. The system sets a lower bound implicitly for this parameter at 3600, but this is an advanced parameter that should be set with care and understanding of the characteristics of your data.
$maxHotSpanSecs,

		[Parameter()]
		[int]
# The amount of memory, expressed in MB, to allocate for buffering a single tsidx file into memory before flushing to disk. Defaults to 5. The default is recommended for all environments.  IMPORTANT: Calculate this number carefully. Setting this number incorrectly may have adverse effects on your systems memory and/or splunkd stability/performance.
$maxMemMB, 	

		[Parameter()]
		[int] 
		# Sets the maximum number of unique lines in .data files in a bucket, which may help to reduce memory consumption. If set to 0, this setting is ignored (it is treated as infinite).  If exceeded, a hot bucket is rolled to prevent further increase. If your buckets are rolling due to Strings.data hitting this limit, the culprit may be the punct field in your data. If you don't use punct, it may be best to simply disable this (see props.conf.spec in $SPLUNK_HOME/etc/system/README).  There is a small time delta between when maximum is exceeded and bucket is rolled. This means a bucket may end up with epsilon more lines than specified, but this is not a major concern unless excess is significant.
		$maxMetaEntries, 	
		
		[Parameter()]
		[int]
# The indexer fires off helper processes like splunk-optimize, recover-metadata, and others. This parameter controls how many processes the indexer fires off at any given time. CAUTION: This is an advanced parameter, do NOT set this unless instructed by Splunk Support.
$maxRunningProcessGroups, 	

		[Parameter()]
		[int]
# The maximum size of an index (in MB). If an index grows larger than the maximum size, the oldest data is frozen.
$maxTotalDataSizeMB, 	
		
		[Parameter()]
		[int]
# The maximum number of warm buckets. If this number is exceeded, the warm bucket/s with the lowest value for their latest times will be moved to cold.
$maxWarmDBCount, 	

		[Parameter()]
		[string]
# Specify an integer (or "disable") for this parameter.  This parameter sets how frequently splunkd forces a filesystem sync while compressing journal slices. During this interval, uncompressed slices are left on disk even after they are compressed. Then splunkd forces a filesystem sync of the compressed journal and removes the accumulated uncompressed files. If 0 is specified, splunkd forces a filesystem sync after every slice completes compressing. Specifying "disable" disables syncing entirely: uncompressed slices are removed as soon as compression is complete. NOTE: Some filesystems are very inefficient at performing sync operations, so only enable this if you are sure it is needed.
$minRawFileSyncSecs,

		[Parameter()]
		[int]
# Related to serviceMetaPeriod. If set, it enables metadata sync every <integer> seconds, but only for records where the sync can be done efficiently in-place, without requiring a full re-write of the metadata file. Records that require full re-write are be sync'ed at serviceMetaPeriod.  specifies, in seconds, how frequently it should sync. Zero means that this feature is turned off and serviceMetaPeriod is the only time when metadata sync happens.  If the value of partialServiceMetaPeriod is greater than serviceMetaPeriod, this setting has no effect.  By default it is turned off (zero).
$partialServiceMetaPeriod,

		[Parameter()]
		[int]
# Events with timestamp of quarantineFutureSecs newer than "now" are dropped into quarantine bucket. Defaults to 2592000 (30 days).  This is a mechanism to prevent main hot buckets from being polluted with fringe events.
$quarantineFutureSecs,

		[Parameter()]
		[int]
# Events with timestamp of quarantinePastSecs older than "now" are dropped into quarantine bucket. Defaults to 77760000 (900 days).  This is a mechanism to prevent the main hot buckets from being polluted with fringe events.
$quarantinePastSecs, 	

		[Parameter()]
		[int]
# Target uncompressed size in bytes for individual raw slice in the rawdata journal of the index. Defaults to 131072 (128KB). 0 is not a valid value. If 0 is specified, rawChunkSizeBytes is set to the default value.  NOTE: rawChunkSizeBytes only specifies a target chunk size. The actual chunk size may be slightly larger by an amount proportional to an individual event size.  WARNING: This is an advanced parameter. Only change it if you are instructed to do so by Splunk Support.
$rawChunkSizeBytes,
		
		[Parameter()]
		[int]
# How frequently (in seconds) to check if a new hot bucket needs to be created. Also, how frequently to check if there are any warm/cold buckets that should be rolled/frozen.
$rotatePeriodInSecs,

		[Parameter()]
		[int]
#Defines how frequently metadata is synced to disk, in seconds. Defaults to 25 (seconds). You may want to set this to a higher value if the sum of your metadata file sizes is larger than many tens of megabytes, to avoid the hit on I/O in the indexing fast path.
$serviceMetaPeriod,
		
		[Parameter()]
		[string[]]
# Specify a comma-separated list of indexes. This parameter suppresses index missing warning banner messages for the specified indexes. Defaults to empty.
$suppressBannerList, 	

		[Parameter()]
		[switch]
# When true, a sync operation is called before file descriptor is closed on metadata file updates. This functionality improves integrity of metadata files, especially in regards to operating system crashes/machine failures.  Do not change this parameter without the input of a Splunk Support.
$syncMeta = $true, 

		[Parameter()]
		[int]
#  	Defines how frequently Splunk checks for index throttling condition, in seconds. Defaults to 15 (seconds).  Do not change this parameter without the input of a Splunk Support. 	    
$throttleCheckPeriod,
       
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
		Write-Verbose " [Set-SplunkIndex] :: Starting..."
        
	}
	Process
	{          
		Write-Verbose " [Set-SplunkIndex] :: Parameters"
        Write-Verbose " [Set-SplunkIndex] ::  - ParameterSet = $ParamSetName"
		$PSBoundParameters.Keys | foreach{
			Write-Verbose " [Set-SplunkIndex] ::  - $_ = $($PSBoundParameters[$_])"		
		}
		$Arguments = @{};
		$nc = 'ComputerName','Port','Protocol','Timeout','Credential';
		$fields = data {
			'assureUTF8'
			'blockSignSize'
			'coldToFrozenDir'
			'coldToFrozenScript'
			'compressRawdata'
			'frozenTimePeriodInSecs'
			'maxConcurrentOptimizes'
			'maxDataSize'
			'maxHotBuckets'
			'maxHotIdleSecs'
			'maxHotSpanSecs'
			'maxMemMB'
			'maxMetaEntries'
			'maxRunningProcessGroups'
			'maxTotalDataSizeMB'
			'maxWarmDBCount'
			'minRawFileSyncSecs'
			'partialServiceMetaPeriod'
			'quarantineFutureSecs'
			'quarantinePastSecs'
			'rawChunkSizeBytes'
			'rotatePeriodInSecs'
			'serviceMetaPeriod'
			'suppressBannerList'
			'syncMeta'
			'throttleCheckPeriod'
		};
		        
        Write-Verbose " [Set-SplunkIndex] :: checking for existance of index"
        $InvokeAPIParams = @{
        			ComputerName = $ComputerName
        			Port         = $Port
        			Protocol     = $Protocol
        			Timeout      = $Timeout
        			Credential   = $Credential
                    name		 = $Name
                }
        $ExistingIndex = Get-SplunkIndex @InvokeAPIParams -erroraction 'silentlycontinue';
        
        if(-not $ExistingIndex)
        {
            Write-Host " [Set-SplunkIndex] :: Index [$Name] does not exist and cannot be updated"
            Return
        }

		if( -not $pscmdlet.ShouldProcess( $ComputerName, "Updating Splunk index named $Name" ) )
		{
			return;
		}
		
		$intParams =  'assureUTF8, compressRawdata, disabled, enableRealtimeSearch, isInternal, sync,blockSignSize, currentDBSizeMB, frozenTimePeriodInSecs, maxConcurrentOptimizes, maxHotBuckets, maxHotIdleSecs, maxHitSpanSecs, maxMemDB, maxMetaEntries,' +
			'maxRunningProcessGroups, maxTotalDataSizeMB, maxWarmDBCount, partialServiceMetaPeriod, quarantineFutureSecs, quarantinePastSecs, rawChuckSizeBytes,' +
			'rotatePeriodInSecs, serviceMetaPeriod, throttleCheckPeriod, totalEventCount' -split '\s*,\s*';
							
		$fields | foreach{			
			if( $nc -notcontains $_ )
			{
				if( $PSBoundParameters.ContainsKey($_) )
				{
					$value = $PSBoundParameters[$_];
				}
				else
				{
					$value = $ExistingIndex.$_;
				}
													
		        switch ($_)
		        {		
		            { $intParams -contains $_ }            { $Arguments[$_] = [int]$value; continue }
		            Default                                { $Arguments[$_] = $value; continue }
		        }
				
				Write-Verbose " [Set-SplunkIndex] ::  updating property $_ = $($ExistingIndex.$_) ; $($PSBoundParameters[$_]); $($Arguments[$_])"		
			}
		}


		Write-Verbose "Updated index parameters: $arguments";
		
		Write-Verbose " [Set-SplunkIndex] :: Setting up Invoke-APIRequest parameters"
		$InvokeAPIParams = @{
			ComputerName = $ComputerName
			Port         = $Port
			Protocol     = $Protocol
			Timeout      = $Timeout
			Credential   = $Credential
			Endpoint 	 = "/services/data/indexes/$Name"
			Verbose      = $VerbosePreference -eq "Continue"
		}
        	
		Write-Verbose " [Set-SplunkIndex] :: Calling Invoke-SplunkAPIRequest @InvokeAPIParams"
		try
		{
		    [XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams -Arguments $Arguments -RequestType POST 
        }
		catch
		{
			Write-Verbose " [Set-SplunkIndex] :: Invoke-SplunkAPIRequest threw an exception: $_"
            Write-Error $_;

			return;
		}
        try
        {
			Write-Verbose " [Set-SplunkIndex] :: Checking for valid results"
			if($Results -and ($Results -is [System.Xml.XmlDocument]))
			{
				Write-Verbose " [Set-SplunkIndex] :: Fetching index $name"
                $InvokeAPIParams = @{
        			ComputerName = $ComputerName
        			Port         = $Port
        			Protocol     = $Protocol
        			Timeout      = $Timeout
        			Credential   = $Credential
                    name		 = $Name
                }
                Get-SplunkIndex @InvokeAPIParams
			}
			else
			{
				Write-Verbose " [Set-SplunkIndex] :: No Response from REST API. Check for Errors from Invoke-SplunkAPIRequest"
			}
		}
		catch
		{
			Write-Verbose " [Set-SplunkIndex] :: Set-SplunkIndex threw an exception: $_"
            Write-Error $_
		}
	}
	End
	{
		Write-Verbose " [Set-SplunkIndex] :: =========    End   ========="
	}
} # Set-SplunkIndex

#endregion

#region Disable-SplunkIndex

function Disable-SplunkIndex
{
	<# .ExternalHelp ../Splunk-Help.xml #>

	[CmdletBinding(DefaultParameterSetName='byFilter', SupportsShouldProcess=$true)]
    Param(

		[Parameter(Position=0,ParameterSetName='byFilter')]
		[string]
#Regular expression used to match index name
$Filter = '.*',
		
		[Parameter(Position=0,ParameterSetName='byName',Mandatory=$true)]
		[string]
#Boolean predicate to filter results
$Name,
		
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
		$Credential = ( get-splunkconnectionobject ).Credential,		
		
		[Parameter()]
		[Switch] 
		# Specify to bypass standard PowerShell confirmation processes
		$Force
        
    )
	Begin 
	{
	        Write-Verbose " [Get-SplunkIndex] :: Starting..."	        
	}
	Process
	{          
		Write-Verbose " [Disable-SplunkIndex] :: Parameters"
        Write-Verbose " [Disable-SplunkIndex] ::  - ParameterSet = $ParamSetName"
		$PSBoundParameters.Keys | foreach{
			Write-Verbose " [Disable-SplunkIndex] ::  - $_ = $($PSBoundParameters[$_])"		
		}

		try
		{
			$items = get-splunkIndex @PSBoundParameters;
			$items | ? { -not $_.disabled } | foreach {
				if( $force -or $pscmdlet.ShouldProcess( $ComputerName, "Disabling Splunk index named $($_.Name)" ) )
				{
					Write-Verbose " [Disable-SplunkIndex] :: Setting up Invoke-APIRequest parameters"
					$InvokeAPIParams = @{
						ComputerName = $ComputerName
						Port         = $Port
						Protocol     = $Protocol
						Timeout      = $Timeout
						Credential   = $Credential
						Endpoint 	 = "/services/data/indexes/$($_.Name)/disable"
						Verbose      = $VerbosePreference -eq "Continue"
					}
			        	
					Write-Verbose " [Disable-SplunkIndex] :: Calling Invoke-SplunkAPIRequest $InvokeAPIParams"
					try
					{
					    [XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams -RequestType POST -Arguments @{}
			        }
					catch
					{
						Write-Verbose " [Disable-SplunkIndex] :: Invoke-SplunkAPIRequest threw an exception: $_"
			            Write-Error $_;

						return;
					}
				}
			}
			
			get-splunkIndex @PSBoundParameters;							
		}
		catch
		{
			Write-Verbose " [Disable-SplunkIndex] :: Disable-SplunkIndex threw an exception: $_"
            Write-Error $_
		}
	}
	End
	{
		Write-Verbose " [Disable-SplunkIndex] :: =========    End   ========="
	}
} # Disable-SplunkIndex

#endregion

#region Enable-SplunkIndex

function Enable-SplunkIndex
{
	<# .ExternalHelp ../Splunk-Help.xml #>
	[CmdletBinding(DefaultParameterSetName='byFilter', SupportsShouldProcess=$true)]
    Param(

		[Parameter(Position=0,ParameterSetName='byFilter')]
		[string]
#Regular expression used to match index name
$Filter = '.*',
		
		[Parameter(Position=0,ParameterSetName='byName',Mandatory=$true)]
		[string]
#Boolean predicate to filter results
$Name,
		
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
		$Credential = ( get-splunkconnectionobject ).Credential,
		
		[Parameter()]
		[Switch] 
		# Specify to bypass standard PowerShell confirmation processes
		$Force
        
    )
	Begin 
	{
	        Write-Verbose " [Get-SplunkIndex] :: Starting..."	        
	}
	Process
	{          
		Write-Verbose " [Enable-SplunkIndex] :: Parameters"
        Write-Verbose " [Enable-SplunkIndex] ::  - ParameterSet = $ParamSetName"
		$PSBoundParameters.Keys | foreach{
			Write-Verbose " [Enable-SplunkIndex] ::  - $_ = $($PSBoundParameters[$_])"		
		}

		try
		{
			$items = get-splunkIndex @PSBoundParameters;
			$items | where { 1 -eq $_.disabled } | foreach {
				
				if( $force -or $pscmdlet.ShouldProcess( $ComputerName, "Enabling Splunk index named $($_.Name)" ) )
				{
					Write-Verbose " [Enable-SplunkIndex] :: Setting up Invoke-APIRequest parameters"
					$InvokeAPIParams = @{
						ComputerName = $ComputerName
						Port         = $Port
						Protocol     = $Protocol
						Timeout      = $Timeout
						Credential   = $Credential
						Endpoint 	 = "/services/data/indexes/$($_.Name)/enable"
						Verbose      = $VerbosePreference -eq "Continue"
					}
			        	
					Write-Verbose " [Enable-SplunkIndex] :: Calling Invoke-SplunkAPIRequest $InvokeAPIParams"
					try
					{
					    [XML]$Results = Invoke-SplunkAPIRequest @InvokeAPIParams -RequestType POST -Arguments @{}
			        }
					catch
					{
						Write-Verbose " [Enable-SplunkIndex] :: Invoke-SplunkAPIRequest threw an exception: $_"
			            Write-Error $_;

						return;
					}
				}
				
				$getIndexParams = @{
					ComputerName = $ComputerName
					Port         = $Port
					Protocol     = $Protocol
					Timeout      = $Timeout
					Credential   = $Credential
					name		 = $_.Name
				}
				# get-splunkIndex @getIndexParams
			}
			
			get-splunkIndex @PSBoundParameters;
		}
		catch
		{
			Write-Verbose " [Enable-SplunkIndex] :: Enable-SplunkIndex threw an exception: $_"
            Write-Error $_
		}
	}
	End
	{
		Write-Verbose " [Enable-SplunkIndex] :: =========    End   ========="
	}
} # Enable-SplunkIndex

#endregion

#endregion Index

