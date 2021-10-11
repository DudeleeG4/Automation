Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

# Load PowerCLI Modules and clear the console
Get-Module -ListAvailable | Where {$_.Name -like "VM*"} | Import-Module
clear

# Define variables
$Progress = 0
$Progress2 = 0
$Cred = Get-Credential
$vCenterServers = @("vcw00001i3", "vcw00002i3", "vcw00003i3", "vcw00004i3", "vcw00005i3", "vcw00007i3", "vcw00008i3", "vcv00002i3.pod0000d.sys00005.il3management.local", "vcv00003i3.pod0000d.sys00005.il3management.local", "vcv00004i3.pod00012.sys00006.il3management.local", "vcv00005i3.pod00012.sys00006.il3management.local")

# Open an array and begin looping through vCenters
$Final = @()
foreach ($vCenter in $vCenterServers)
{	
	$Progress += 1
	Write-Progress -Id 1 -Activity "Finding storage.." -PercentComplete ($Progress/$vCenterServers.Count*100)
	$SANList = $Null
	$SANList = @()
	
	# Connect to current vCenter in loop
	Connect-VIServer $vCenter -Credential $Cred
	
	# Retrieve all of the datastore clusters on the vCenter
	$DatastoreClusters = Get-DatastoreCluster
	
	# Loop through the Datastore Clusters
	foreach ($DatastoreCluster in $DatastoreClusters)
	{	
		$Progress2 += 1
		Write-Progress -ParentId 1 -Activity "Searching Clusters.." -PercentComplete ($Progress2/$DatastoreClusters.Count*100)
		$SAN = $Null
		$SANNames = $Null
		
		# Deal with datastore clusters with a colon in the name
		if ($DatastoreCluster.Name -notmatch ":")
		{	
			$DatastoreName = $null
			$DatastoreNames = $null
			$DatastoreName = @()
			$DatastoreNames = @()
			
			# retrieve all of the relevant datastores from the current datastore cluster
			$Datastores = Get-Datastore -Location $DatastoreCluster | Where {$_.Name -notmatch "boot"}
			if (!$Datastores)
			{
				$Datastores = Get-Datastore -Location $DatastoreCluster
			}
			# Loop through datastores, split by a colon and select the first part
			foreach ($Datastore in $Datastores)
			{	
				$DatastoreName = $Datastore.Name -split ":" | select -First 1
				if (!$DatastoreName)
				{	Write-Host "Fuck"
					$DatastoreName = $Datastore.Name
				}
				$DatastoreNames += $DatastoreName
			}
			
			# Remove Duplicates from list and build report
			$SANs = $DatastoreNames | Select -Unique
			$SANNames = $null
			$SANNames = @()
			foreach ($SAN in $SANs)
			{
				$SANName = "" | Select vCenter, SAN
				$SANName.vCenter = $vCenter
				$SANName.SAN = $SAN
				$SANNames += $SANName
			}
		}
		
		# deal with datastore clusters with a colon in their name
		else
		{	
			# Split the datastore cluster name by a colon and select the first
			$Name = $DatastoreCluster.Name -split ":" | select -First 1
			if (!$Name)
			{
				$Name = $DatastoreCluster.Name
			}
			
			# Build report
			$SANNames = "" | Select vCenter, SAN
			$SANNames.vCenter = $vCenter
			$SANNames.SAN = $Name
		}
		
		# If there is a report, add it to an array
		if ($SANNames)
		{
			$SANList += $SANNames
		}
	}
$Progress2 = 0

# Disconnect from the vCenter
Disconnect-VIServer $vCenter -Confirm:$False -ErrorAction SilentlyContinue

# Add the array to the final report array
$Final += $SANList | Sort-Object -Property SAN -Unique | Where {$_.SAN -notmatch "boot"}
}
Write-Progress -Id 1 -Activity "Finding storage.." -Completed

# Display results to screen
$Final | Out-Gridview -PassThru
