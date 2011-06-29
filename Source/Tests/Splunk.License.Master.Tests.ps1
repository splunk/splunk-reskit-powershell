param( $fixture )

Describe "get-splunkLicenseMaster" {

	$fields = data {
		"ID"
		"Title"
		"MasterGUID"
		"MasterURI"
	};							

	It "fetches license master list using default connection parameters" {
		$m = get-splunkLicenseMaster
		
		$m | verify-results -fields $fields | verify-all;
	}	
}

Describe "set-splunkLicenseMaster" {

	It "sets license master using default connection parameters" {
		set-splunkLicenseMaster -force
		
	}	
}
