
param( $fixture )

Describe "enable-splunkServerClass" {

	function get-disabledServerClass
	{
		$local:sc = Get-SplunkServerClass | where {$_.disabled};
		if( -not $local:sc )
		{
			$local:sc = Get-SplunkServerClass;
		}
		
		$local:sc = @($local:sc)[ @($local:sc).length - 1 ];
		
		if( -not $local:sc.disabled )
		{
			$local:sc = $local:sc | Disable-SplunkServerClass;
		}
		$local:sc;
	}
	
	It "accepts server class object as pipeline input" {
		$local:sc = get-disabledServerClass;	
		$local:sc = $local:sc | enable-SplunkServerClass;
		return -not $local:sc.disabled;
	}
	
	It "accepts server class object by name" {
		$local:sc = get-disabledServerClass;	
		$local:sc = enable-SplunkServerClass -Name $local:sc.Name;
		return -not $local:sc.disabled;
	}
	
	It "accepts filter of server class object" {
		$local:sc = get-disabledServerClass;	
		$local:sc = enable-SplunkServerClass -Filter $local:sc.Name
		return -not $local:sc.disabled;
	}

}

Describe "disable-splunkServerClass" {

	function get-enabledServerClass
	{
		$local:sc = Get-SplunkServerClass | where { -not $_.disabled };
		if( -not $local:sc )
		{
			$local:sc = Get-SplunkServerClass;
		}
		
		$local:sc = @($local:sc)[ @($local:sc).length - 1 ];
		
		if( $local:sc.disabled )
		{
			$local:sc = $local:sc | enable-SplunkServerClass;
		}
		$local:sc;
	}
	
	It "accepts server class object as pipeline input" {
		$local:sc = get-enabledServerClass;	
		$local:sc = $local:sc | disable-SplunkServerClass;
		return $local:sc.disabled;
	}
	
	It "accepts server class object by name" {
		$local:sc = get-enabledServerClass;	
		$local:sc = disable-SplunkServerClass -Name $local:sc.Name;
		return $local:sc.disabled;
	}
	
	It "accepts filter of server class object" {
		$local:sc = get-enabledServerClass;	
		$local:sc = disable-SplunkServerClass -Filter $local:sc.Name
		return $local:sc.disabled;
	}

}