#
# Splunk Powershell SDK Demo
#
# Loading the Module
#
ipmo ./Splunk
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
$SplunkDefaultObject = Connect-Splunk -ComputerName $SplunkServers -UserName admin
$SplunkDefaultObject
#
# Now we can do this instead
#
Get-Splunkd

#
# If the admin account has the same password on multiple splunk instances you can do this.
#
#
$SplunkServers = "Lagos","Win-Dev-2","GOOSE"
$SplunkServers | Get-Splunkd
#
# Lets use Set-Splunkd to change the session timeout
#
Set-Splunkd -SessionTimeout 1d 
#
# We can also to this on a set of servers
#
$SplunkServers | Set-Splunkd -SessionTimeout 1h -force
#
# After we make these kind of changes we need to restart splunkd
#
#Restart-SplunkService -wait
#
# As with the others we can also do this in mass
#
#$SplunkServers | Restart-SplunkService -force -wait
#
# When we restart splunkd on multiple servers we may want to verify it worked.
#
$SplunkServers | Test-Splunkd

# 
# Some other cmdlets
#
# Returns Splunk users
#
Get-SplunkdUser
#
# Returns the OS and Splunk version.
#
Get-SplunkdVersion
#
# Returns the currently loaded licenses
#
Get-SplunkLicenseFile
#
# This returns the current logging settings
#
Get-SplunkdLogging
#
# Lets see it at work
#
Search-Splunk -Search 'Type=Error source=WinEventLog:Application'
