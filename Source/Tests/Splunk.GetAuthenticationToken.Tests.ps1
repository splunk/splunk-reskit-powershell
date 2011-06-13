param( $fixture )


Describe "get-splunkAuthToken" {

	$local:fields = data {
		"AuthToken"
		"UserName"
	};							

	It "fetches auth token using custom credentials" {
		Get-SplunkAuthToken -Credential $script:fixture.splunkAdminCredentials | verify-results -fields $local:fields | verify-all;
	}
}