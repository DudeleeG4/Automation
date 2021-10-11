<#
.DESCRIPTION
Checks to see if adding additional space to a vDC is likely to put the datastore cluster over it's threshold.

.EXAMPLE
PS C:\> .\Show-StorageThreshold.ps1 -vCenter vcw0000ai2 -vDCName test-vdc -StorageGB 10000
	
.NOTES
Author: Dylan Coombes
Created: 29-08-2019
#>


param(
    [parameter(Mandatory=$true)]
    [string]$vCenter,

    [parameter(Mandatory=$true)]
    [string]$vDCName,

    [parameter(Mandatory=$false)]
    [string]$VMName,

    [parameter(Mandatory=$true)]
    [int]$StorageGB
)

$ErrorActionPreference = "Stop"

Import-Module VMware.PowerCLI

$Credential = Get-Credential -Message "Enter your username & password"
Connect-VIServer -server $vCenter -Credential $Credential | Out-Null
Write-Host -ForegroundColor Green "Successfully connected to vCenter"

$vDCs = Get-ResourcePool | Where-Object {$_.Name -like "*$vDCname*"}

foreach ($vDC in $vDCs) {

    Write-Host "------------- vDC is $vDC -------------"
    Write-Host " "

    if ([string]::IsNullOrEmpty($VM)) {
        $SelectedVM = $vDC | Get-VM
        $FinalVMs = $SelectedVM
        Write-Host -ForegroundColor Yellow "It is likely multiple VM's have been selected. Please check afterwards which datastore cluster is applicable."
        Write-Host -ForegroundColor Yellow "You can specify a specific VM as well as a vDC with the -VM parameter."
        Write-Host " "
    } else {
        $FinalVMs = $SelectedvDC | get-VM | Where-Object {$_.Name -Like "*$VM*"}
        Write-Host -ForegroundColor Green "the VM $FinalVMs has been found."
    }
    
    foreach ($FinalVM in $FinalVMs) {
        
        Write-Host "------------- VM is $FinalVM -------------"

        $Cluster = $FinalVM | Get-Datastore | Get-DatastoreCluster
        $ClusterName = $Cluster.Name
        
        Write-Host "------------- Cluster is $ClusterName -------------"
        Write-Host " "

        $ClusterFreeSpace = $Cluster.FreeSpaceGB
        $ClusterCapacity = $Cluster.CapacityGB
        $ClusterThreshold = ($ClusterCapacity/100)*85
        $ClusterUsed = ($ClusterCapacity - $ClusterFreeSpace)
        $Calculation = ($ClusterUsed + $StorageGB)
    
        if ($Calculation -gt $ClusterThreshold) {
            Write-Host -ForegroundColor Red "Cluster Used Space is $ClusterUsed GB"
            Write-Host -ForegroundColor Red "Cluster Threshold at $ClusterThreshold GB Used"
            Write-Host -ForegroundColor Red "Requested Storage Totals $Calculation GB"
            Write-Host -ForegroundColor Red "This is ABOVE the threshold"
        } else {
            Write-Host -ForegroundColor Green "Cluster Used Space is $ClusterUsed GB"
            Write-Host -ForegroundColor Green "Cluster Threshold at $ClusterThreshold GB Used"
            Write-Host -ForegroundColor Green "Requested Storage Totals $Calculation GB"
            Write-Host -ForegroundColor Green "This is BELOW the threshold"
        }
    }
}