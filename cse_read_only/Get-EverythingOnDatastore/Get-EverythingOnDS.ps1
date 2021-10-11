Get-Module -ListAvailable | Where {$_.Name -like "VM*"} | Import-Module
clear

Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

# Prompt user for the vCenter they want to connect to
$vCenterServers = Read-Host -Prompt "vCenter:(vcw0000xxx)"

# Prompt user to enter their management credentials
$Cred = Get-Credential -Message "Please enter your management credentials"

$Report = $Null
$Report = @()
$Progress = 0

# Build an object with various properties to pass into another Object which will act as a query
$fileQueryFlags = New-Object VMware.Vim.FileQueryFlags
$fileQueryFlags.FileSize = $true
$fileQueryFlags.FileType = $true
$fileQueryFlags.Modification = $true

# Create the query object, containing the previous object
$searchSpec = New-Object VMware.Vim.HostDatastoreBrowserSearchSpec
$searchSpec.details = $fileQueryFlags
$searchSpec.sortFoldersFirst = $true

# Loop through the vCenters specified by the user
Foreach ($vCenterServer in $vCenterServers){
	
	# Connect to the vCenter
	Connect-VIServer $vCenterServer -Credential $Cred
	
	# Retrieve just the names of all Datastores on the vCenter and ask the user to select one or more
	$arrDS = Get-View -ViewType Datastore | Select Name | Out-GridView -Passthru
	
	# Use the selected datastore name to retrieve the Datastore View object(s)
	$arrDS = $arrDS |% {Get-View -ViewType Datastore -Filter @{Name=$_.Name}}
	
	# Loop through every datastore View object retrieved
	Foreach ($strDatastore in $arrDS){		
		$strDatastoreName = $strDatastore.name
		Write-Progress -Id 1  -Activity  "Browsing Datastore.." -PercentComplete ($Progress/$arrDS.Count*100) -CurrentOperation "Current Datastore is $strDatastoreName"
		$ds = $strDatastore
		
		# Retrieve the datastore browser for the current datastore
		$dsBrowser = Get-View $ds.browser
		
		# Assemble the root path of the datastore
		$rootPath = "["+$ds.summary.Name+"]"
		
		# This is where the method "SearchDatastoreSubFolders" is called on the datastore browser, with the root path specified and the query that I constructed earlier passed in
		$searchResult = $dsBrowser.SearchDatastoreSubFolders($rootPath, $searchSpec) | Select -ExpandProperty file
		
		# Loop through the query results and get the relevant details
		$Progress2 = 0
		foreach ($Result in $searchResult){
			Write-Progress -ParentId 1 -Activity "Gathering Files.." -PercentComplete ($Progress2/$searchResult.Count*100)
			$info = "" | Select Datastore, Filename, "Size in GB", "Last Modified"
			$info.Datastore = $strDatastore.Name
			$info.Filename = $Result.Path
			$info."Size in GB" = [Math]::Round($Result.FileSize/1000000000,2)
			$info."Last Modified" = $Result.Modification
			
			$Report += $info
			$Progress2 += 1
		}
		$Progress += 1
	}
}

Write-Progress -Id 1 -Activity "Browsing Datastore.." -Completed

Disconnect-VIServer * -Confirm:$false

# Show the results to the screen with Out-Gridview
$Report | sort "Size in GB" | Out-GridView -PassThru