# Connect to pod B vcenter - change this for a different vCenter
Connect-VIServer vcv0000ci2.pod0000b.sys00005.il2management.local

# Retrieve all the hosts for a vCenter
$VMHosts = Get-VMHost

# Retrieve all assured accounts
$Accounts = Get-EApiAccount

#Loop through all the Hosts
$Progress = 0
$Report = Foreach ($VMHost in $VMHosts) {
	Write-Progress -Activity "Looping through hosts" -PercentComplete ($Progress/$VMHosts.count*100) -Id 1
	
	# Gather all VMs that are not Edge gateways
	$VMs = $VMHost | Get-VM | Where {$_.name -notlike "vse-*"}
	$Progress2 = 0
	
	#Loop through all the VMs on the current host
	foreach ($VM in $VMs){
		Write-Progress -Activity "Looping through VMs" -PercentComplete ($Progress2/$VMs.count*100) -ParentId 1
		
		# Match VMs up to their accounts
		$Account = $Accounts | Where {$_.domainIdentifier -match ($VM.Folder.Parent.Parent.name -split "-" | Select -Index 1)}
		
		# Omit VMs that do not fall into the standard vCloud folder structure (these will be largely internal only VMs or tempates)
		if ($Account.count -gt 1){
			Continue
			$Progress2 ++
		}
		elseif(!$Account){
			Continue
			$Progress2 ++
		}	
		[PSCustomObject]@{
			VM = $VM.name
			Company = $Account.Company.Name
			Account = $Account.Name
			Host = $VMHost.Name
		}
		$Progress2 ++
	}
	$Progress ++
}

# Export the output to csv on the user's desktop
$DesktopPath = [Environment]::GetFolderPath("Desktop")
$OutputPath = "$DesktopPath\PodBVMLocations.csv"
$Report | Export-Csv $OutputPath -NoTypeInformation

Read-Host -prompt "Press enter to exit."