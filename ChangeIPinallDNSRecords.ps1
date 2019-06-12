# Set these Variables!
$oldip = "0.0.0.0" # enter the ip you want to change
$newip = "1.1.1.1" # enter the ip you want it changed to


########## DO NOT CHANGE AFTER HERE ##########
### SET VARIABLES ###
# split up IPs into array
$oldipsplit = $oldip.Split(".")
$newipsplit = $newip.Split(".")

# create reverse zone names
$oldreversezone = $oldipsplit[2] + "." + $oldipsplit[1] + "." + $oldipsplit[0] + ".in-addr.arpa"
$newreversezone = $newipsplit[2] + "." + $newipsplit[1] + "." + $newipsplit[0] + ".in-addr.arpa"


### CHANGE REVERSE ###
write-host "### CHANGE REVERSE ###"

# Get all reversezones entries for the IP
$reverserecords = get-dnsserverresourcerecord $oldreversezone -rrtype "PTR" | where {$_.HostName -match $oldipsplit[3] -and -not $_.TimeStamp}

# Add Record in new zone for each fqdn
foreach ($reverserecord in $reverserecords){
    $fqdn = $reverserecord.RecordData.PTRDomainName
	write-host "============================================================"
	write-host "Changing Reverse: $fqdn"
	Add-DnsServerResourceRecordPtr -Name $newipsplit[3] -ZoneName $newreversezone -PtrDomainName "$fqdn"
	write-host "============================================================"
}
# remove old reverse entries
get-dnsserverresourcerecord $oldreversezone -rrtype "PTR" | where {$_.HostName -match $oldipsplit[3] -and -not $_.TimeStamp} | remove-dnsserverresourcerecord -zonename $oldreversezone -force

write-host "### REVERSE DONE ###"

### CHANGE FORWARD ###
write-host ""
write-host "############################################################"
write-host ""
write-host "### CHANGE FORWARD ###"

# Get all Forward Zones
$zones = (Get-DnsServerZone | where {$_.IsReverseLookupZone -match "False"}).ZoneName 

# for each zone
foreach ($zone in $zones) {
    # get all A records with the old IP in each zone
	$records = get-dnsserverresourcerecord $zone -rrtype "A" | where {$_.RecordData.IPv4Address -eq $oldip -and -not $_.TimeStamp}
    
    # if zone has any recrords
    if ($records) {
        write-host "============================================================"
        write-host "Changing Zone: $zone"

        # for each record in each zone, change the records
        foreach ($record in $records){
            write-host "Changing A Record:" $record.HostName
			
			# for @ host entries
			if ($record.HostName -eq "@") {
			
			# add new a record with @
			add-dnsserverresourcerecorda -zonename $zone -ipv4address $NewIP -name "@"
			
			# remove the old a record with @
			Remove-DnsServerResourceRecord -ZoneName $zone -RRType "A" -Name "@" -RecordData $oldip	-force
			}
			
			else {
            # create new object with information from old 
		    $newobj = get-dnsserverresourcerecord $zone -rrtype "A" -name $record.HostName | where {$_.RecordData.IPv4Address -eq $oldip -and -not $_.TimeStamp}
            
            # fill in the new IP 
            $newobj.RecordData.IPv4Address=[System.Net.IPAddress]::parse($newip)
		    
            # change record
            Set-dnsserverresourcerecord -newinputobject $newobj -oldinputobject $record -zonename $zone
		    }
			write-host "============================================================"
	    }
    }
}
write-host "### FORWARD DONE ###"
