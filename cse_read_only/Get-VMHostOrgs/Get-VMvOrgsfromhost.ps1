# Load the PowerCLI modules and clear the console
Get-Module -ListAvailable | Where {$_.Name -like "VM*"} | Import-Module
Clear

Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

# Prompt the user to enter the vCenter and connect to it
$vCenter = Read-Host -Prompt "vCenter:(vcw0000xxx)"
Connect-VIServer $vCenter

# Retrieve all of the Hosts from the vCenter and ask the user to select one
$VMHost = Get-VMHost | Out-GridView -Passthru

# Retrieve all of the VMs that are on the host and their vOrg and retrieve them 
$VMHost | Get-VM | Select @{N="VM";E={$_.Name}}, @{N="vOrg";E={$_.Folder.Parent.Parent}} | Export-Csv "C:\Scripts\Technology\CSE\VMsOnHost.csv" -NoTypeInformation

# Disconnect from the vCenter and tell the user where they can find the output
Disconnect-VIServer * -Confirm:$false
Write-Host "Report Created ---> C:\Scripts\Technology\CSE\VMsOnHost.csv"
