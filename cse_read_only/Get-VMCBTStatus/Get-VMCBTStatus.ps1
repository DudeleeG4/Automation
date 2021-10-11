Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

# Prompt the user to enter the full VM name as it appears on vCenter
$VMName = Read-Host -Prompt "VM Name:"

# Prompt the user to enter the vCenter that the VM is in
$vCenterServer = Read-Host -Prompt "vCenter:"

# Connect to the VIServer
Connect-VIServer $vCenterServer

# Retrieve the CBT status of the specified VM
Get-VM  -name $VMName | Select Name, @{N="CBT Enabled";E={$_.ExtensionData.Config.ChangeTrackingEnabled}}
