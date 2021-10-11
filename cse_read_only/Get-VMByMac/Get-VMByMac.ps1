Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

# Connect to the vCentre
Connect-VIServer -Server vcw0000xxx

# Prompt user to enter mac address
Read-Host -Prompt "Please enter the MAC address"

# Amend the MAC address. Put the MAC address in "MACADDRESS"
Get-VM | Get-NetworkAdapter | Where {$_.macaddress -eq $MacAddress} | select parent,macaddress
