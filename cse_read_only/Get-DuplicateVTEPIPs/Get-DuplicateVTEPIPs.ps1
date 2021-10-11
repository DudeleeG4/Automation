
# Retrieve a list of vCenters and ask the user to pick which one to connect to
$Server = Get-CustomerVIServers | Invoke-MultiSelectForm
if (!$Server){
	Write-Host "Cancelled..."
	Break
}

# Connect to the selected vCenter
Connect-VIServer $Server

# Retrieve a list of every cluster within the vCenter and as the user to select which cluster to check
$Cluster = Get-Cluster | Invoke-MultiSelectForm
if (!$Cluster){
	Write-Host "Cancelled..."
	Break
}

# Retrieve the ESXi hosts' vmk4 adapters
$VMHostVMK4s = Get-VMHost -Location $Cluster | Get-VMHostNetworkAdapter | Where {$_.Name -like "*vmk4*"} 

# Create a list of the VMhosts and their IP addresses
$Progress = 0
$Report = Foreach ($VMHostVMK4 in $VMHostVMK4s){
	Write-Progress -Activity "Gathering VTEP IPs" -PercentComplete ($Progress/$VMHostVMK4s.Count*100) -Id 1
	[PSCustomObject]@{
		VMHost = $VMHostVMK4.VMHost
		Name = $VMHostVMK4
		IP = [IPAddress]$VMHostVMK4.IP
	}
	$Progress ++
}

# Loop through the list and find any duplicates, add them to a separate list
$Duplicates = @()
$Progress2 = 0
Foreach  ($Item in $Report){
	Write-Progress -Activity "Checking for duplicates" -PercentComplete ($Progress2/$Report.Count*100) -ParentId 1
	$Output = $Report | Where {$_.IP -match $Item.IP}
	if ($Output.count -lt 2){
		# Output any healthy hosts to pipeline
		$Message = "No duplicates for" + $Output.VMHost
		Write-Host $Message
	}else{
		$Duplicates += $Output
	}
	$Progress2 ++
}

# Output any duplicates to pipeline
if (!$Duplicates){
	Read-Host -Prompt "No duplicates."
}else{
	$Duplicates | Sort-Object -Property VMHost -Unique
}