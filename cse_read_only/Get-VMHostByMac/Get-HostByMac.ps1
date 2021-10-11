Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

# Connect to the vCentre
Connect-VIServer -Server vcw0000xxx
 
# Prompt user for MAC address
$MacAddress = Read-Host -Prompt "Please enter the MAC address"
 
# Amend the MAC address. Put the MAC address in "MACADDRESS"
Get-VMHost | Get-VMHostNetworkAdapter | Where-Object {$_.Mac -eq $MacAddress} | Format-List -Property *
