Connect-CustomerVIServers

$DatastoreClusters = Get-DatastoreCluster

$Progress = 0
$Report = Foreach ($DatastoreCluster in $DatastoreClusters){
	Write-Progress -Activity "Looping through Datastore Clusters" -PercentComplete ($Progress/$DatastoreClusters.Count*100) -Id 0
	$ClusterTags = $DatastoreCluster | Get-TagAssignment
	$Datastores = $DatastoreCluster | Get-Datastore
	$Progress2 = 0
	Foreach ($Datastore in $Datastores){
		Write-Progress -Activity "Looping through Datastores" -PercentComplete ($Progress2/$Datastores.Count*100) -Id 1
		$DatastoreTags = $Datastore | Get-TagAssignment
		[PSCustomObject]@{
			"Cluster" = $DatastoreCluster.Name
			"Cluster Tags" = $ClusterTags.Tag -join ", "
			"Datastore" = $Datastore.Name
			"Datastore Tags" = $DatastoreTags.Tag -join ", "
		}
		$Progress2 ++
	}
	$Progress ++
}

$OutPath = [Environment]::GetFolderPath("Desktop") + "\DatastoreTagComparison.csv"
$Report | Export-csv $OutPath -NoTypeInformation