function global:reset-connection
{
	Write-Debug 'creating default splunk object using connect-splunk';
	Disable-CertificateValidation;
	$global:SplunkDefaultObject = Connect-Splunk -ComputerName $script:fixture.splunkServer -Credentials $script:fixture.splunkAdminCredentials;
}
function global:verify-all( $value = $true )
{
	begin
	{
		$local:a = @();
	}
	process
	{
		$local:a += $input;
	}	
	end
	{
		if( $value -and -not $local:a )
		{
			return $false;
		}
		
		foreach( $aa in $local:a )
		{
			if( $aa -ne $value )
			{
				return $false;
			}
		}
		return $true;
	}
}

function global:verify-results
{
	[CmdletBinding()]
	param(
		[Parameter(ValueFromPipeline=$true)] $results, 
		[Parameter()]
		[String[]] $fields
	);
	
	process
	{
		$local:resultFields = $results | Get-Member -membertype properties | foreach{ $_.name };
		if( $fields | where{ $local:resultFields -notcontains $_ } )
		{
			return $false;
		}
		
		return $true;
	}
}

function global:compare-objectProperties( $a, $b )
{
	if( -not( $a -and $b ) )
	{
		return $false;
	}
	
	$local:scNames = $a | get-member -membertype Properties | foreach{ $_.Name };
	$local:scNames | Write-Debug;
	
	$b | Get-Member -MemberType Properties | foreach {
		$local:key = $_.name;
		Write-Debug "processing $($_.name)";
		$local:result = $local:scNames -contains $local:key; 
		if( -not $local:result )
		{
			Write-Debug "$local:key is not in list of property names";
			$false;
		}
		else
		{
			write-debug ($b."$local:key" -eq $a."$local:key")
			$b."$local:key" -eq $a."$local:key";
		}
	};
}