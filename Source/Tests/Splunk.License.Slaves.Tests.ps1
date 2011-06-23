param( $fixture )

Describe "get-splunkLicenseSlave" {

	$local:fields = data {
		"ID"
		"PoolIDs"
		"StackIDs"
		"Label"
	};							

	It "fetches slave list using default connection parameters" {
		$slaves = get-splunkLicenseSlave
		$slaves | verify-results -fields $local:fields | verify-all;
	}	
}
