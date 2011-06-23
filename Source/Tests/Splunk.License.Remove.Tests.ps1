param( $fixture )

Describe "remove-splunkLicenseFile" {

	$trialLicenseLabel = 'Splunk Enterprise Download Trial'
	$trialLicenseXml = @'
<license>
  <signature>ORjrS0GsHtQ/SlxeVazPI/TnOUJtw2w7ItW0ni6ovwFAwhvI8Q5Gfzg2jsz0nBvDyDv9vUzehN7CRpxm9GsLyntGjKoZzq7Pi+RAU3HEOFGWNPexf5e3uMMt4PD/okxkLjwlOVBxJaSd939cufIl1h0OsHcZ2jNye/pyqAjWY6qsP5f4ZR0a4uiuq20wo5VyWHI7T3YgRzfrQqjx9oN+Ad6UOKOvfkz7gzIA+cfGapZOI/R+J33WlYPb34S0ThToGQZc04q12PCPXn1L0zPBtchRUtlgBq8HuRaNMjcmaqFxUcn0EzRpGzVOH313g41Fz8n8Q8ZylMMFir+tpuTn8Q==</signature>
  <payload>
    <type>download-trial</type>
    <group_id>Trial</group_id>
    <quota>524288000</quota>
    <max_violations>5</max_violations>
    <window_period>30</window_period>
    <creation_time>1308038408</creation_time>
    <expiration_time>1313827208</expiration_time>
    <label>Splunk Enterprise Download Trial</label>
    <features>
      <feature>Auth</feature>
      <feature>FwdData</feature>
      <feature>RcvData</feature>
      <feature>LocalSearch</feature>
      <feature>DistSearch</feature>
      <feature>RcvSearch</feature>
      <feature>ScheduledSearch</feature>
      <feature>Alerting</feature>
      <feature>DeployClient</feature>
      <feature>DeployServer</feature>
      <feature>SplunkWeb</feature>
      <feature>SigningProcessor</feature>
      <feature>SyslogOutputProcessor</feature>
      <feature>AllowDuplicateKeys</feature>
    </features>
    <sourcetypes/>
    <guid>B0CE9D18-3272-41B8-94E3-76848AFC7F89</guid>
  </payload>
</license>
'@;
		
	function reset-TrialLicense
	{
		if( get-splunkLicenseFile -all | where{ $_.label -eq $trialLicenseLabel } )
		{
			return;
		}

		Write-Debug 'Resetting trial license file because it does not exist'
		add-SplunkLicenseFile -Name $trialLicenseLabel -payload $trialLicenseXml | Out-Null;				
	}

	It "removes enterprise trial license" {
		try
		{
			reset-TrialLicense;
			
			$pre = get-splunkLicenseFile -all | where{ $_.label -eq $trialLicenseLabel }
			
			$pre.Hash | Remove-SplunkLicenseFile;
			
			$post = get-splunkLicenseFile -all | where{ $_.label -eq $trialLicenseLabel }
			
			$pre -and -not $post
		}
		finally
		{
			reset-TrialLicense;
		}
	}	
}

Describe "add-splunkLicenseFile" {

	$trialLicenseLabel = 'Splunk Enterprise Download Trial'
	$trialLicenseXml = @'
<license>
  <signature>ORjrS0GsHtQ/SlxeVazPI/TnOUJtw2w7ItW0ni6ovwFAwhvI8Q5Gfzg2jsz0nBvDyDv9vUzehN7CRpxm9GsLyntGjKoZzq7Pi+RAU3HEOFGWNPexf5e3uMMt4PD/okxkLjwlOVBxJaSd939cufIl1h0OsHcZ2jNye/pyqAjWY6qsP5f4ZR0a4uiuq20wo5VyWHI7T3YgRzfrQqjx9oN+Ad6UOKOvfkz7gzIA+cfGapZOI/R+J33WlYPb34S0ThToGQZc04q12PCPXn1L0zPBtchRUtlgBq8HuRaNMjcmaqFxUcn0EzRpGzVOH313g41Fz8n8Q8ZylMMFir+tpuTn8Q==</signature>
  <payload>
    <type>download-trial</type>
    <group_id>Trial</group_id>
    <quota>524288000</quota>
    <max_violations>5</max_violations>
    <window_period>30</window_period>
    <creation_time>1308038408</creation_time>
    <expiration_time>1313827208</expiration_time>
    <label>Splunk Enterprise Download Trial</label>
    <features>
      <feature>Auth</feature>
      <feature>FwdData</feature>
      <feature>RcvData</feature>
      <feature>LocalSearch</feature>
      <feature>DistSearch</feature>
      <feature>RcvSearch</feature>
      <feature>ScheduledSearch</feature>
      <feature>Alerting</feature>
      <feature>DeployClient</feature>
      <feature>DeployServer</feature>
      <feature>SplunkWeb</feature>
      <feature>SigningProcessor</feature>
      <feature>SyslogOutputProcessor</feature>
      <feature>AllowDuplicateKeys</feature>
    </features>
    <sourcetypes/>
    <guid>B0CE9D18-3272-41B8-94E3-76848AFC7F89</guid>
  </payload>
</license>
'@;
		
	It "adds enterprise trial license" {
		$pre = get-splunkLicenseFile -all | where{ $_.label -eq $trialLicenseLabel }

		if( $pre )
		{
			Write-Debug 'removing trial license file to test add-splunklicensefile'
			$pre.Hash | Remove-SplunkLicenseFile;
		}
		
		$pre = get-splunkLicenseFile -all | where{ $_.label -eq $trialLicenseLabel }
		
		add-SplunkLicenseFile -Name $trialLicenseLabel -payload $trialLicenseXml | out-host;				
		
		$post = get-splunkLicenseFile -all | where{ $_.label -eq $trialLicenseLabel }
		
		$post -and -not $pre		
	}	
}