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

function Get-Splunk
{
    <# .ExternalHelp Splunk-Help.xml #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Verb = "*",
        [Parameter()]
        [string]$noun = "*"
    )


    Process
    {
        Get-Command -Module Splunk* -Verb $verb -noun $noun
    }#Process

} # Get-Splunk


#region Helper cmdlets

#region ConvertFrom-UnixTime

function ConvertFrom-UnixTime
{
	<# .ExternalHelp Splunk-Help.xml #>
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
	<# .ExternalHelp Splunk-Help.xml #>
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
	<# .ExternalHelp Splunk-Help.xml #>
	[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
}

#endregion Disable-CertificateValidation

#region Enable-CertificateValidation

function Enable-CertificateValidation
{
	<# .ExternalHelp Splunk-Help.xml #>
	[System.Net.ServicePointManager]::ServerCertificateValidationCallback = $Null
}

#endregion Enable-CertificateValidation

#region Export-SplunkConnectionObject

function Export-SplunkConnectionObject
{
	<# .ExternalHelp Splunk-Help.xml #>

    [cmdletbinding()]
	Param(
		[Parameter()]
		$Path = "$SplunkModuleHome\SplunkConnectionObject.xml",
        
        [Parameter()]
        [SWITCH]$Force
	)
    
    Write-Verbose " [Export-SplunkConnectionObject] :: Starting"
	
    if((Test-Path $Path) -and (-not $Force))
    {
        Write-Host " [Export-SplunkConnectionObject] :: $Path already exists. Please remove or use -Force."
    }
    else
    {
        Write-Verbose " [Export-SplunkConnectionObject] :: Exporting Module Configuration to $Path"
        $SplunkDefaultConnectionObject | Export-Clixml -Path $Path
        Get-Item $Path
    }
	
}

#endregion Export-SplunkConnectionObject

#region Import-SplunkConnectionObject

function Import-SplunkConnectionObject
{
	<# .ExternalHelp Splunk-Help.xml #>
    [cmdletbinding()]
	Param(
		[Parameter()]
		$Path = "$SplunkModuleHome\SplunkConnectionObject.xml",
        
        [Parameter()]
        [SWITCH]$Force
	)
	
    Write-Verbose " [Import-SplunkConnectionObject] :: Starting"
    
    if($SplunkDefaultConnectionObject -and !$Force)
    {
        Write-Host " [Import-SplunkConnectionObject] :: `$SplunkDefaultConnectionObject already exists. Use -Force to overwrite."
    }
    else
    {
    	Write-Verbose " [Import-SplunkConnectionObject] :: Importing Configuration from $Path"
    	$OldObject = Import-Clixml -Path $Path
    	
    	Write-Verbose " [Import-SplunkConnectionObject] :: Creating Credential Object"
    	$UserName = $OldObject.UserName
    	$Password = ConvertTo-SecureString $OldObject.Password
    	$MyCredential = New-Object System.Management.Automation.PSCredential($UserName,$Password)
    	
    	Write-Verbose " [Import-SplunkConnectionObject] :: Calling Connect-Splunk"
    	Connect-Splunk -ComputerName $OldObject.ComputerName -Credentials $MyCredential
    }
	
}

#endregion Import-SplunkConnectionObject

#region Set-SplunkConnectionObject

function Set-SplunkConnectionObject
{
	<# .ExternalHelp Splunk-Help.xml #>

    [cmdletbinding()]
	Param(
		[Parameter(Mandatory=$True)]
		[PSCustomObject]$ConnectionObject,
        
        [Parameter()]
        [SWITCH]$Force
	)
	
	Write-Verbose " **********************************************"
	Write-Verbose " **********************************************"
	Write-Verbose " **********************************************"
    Write-Verbose " [Set-SplunkConnectionObject] :: Starting...."
    
    if($Force -or (!$script:SplunkDefaultConnectionObject))
    {
        if($ConnectionObject.PSTypeNames -contains 'Splunk.SDK.Connection')
        {
            Write-Verbose " [Set-SplunkConnectionObject] :: Setting `$SplunkDefaultConnectionObject to $ConnectionObject"
            $script:SplunkDefaultConnectionObject = $ConnectionObject
        }
        else
        {
             Write-Host " [Set-SplunkConnectionObject] :: Wrong type of Object passed" -ForegroundColor Red
        }
    }
    else
    {
        Write-Host " [Set-SplunkConnectionObject] :: `$SplunkDefaultConnectionObject already exists. Use -Force to overwrite."
    }
}

#endregion Set-SplunkConnectionObject 

#region Get-SplunkConnectionObject

function Get-SplunkConnectionObject
{
	<# .ExternalHelp Splunk-Help.xml #>

    [cmdletbinding()]
	Param(
		[Parameter()]
		$Path = "$SplunkModuleHome\SplunkConnectionObject.xml",
        
        [Parameter()]
        [SWITCH]$Force
	)
	
    Write-Verbose " [Get-SplunkConnectionObject] :: Starting...."
    
    if( -not $script:SplunkDefaultConnectionObject )
	{
		Write-Verbose " [Get-SplunkConnectionObject] :: returning empty object"
		return new-object psobject;
	}
	
	$script:SplunkDefaultConnectionObject
}

#endregion Get-SplunkConnectionObject

#region Remove-SplunkConnectionObject

function Remove-SplunkConnectionObject
{
	<# .ExternalHelp Splunk-Help.xml #>
    [cmdletbinding(SupportsShouldProcess=$True,ConfirmImpact='High')]
	Param(
        [Parameter()]
        [SWITCH]$Force
	)
	
    Write-Verbose " [Remove-SplunkConnectionObject] :: Starting..."
    
    if($Force -or $PSCmdlet.ShouldProcess($SplunkDefaultConnectionObject.AuthToken,"Removing Default Connection Object"))
	{
        $script:SplunkDefaultConnectionObject = $null
	}
}

#endregion Remove-SplunkConnectionObject

#endregion Helper cmdlets

# Adding System.Web namespace
Add-Type -AssemblyName System.Web 

New-Variable -Name SplunkModuleHome              -Value $psScriptRoot -Scope Global -Force
New-Variable -Name SplunkDefaultConnectionObject -Value $null -Scope Script

# code to load scripts
Get-ChildItem $SplunkModuleHome *.ps1xml -Recurse | foreach-object{ Update-FormatData $_.fullname -ea 0 } 
Get-ChildItem $SplunkModuleHome -Filter Splunk-*  | where{$_.PSisContainer} | foreach{Import-Module $_.FullName }
