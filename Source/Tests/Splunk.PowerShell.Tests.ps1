param( $fixture )

Get-Command -Module splunk | foreach {
	$script:this = $_;
	Describe "Splunk Module" {		
		It "$($script:this.Name) has custom help" {
			$script:this | Write-Debug;
			$local:help = ( $script:this | Get-Help -full ) | Out-String;
			
			$local:help -match 'NAME' -and
				$local:help -match 'SYNOPSIS' -and
				$local:help -match 'SYNTAX' -and
				$local:help -match 'DESCRIPTION' -and
				$local:help -match 'EXAMPLE';
		}

	}
}