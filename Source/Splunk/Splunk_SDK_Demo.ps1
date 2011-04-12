#
# Splunk Powershell SDK Demo
#
# Lets start with what cmdlets we have so far.
#
Get-Splunk
#
# Lets take a look at Get-Splunkd
#
$MyCreds = Get-Credential
Get-Splunkd -ComputerName yetiwinsrv1 -port 8089 -Protocol https -timeout 5000 -Credential $MyCreds
#
# Having to pass parameters everytime we want to use a cmdlet can be a pain. 
# So we included Connect-Splunk to allow you to set default values.
#
$SplunkDefaultObject = Connect-Splunk -ComputerName yetiwinsrv1 -UserName admin
$SplunkDefaultObject
#
# Now we can do this instead
#
Get-Splunkd
#
# If the admin account has the same password on multiple splunk instances you can do this.
#
$SplunkServers | Get-Splunkd
#
# This process works with most of the cmdlets. Lets take a look at Set-Splunkd
#
Get-Help Set-Splunkd -Full
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
Restart-SplunkService -wait
#
# As with the others we can also do this in mass
#
$SplunkServers | Restart-SplunkService -force
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
Get-SplunkLicense
#
# This returns the current logging settings
#
Get-SplunkdLogging
#
# Finally, lets take a look at Search-Splunk
#
Get-Help search-splunk -Full
#
# Lets see it at work
#
Search-Splunk -Search 'source="WinEventLog:Directory Service"'
