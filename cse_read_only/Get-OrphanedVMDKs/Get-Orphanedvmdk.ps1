# Set up variables
clear
Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

$arrayVC = @("vcw00002i2")
$DesktopPath = [Environment]::GetFolderPath("Desktop")
$OutputFile = "$DesktopPath\orphanedvmdks.txt"
$Report = $Null
$Report = @()
$Progress = 0

# build a VMware.Vim.FileQueryFlags object to put into the search spec
$fileQueryFlags = New-Object VMware.Vim.FileQueryFlags
$fileQueryFlags.FileSize = $true
$fileQueryFlags.FileType = $true
$fileQueryFlags.Modification = $true

# build a VMware.Vim.HostDatastoreBrowserSearchSpec object containing the previous FileQueryFlags object
$searchSpec = New-Object VMware.Vim.HostDatastoreBrowserSearchSpec
$searchSpec.details = $fileQueryFlags
$searchSpec.sortFoldersFirst = $true
$searchSpec.Query = New-Object VMware.Vim.VmDiskFileQuery

# Loop Through vCenters
Foreach ($strVC in $arrayVC)
{
	# Connect to current vCenter
	Connect-VIServer $strVC 
	
	# Use get-view to retrieve all the Datastores from a vCenter
	$arrDS = Get-View -ViewType Datastore | where {$_.Name -notmatch "_boot"}
	
	# Loop through the Datastores
	Foreach ($strDatastore in $arrDS)
	{	
		# Get all the filenames for VM harddisks
		$arrUsedDisks = Get-VM -Datastore $strDatastore.Name | Get-HardDisk | %{$_.filename}
		$Progress += 1
		Write-Progress -Activity  "Gathering Orphaned VMDKs.." -PercentComplete ($Progress/$arrDS.Count*100)
		
		# Get the Datastore browser object
		$strDatastoreName = $strDatastore.name
		$ds = $strDatastore
		$dsBrowser = Get-View $ds.browser
		
		# Retrieve the datastore's root path and then search through it using the Search Spec that was created earlier - filtering out snapshot pointer files, changeblock tracking files and flat files
		$rootPath = "["+$ds.summary.Name+"]"
		$searchResult = $dsBrowser.SearchDatastoreSubFolders($rootPath, $searchSpec) | Select -ExpandProperty file | where {$_.Path -notlike "*0000??.vmdk"} | where {$_.Path -notlike "*ctk.vmdk"} | where {$_.Path -notlike "*-flat.vmdk"}   
		foreach ($fileResult in $searchResult)
		{
			# Check each VMDK file against existing VMs to check whether the file is orphaned or not (doesn't really work)
			$VMDKName = $fileResult.Path
			$VMDKSize = $fileResult.FileSize/1000000000
			$strCheckfile = "*$VMDKName*"
			<#reach ($useddisk in $arrUsedDisks)
			{
				if (,$useddisk -like "*$VMDKName*"){Write-Host $useddisk}
			}#>
			IF ($arrUsedDisks -Like $strCheckfile){Break}
			Else
			{
				$info = "" | Select Datastore, VMDK, "Size (GB)"
				$info.Datastore = $strDatastoreName
				$info.VMDK = $VMDKName
				$info."Size (GB)" = $VMDKSize
				$Report += $info
			}
		}
	}
}
Disconnect-VIServer * -Confirm:$False
$Report | Export-Csv -Path "C:\Scripts\Technology\CSE\OrphanedVMDKsVCW3i3.csv"
