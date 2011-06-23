[cmdletbinding(SupportsShouldProcess=$true)]
param()

process
{
$c = New-Object system.Net.WebClient
$credentials = Get-Credential;

$url = New-Object system.Collections.Stack
$url.push('https://vbox-xp:8089/services');
$done = @();

while( $url.Peek() )
{
	$u = $url.Pop();
	if( $done -contains $u )
	{
		continue;
	}

	$done += $u;
	
	if( -not( $pscmdlet.shouldprocess( $u ) ) )
	{
		continue;
	}
	
	Write-Host "fetching $u...";

	$c.Credentials = $credentials
	[xml]$d = $c.DownloadString( $u );
	
	$n = $d.feed.title;
	$d.save( "$pwd\$n.atom" )
	$d.feed.entry | select id | %{ $url.push($_.id) }	
}
}