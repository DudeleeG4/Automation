Get-Module -ListAvailable | Where {$_.Name -like "VM*"} | Import-Module 
Import-Module Microsoft.Powershell.Utility -ErrorAction 'silentlycontinue' -WarningAction 'silentlycontinue'
clear
$VMHistory = $Null
$VMHistory = @()
$Destination = @()
$vCenter = Read-Host "Which vCenter?"
$Cred = Get-Credential
Connect-VIServer $vCenter -Credential $Cred
$SAN = Get-DatastoreCluster | Out-Gridview -Passthru
$Datastores = $SAN | Get-Datastore | Where {$_.Name -notlike "*boot*"} | Out-GridView -title "Select Datastores" -passthru
Do{
	$FinalVMs = $Null
	$DSVMs = Get-VM -Datastore $Datastores <#| Where {$_.PowerState -notlike "PoweredOff"}#> | Where-Object {$_.Name -notin $VMHistory.Name}
	$VMChoice = $DSVMs | Select @{N="Name"; E={$_.Name}},@{N="UsedSpace";E={$_.UsedSpaceGB}},@{N="Power State";E={$_.PowerState}} | Sort UsedSpace -Descending | Out-GridView -title "Select VMs" -PassThru 
	$VMChoice2 = $VMChoice.Name
	$FinalVMs = $Null
	$FinalVMs = @()

	foreach ($VM in $VMChoice2)
	{	
		$info = $DSVMs | Where {$_.Name -like $VM}
		if (!$info)
		{
			$VM = $VM -split " " | Where {$_ -like "(*-*-*-*-*)"} 
			$info = $DSVMs | Where {$_.Name -match $VM}
		}
		$FinalVMs += $info
	}
	$VMHistory += $FinalVMs
	$Target = Read-Host "Choose destination: (Cluster/Datastore)"
	$DSCluster = Get-DatastoreCluster 
	$DSCluster = $DSCluster | Out-GridView -Title "Select Datastore cluster" -Passthru
	if ($Target -like "Cluster")
	{	
		Foreach ($FinalVM in $FinalVMs)
		{
			$Destination += $DSCluster.Name
		}
		if ($FinalVMs.Count -gt 1)
		{
			$VMSplit = Read-Host "Do you want to split up the VMs? (Yes/No)"
			if ($VMSplit -like "Yes")
			{
			Write-Host "Split VMs"
			$vmAntiAffinityRule = New-Object -TypeName VMware.VimAutomation.ViCore.Types.V1.DatastoreManagement.SdrsVMAntiAffinityRule -ArgumentList $FinalVMs
			Move-VM -VM $FinalVMs -Datastore $DSCluster -AdvancedOption $vmAntiAffinityRule -Confirm:$false -RunAsync
			}
		
		
			elseif ($VMSplit -like "No")
			{
				$VMDKs = Get-Harddisk -VM $FinalVMs
				$SplitVMDKs = Read-Host "Do you want to split up the hard disks? (Yes/No)"
				if ($Splitvmdks -like "Yes")
				{
					Write-Host "Split"
					$vmdkAntiAffinityRule = New-Object -TypeName VMware.VimAutomation.ViCore.Types.V1.DatastoreManagement.SdrsVMDiskAntiAffinityRule -ArgumentList $vmdks
					Move-VM -VM $FinalVMs -Datastore $DSCluster -AdvancedOption $vmdkAntiAffinityRule -Confirm:$False -RunAsync
				}
				elseif ($Splitvmdks -like "No")
				{
					Write-Host "Don't Split"
					Move-VM -VM $FinalVMs -Datastore $DSCluster -Confirm:$false -RunAsync
				}
			}
		}
		elseif ($FinalVMs.Count -eq 1)
		{
		$VMDKs = Get-Harddisk -VM $FinalVMs
			$SplitVMDKs = Read-Host "Do you want to split up the hard disks? (Yes/No)"
			if ($Splitvmdks -like "Yes")
			{
				Write-Host "Split"
				$vmdkAntiAffinityRule = New-Object -TypeName VMware.VimAutomation.ViCore.Types.V1.DatastoreManagement.SdrsVMDiskAntiAffinityRule -ArgumentList $vmdks
				Move-VM -VM $FinalVMs -Datastore $DSCluster -AdvancedOption $vmdkAntiAffinityRule -Confirm:$False -RunAsync
			}
			elseif ($Splitvmdks -like "No")
			{
				Write-Host "Don't Split"
				Move-VM -VM $FinalVMs -Datastore $DSCluster -Confirm:$false -RunAsync
			}
		}
	}
	elseif ($Target -like "Datastore")
	{
		$Datastore = Get-Datastore -Location $DSCluster | Out-GridView -Title "Please select a Datastore" -Passthru 
		if (!$Datastore)
		{
			$Continue = "No"
			Disconnect-VIServer * -Confirm:$false
			Break
		}
		foreach ($FinalVM in $FinalVMs)
		{
			$Destination += $Datastore.Name
		}
				
		Move-VM -VM $FinalVMs -Datastore $Datastore -Confirm:$false -RunAsync -WhatIf
			
	}
	$Continue = Read-Host "Do you want to choose more VMs to move? (Yes/No)"
	
}
Until($Continue -like "No")
$Report = $null
$Report = @()
$Progress = 0
Foreach ($Record in $VMHistory)
{
	
	$Result = "" | Select "VM Moved", Destination, PowerState
	$Result."VM Moved" = $Record.Name
	$Result.Destination = $Destination | Select -Index $Progress
	$Result.PowerState = $Record.PowerState
	$Report += $Result
	$Progress += 1
}

$Report | Out-Gridview -Passthru | Export-Csv "C:\Scripts\Technology\NOC\VMList.csv"

Disconnect-VIServer * -Confirm:$false



