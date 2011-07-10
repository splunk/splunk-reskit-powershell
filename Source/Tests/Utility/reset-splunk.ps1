ri 'C:\Program Files\Splunk\etc\passwd';
restart-service splunk*
sleep -seconds 3;
start 'http://vbox-xp:8000/en-US/manager/launcher/authentication/changepassword/admin/?action=edit'