#
# Splunk Powershell SDK Demo
#
# Loading the Module
#
ipmo C:\Projects\SDK\splunk-sdk-powershell\Source\Splunk -force
#
# Disabling certificate checking
#
Disable-CertificateValidation
#
# Lets start with what cmdlets we have so far.
#
Get-Splunk
#
# Lets take a look at Get-Splunkd
#
$MyCreds = Get-Credential
Get-Splunkd -ComputerName Lagos -port 8089 -Protocol https -timeout 5000 -Credential $MyCreds
#
# Having to pass parameters everytime we want to use a cmdlet can be a pain. 
# So we included Connect-Splunk to allow you to set default values.
#
Connect-Splunk -ComputerName lagos -UserName bshell
#
# Now we can do this instead
#
Get-Splunkd
#
# Lets take a look at the connection object cmdlets
#
Get-SplunkConnectionObject
#
# Export
#
Export-SplunkConnectionObject -Path C:\Data\Myconnection.xml
#
# Lets look at the file
#
notepad C:\Data\Myconnection.xml
#
# Remove Connection Object
#
Remove-SplunkConnectionObject -force
#
# Verify it is gone
#
Get-SplunkConnectionObject
#
# Import
#
Import-SplunkConnectionObject -Path C:\Data\Myconnection.xml -Force
#
# 
#
Get-SplunkConnectionObject
#
# Verify it works
#
Get-Splunkd
#
# Lets look at the licensing cmdlets
#
Get-Splunk -noun "*license*"
#
# Get License file info
#
Get-SplunkLicenseFile 
#
# Look for messages
#
Get-SplunkLicenseMessage
#
# Group
#
Get-SplunkLicenseGroup
#
# Stack
#
Get-SplunkLicenseStack
#
# Pool
#
Get-SplunkLicensePool



