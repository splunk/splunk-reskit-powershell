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

# Splunk demo
# 11.11.2011
# jim christopher <jimchristopher@gmail.com>

# -----------------------------------------------------------------------------
# preamble

# import the Splunk module
Import-Module Splunk

# disable certificate validation for this session
disable-certificateValidation;

# define our splunk topology
$indexer = 'talon-xp'
$forwarders = 'talon-xp2','talon-xp3'
$allSplunk = $forwarders + $indexer;

# load credentials if necessary
if( -not $credential )
{
	$credential = Get-Credential;
}

# create a default connection to the indexer
connect-splunk -computername $indexer -protocol 'https' -port 8089 -credentials $credential;

# -----------------------------------------------------------------------------
# concept: managing multiple splunk instances at a time

# example: get the splunk daemon information for the default connection
get-splunkd;

# example: get the splunk daemon information for the list of forwarders
$forwarders | get-splunkd;

# example: get the splunk daemon information for splunk topology, sorted by computername
$allSplunk | get-splunkd | sort ComputerName

# -----------------------------------------------------------------------------
# story: admin can apply configuration of inputs to multiple forwarders

$inputName = 'PerfCounter Processes';

# create a new input on every splunk instance
$allSplunk | new-SplunkInputWinPerfMon -name $inputName -interval 30 -object 'process' -counters 'elapsed time' -instances *

# verify the new input on every splunk instance
$allSplunk | get-SplunkInputWinPerfMon -name $inputName

# update an existing input on the forwarder instances - set the update interval to 10 seconds
$forwarders | set-SplunkInputWinPerfMon -name $inputName -interval 10 -instances *;

# verify the updated inputs
$allSplunk | get-SplunkInputWinPerfMon -name $inputName 

# remove the new input on every splunk instance
$allSplunk | remove-SplunkInputWinPerfMon -name $inputName -force

# -----------------------------------------------------------------------------
# story: admin can apply configuration of outputs for multiple forwarders

$outputName = 'talon-xp:9997';

$forwarders | remove-SplunkOutputServer -name $outputName

# create an output configuration on each forwarder
$forwarders | new-SplunkOutputServer -name $outputName

# verify the new output server configurations
$forwarders | get-SplunkOutputServer -name $outputName

# update the output server configurations
$forwarders | set-SplunkOutputServer -name $outputName -disabled -initialBackoff 30

# verify the new output server configurations
$forwarders | get-SplunkOutputServer -name $outputName

# verify the new output server configurations
$forwarders | remove-SplunkOutputServer -name $outputName

Remove-Module Splunk;