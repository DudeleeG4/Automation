# Load the PowerCLI modules and then clear the console
Get-Module -ListAvailable | Where {$_.Name -like "VM*"} | Import-Module
clear

# Prompt the user to enter the vCenter and then connect to it
$vCenterServers = Read-Host -Prompt "Enter the vCenter:"
Connect-VIServer $vCenterServers

# Gather all of the snapshots for every VM on the vCenter
$VMs = Get-VM
$Snapshots = Get-Snapshot -VM $VMs

# Select which snapshots to remove by filtering for just the snapshots which have "Avamar" in their name
$removesnapshots = $Snapshots | Where {$_.Name -match "Avamar"}

# Retrieve the VM names from the snapshots.
$VMNames = $removesnapshots.VM
$finalsnapshots = Get-Snapshot -VM $VMNames

# Show the user the selection of snapshots and ask them to select one or more to be removed
$DeletedSnapshots = $finalsnapshots | Select @{N="Name";E={$_}}, Description, @{N="Snapshot Powerstate";E={$_.Powerstate}}, VM | Out-GridView -Title "Select snapshots you wish to delete" -Passthru
if (!$DeletedSnapshots)
	{
	Disconnect-VIServer * -Confirm:$False
	exit
	}
	
# Forcibly remove the snapshots (this can take some time)
$DeletedSnapshots.Name | Remove-Snapshot -RemoveChildren:$false -Confirm:$false #-RunASync #-WhatIf
$DeletedSnapshots | Out-GridView -Title "These snapshots have been deleted"
Disconnect-VIServer * -Confirm:$False