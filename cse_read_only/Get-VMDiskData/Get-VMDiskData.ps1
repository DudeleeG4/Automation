# Load the PowerCLI modules and then clear the console
Get-Module -ListAvailable | Where {$_.Name -like "VM*"} | Import-Module
Clear

Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

# Define variables
$DesktopPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
$Report = @()

# Prompt the user to enter the vCenter and ask for their credentials
$vCenter = Read-Host -Prompt "Enter a vCenter (vcw0000xxx)"
$Cred = Get-Credential

# Connect to the vCenter entered by the user
Connect-VIServer $vCenter -Credential $Cred
Write-Host "Gathering Datastore information..."

# Gather all Datastores on the vCenter
$AllDSs = Get-Datastore
Write-Host "Gathering VMs..."

# Gather all the VMs and output them to the user to select from, pass the selection back into the pipeline and into the $choice variable
$Choice = Get-VM | Out-GridView -Title "Please select VM(s)" -PassThru
$VMNo = $Choice.Count
Write-Host "Calculating VM hard disk statistics for $vmno VMs..."

# Loop through the chosen VMs
$Number = 0
$Report = $Choice |% {
	$VM = $_
	Write-Progress -Activity "Retrieving hard disks for VMs..." -PercentComplete ($Number/$Choice.Count*100) -Id 1
	
	<# Retrieve 2 different versions of the VMs disk, as we will need information from both. One is the harddisk object retrieved by using Get-HardDisk,
	the other are the harddisk objects contained within the VM object #>
	
	# Retrieve the VM's hard disks
	$HDD = $VM | Get-HardDisk
	
	# Create an object for each of the VM's disks from the Get-VM object with the disk's filename edited to omit square brackets
	$HardDisks = $VM.ExtensionData.LayoutEx.File | Where {$_.Type -match "diskExtent"}|% {
		[PSCustomObject]@{
			Key = $_.Key
			Name = $_.Name.Trimend("-flat.vmdk").Replace("[","").Replace("]","")
			FileName = $_.Name
			"Type" = $_.Type
			Size = $_.UniqueSize
			UniqueSize = $_.UniqueSize
			BackingObjectId = $_.BackingObjectId
			Accessible = $_.Accessible
		}
	}
	
	# Loop through the hard disk objects
	$Number2 = 0
	$HDD |% {
		Try{
			Write-Progress -ParentId 1 -Id 2 -Activity "Calculating storage data..." -PercentComplete ($Number2/$HardDisks.count*100)
		}Catch{
			Write-Progress -ParentId 1 -Id 2 -Activity "Calculating storage data..." -PercentComplete 100
		}
		
		# Trim the HardDisk's filename to remove square brackets
		$TrimmedFileName = $_.Filename.TrimEnd(".vmdk").Replace("[","").Replace("]","")

		# Filter through the $HardDisks list for a disk with the same name as $TrimmedFileName
		$ProvisionedDisk = $HardDisks | Where {$_.Name -like $TrimmedFileName}
		
		# Calculate the Disk's uncommitted space
		$UncommittedSpace = [Math]::Round((($_.CapacityGB)-($ProvisionedDisk.Size/ 1GB)),2)
		
		# Retrieve the exact Datastore name from the $HDDS object
		$Datastore = $_.Filename.Split(" ").Split("]").Split("[") | select -Index 1
		
		# Find the HardDisk object from the $ALLDSs variable which matches the datastore name stored in $Datastore, calculate the Datastore's info
		$DSReport = $AllDSs | Where-Object {$_.Name -match $Datastore}
		$DSUsedSpace = [Math]::Round($DSReport.CapacityGB - $DSReport.FreeSpaceGB,2)
		$DSProvisioned = [Math]::Round(($DSReport.ExtensionData.Summary.Capacity - $DSReport.ExtensionData.Summary.Freespace + $DSReport.ExtensionData.Summary.Uncommitted)/1GB,2)
		
		# Build Report
		[PSCustomObject]@{
			"VM Name" = $VM.Name
			"Hard Disk" = $_.Name
			"Used Space GB" = [Math]::Round($ProvisionedDisk.Size/ 1GB,2)
			"Provisioning GB" = $_.CapacityGB
			"Uncommitted Space" = $UncommittedSpace
			"Datastore" = $Datastore
			"Datastore Capacity GB" = $DSReport.CapacityGB
			"Datastore Used Space GB" = $DSUsedSpace
			"Percent Full" = [Math]::Round(($DSUsedSpace/$DSReport.CapacityGB)*100,2)
			"Datastore Provisioned" = $DSProvisioned
			"Datastore Free Space" = [Math]::Round($DSReport.FreeSpaceGB,2)
		}
		$Number2 ++
	}
	$Number ++
	$Number2 = 0
}
if (!$Final){Write-Host "No Disks found"}
$Report | Out-GridView -Title "Select items and press 'OK' to export to your desktop\VM Datastore Usage.csv" -PassThru  | Export-Csv "$DesktopPath\VM Datastore Usage.csv" -NoTypeInformation

Disconnect-VIServer * -Confirm:$false
