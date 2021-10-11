<#
.SYNOPSIS
Collect datastore metrics from vCenter and send them as a JSON file to Elasticsearch

.DESCRIPTION
This script connects to vCenter and collects minimum freespace for each datastore cluster.  The script uses Get-View
and foreach loops to improve script performance as much as possible.  
It is automated in a docker image on Openshift and runs every hour.

.INPUTS
This script requires 4 environment variables set (plus one optional):
$Env:ELKURI       - The URL of Eleasticsearch - if set to FALSE, will create Excel / CSV instead
$Env:CSVNAME      - (Optional) The name of the CSV file to write to if invoked manually - only runs if $Env:ELKURI set to FALSE
$Env:VCENTER_HOST - The FQDN of the vCenter
$Env:VCENTER_USER - vCenter username with administrative priveleges
$Env:VCENTER_PASS - Password for the username

.OUTPUTS
JSON file posted to elastic search

.NOTES
Version: 0.1
Author: Adrian Johnson
Creation Date: 22/07/2020
Purpose/Change: Additional metrics for minimum freespace per datastore

.EXAMPLE
Get-DS-MinFreeSpace.ps1
#>

$stopwatch = [system.diagnostics.stopwatch]::StartNew()

$ELKuri      = $Env:ELKURI
$CSVname     = $Env:CSVNAME
$vCenterHost = $Env:VCENTER_HOST
$vCenterUser = $Env:VCENTER_USER
$vCenterPass = $Env:VCENTER_PASS

# Script starts here
$now = (Get-Date).tostring("yyyy/MM/dd HH:mm:ss")

# Connect to vCenter 
Write-Host "$(Get-date)`tConnecting to VIServerand CisServer endpoints"
$VIServer = Connect-VIServer -Server $vCenterHost -User $vCenterUser -Password $vCenterPass -NotDefault
if(!$?) { 
    Write-Host -ForegroundColor Red "$(Get-Date)`tCan't connect to VIServer $vCenterHost.  Exiting..."
    $stopwatch.Stop()
    $stopwatch.Elapsed.TotalSeconds
    exit 
}

# Collect the metrics on a per datastore cluster basis
foreach ($cluster in (Get-DatastoreCluster -Server $VIServer | Where-Object {$_.Name -notlike "*boot*"})) {
    
	Write-Host -ForegroundColor Green "$(Get-Date)`t$vCenterHost : $cluster - begin fetch..."
    # Datastore Usage
	$DSs = Get-Datastore -Location $cluster
	if ($DSs.count -gt 0) { $DS_MOs = Get-View $DSs -Property Summary }
    # Write-Output $DS_MOs.Summary
	
	$dsTotal = ($DS_MOs.Summary.Capacity | Measure -Sum).Sum
	$dsFree = ($DS_MOs.Summary.FreeSpace | Measure -Sum).Sum
	$dsUncommited = ($DS_MOs.Summary.Uncommitted | Measure -Sum).Sum
	$dsDSCount = $DS_MOs.Count
	$dsMinFree = ($DS_MOs.Summary.FreeSpace | Measure -Minimum).Minimum
	foreach ($DS_MO in $DS_MOs) {if ($DS_MO.Summary.FreeSpace -eq $dsMinFree) { $dsMinName = $DS_MO.Summary.Name }}
		
    # Create a PSObject of the metrics needed and convert to JSON
    $obj = New-Object psobject
    $obj | Add-Member NoteProperty create_date $now
    $obj | Add-Member NoteProperty vCenter $vCenterHost
    $obj | Add-Member NoteProperty DatastoreCluster $cluster.Name

	# AJ - 2020-07-20 - Extended to find smallest datastore freespace
    $obj | Add-Member NoteProperty ClusterTotal_GB ($dsTotal / 1GB)
    $obj | Add-Member NoteProperty ClusterUsed_GB (($dsTotal - $dsFree) / 1GB)
    $obj | Add-Member NoteProperty ClusterProvisioned_GB (($dsTotal - $dsFree + $dsUncommited) / 1GB)
    $obj | Add-Member NoteProperty ClusterDSCount ($dsDSCount)
    $obj | Add-Member NoteProperty ClusterMinFree_GB ($dsMinFree / 1GB)
    $obj | Add-Member NoteProperty ClusterMinFree_Name ($dsMinName)

	if ($ELKuri -ne "FALSE") { 
		$output = ConvertTo-Json $obj
		Write-Host -ForegroundColor Green "$(Get-Date)`t$cluster metrics collected.  Posting to Elasticsearch..."
		Write-Host $output

		Invoke-RestMethod -Method POST -Uri $ELKuri -ContentType 'application/json' -Body $output 
	}
	else {
		$output = ($obj | Select create_date, vCenter, DatastoreCluster, ClusterTotal_GB, ClusterUsed_GB, ClusterProvisioned_GB, ClusterDSCount, ClusterMinFree_GB, ClusterMinFree_Name  | ConvertTo-Csv -NoTypeInformation ).split("`n") | select -skip 1
		Write-Host -ForegroundColor Green "$(Get-Date)`t$cluster metrics collected.  Posting to CSV $CSVName..."
		Write-Host $output
		
		Out-File -FilePath $CSVName -Append -InputObject $output
 	}
	
}

Disconnect-VIServer $VIServer -Confirm:$false

$stopwatch.Stop()
$stopwatch.Elapsed.TotalSeconds
