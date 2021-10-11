Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

# Connect to the vCentre
Connect-VIServer -Server vcw0000xxx
 
# Amend the MAC address. Put the MAC address in "MACADDRESS"
Get-VMHost | Get-VMHostNetworkAdapter | Where-Object {$_.Mac -eq MACADDRESS} | Format-List -Property *
