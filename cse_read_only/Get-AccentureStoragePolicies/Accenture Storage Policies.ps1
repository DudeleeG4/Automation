Get-Module -ListAvailable | Where {$_.Name -like "VM*"} | Import-Module

Clear

Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

# Connect to vCenters containing Accenture's VMs
Connect-VIServer @("vcw00002i2", "vcw00003i2", "vcw0000ai2")

# Get Accenture's resource pools and start looping through them
$RPs = Get-ResourcePool | Where {$_.Name -like "Accenture*"}
$Progress = 0
$Report = $RPs |% {
	Write-Progress -Activity "Total Completion" -PercentComplete ($Progress/$RPs.Count*100) -Id 1 -CurrentOperation "Resource Pool: $ResourcePool"
	$ResourcePool = $_
	# Get VMs from the current resource pool in the loop
	$VMs = Get-VM -Location $_
	# Loop through all VMs in the resource pool	
	$Progress2 = 0
	$VMs |%{
		Write-Progress -Activity "Processing VMs.." -ParentId 1 -PercentComplete ($Progress2/$VMs.count*100) -Id 2
		$VM = $_
		# Gather the default storage policy for the VM
		$VMStoragePolicy = Get-SpbmEntityConfiguration -VM $_
		# Get the VM's Hard Disks and loop through them
		$HardDisks = Get-HardDisk $_
		$Progress3 = 0
		$HardDisks |% {
			Write-Progress -Activity "Virtual Machine: $VM" -ParentId 2 -PercentComplete ($Progress3/$HardDisks.Count*100)
			$HardDisk = $_
			# Get the storage policy for each hard disk on the VM
			$HardDiskStoragePolicy = Get-SpbmEntityConfiguration -HardDisk $_
			# Create object to put in the report
			[PSCustomObject]@{
				OrgVdc = $ResourcePool.Name
				VM = $VM.Name
				"VM Storage Policy" = $VMStoragePolicy.StoragePolicy
				"Hard Disk" = $HardDiskStoragePolicy.Name
				"Hard Disk Storage Policy" = $HardDiskStoragePolicy.StoragePolicy
				"Hard Disk Persistence" = $HardDisk.Persistence
			}
			$Progress3++
		}
		$Progress2++
	}
	$Progress ++
}
# Export the report to CSV
$Report | Export-Csv "C:\Scripts\Technology\CSE\Accenture Storage Policies.csv" -NoTypeInformation
