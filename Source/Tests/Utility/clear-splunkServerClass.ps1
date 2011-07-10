$s = gc 'C:\Program Files\Splunk\etc\system\metadata\local.meta' 
$s = $s -join "___" -replace '\[serverclass/serverClass.+','' -split '___'
sc -path 'C:\Program Files\Splunk\etc\system\metadata\local.meta' -value $s;

sc 'C:\Program Files\Splunk\etc\system\local\serverclass.conf' -value '';