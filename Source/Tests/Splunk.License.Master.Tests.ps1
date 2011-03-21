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
		$true
	}	
}
