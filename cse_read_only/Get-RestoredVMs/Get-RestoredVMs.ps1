# Load the PowerCLI modules and then clear the console
Get-Module -ListAvailable | Where {$_.Name -like "VM*"} | Import-Module
Clear

Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

# Define a list of vCenters (in this case it is all the client facing vCenters in IL2 PV1
$vCenterServers = @("vcw00001i2.il2management.local", "vcw00002i2.il2management.local", "vcw00003i2.il2management.local", "vcw00004i2.il2management.local", "vcw00005i2.il2management.local", "vcw00007i2.il2management.local", "vcw00008i2.il2management.local", "vcw00009i2.il2management.local", "vcw0000ai2.il2management.local")

# Provide credentials to login to the vCenters
$Cred = Get-Credential
$Report = $null
$Report = @()
$Progress = 0

# Connect to all the vCenters
Connect-VIServer $vCenterServers -Credential $Cred

# Retrieve all VMs with "Restore" in their names
$Filter = @{"Name" = "restore"}
$VMs = Get-View -ViewType VirtualMachine -Filter $Filter
foreach ($VM in $VMs)
{
	$Progress += 1
	Write-Progress -Activity "Gathering.." -PercentComplete ($Progress/$VMs.Count*100)
	$Parent = Get-View $VM.Parent
	$ResourcePool = Get-View $Parent.Parent
	$VC = $VM.Client.ServiceUrl -split "/" | Select -Index 2
	$info = "" | select vCenter, "VM Name", "Resource Pool"
	$info.vCenter = $VC
	$info."VM Name" = $VM.Name
	$info."Resource Pool" = $ResourcePool.Name

	$Report += $info
}
Disconnect-VIServer * -Confirm:$False
$Report | Export-Csv "C:\Scripts\Technology\CSE\Restore VMs\RestoredVMs.csv"././;;
