Import-Module ImportExcel
Add-PSSnapin vmware* -ErrorAction 'silentlycontinue'

Import-Module Microsoft.Powershell.Utility -ErrorAction 'silentlycontinue' -WarningAction 'silentlycontinue'
clear
# This script will create a report with all the datastores within a selected vCenter. It will give details such as Datastore and DatastoreCluster's names, total capacity, used space, free space and provisioned space.

function Get-DatastoreStats ( $vCenter ) {
	Connect-viserver -Server $vCenter -Credential $cred
	Write-Output ""
	Write-Host "Checking for datastores within $vCenter"

	$progress = 0
	$Report = $null
	$Report = @()

	$Datastores = Get-Datastore -Server $vCenter | Where-Object {$_.Name -like "*pod00018*"}
	foreach ($Datastore in $Datastores) {
		$Datastore | %{
			$info = "" | select "vCenter", "Datastore", "Total Capacity", "Used Space", "Free Space", "Provisioned", "OverProvisioned"
			$info."vCenter" = $Datastore.Client.ConnectivityService.ServerAddress
			$info."Datastore" = $Datastore
			$info."Total Capacity" = [Math]::Round(($Datastore.ExtensionData.Summary.Capacity/1TB),2)
			$info."Used Space" = [Math]::Round(($Datastore.ExtensionData.Summary.Capacity - $Datastore.ExtensionData.Summary.Freespace)/1TB,2)
			$info."Free Space" = [Math]::Round(($Datastore.ExtensionData.Summary.Freespace/1TB),2)
			$info."Provisioned" = [Math]::Round(($Datastore.ExtensionData.Summary.Capacity - $Datastore.ExtensionData.Summary.Freespace + $Datastore.ExtensionData.Summary.Uncommitted)/1TB,2)
			$info."OverProvisioned" = [Math]::Round(([Math]::Max($Datastore.ExtensionData.Summary.Uncommitted - $Datastore.ExtensionData.Summary.Freespace, 0))/1TB,2)
			
			$Report += $info
		}
	}


# Write-Host "DatastoreClusterConsumption Info: " $DatastoreClusterConsumption

	$progress += 1				
	# $script:final += $DatastoreConsumption	
	$script:final += $Report	

	Disconnect-viserver -Server $vCenter -Confirm:$false
}

######################################################################
# Main
######################################################################

## Global Vars
$final = @()

$unameS = "il2management\sciencelogicvcw"; $credsS = "As5^l2%j9^j1*u7*s9!"
$userPasswordS = ConvertTo-SecureString "$credsS" -AsPlainText -Force
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $unameS,$userPasswordS

#>
## PV2 - Pod 18
$vCenters = @(
  "vcv00007i2.pod00003.sys00004.il2management.local"
)
# foreach ($vCenter in $vCenters) { Get-DatastoreClusterStats ($vCenter) }
foreach ($vCenter in $vCenters) { Get-DatastoreStats ($vCenter) }

## Write Output
Write-Output ""
$gDate = Get-Date -Format "yyyy-MM-dd-HHmm"

# $outpath = "C:\Users\suajohnson\Documents\Datastore Clusters Report P18 $gDate.xlsx"
$outpath = "C:\ScheduledScripts\Storage Report\Datastore Report P18 $gDate.xlsx"
$oldfile = Get-Item $outpath -ErrorAction SilentlyContinue
$oldfile | Remove-Item -force

$c = New-ExcelChart -Title "Datastores" -ChartType BarStacked -Header "Title" -XRange "Datastores[Datastore]" -YRange @("Datastores[Used Space]","Datastores[Free Space]","Datastores[OverProvisioned]") -Height 1000 -Width 800 -ColumnOffSetPixels 120 -SeriesHeader "Used Space (TB)", "Total Space (TB)", "Provisioned Space (TB)" -ShowPercent
$final = $final | Sort vCenter, "Free Space"
$final | Export-Excel $outpath -AutoSize -TableName Datastores -ExcelChartDefinition $c

Send-MailMessage -SmtpServer rly00001i2 -From "datastoreclusterreport@ukcloud.com" -To "nocengineers@ukcloud.com", "nocshiftleaders@ukcloud.com" -Subject "Datastore Storage Report Pod18" -Body "See the attached document for information regarding the Datastore usage. " -Attachments $Outpath
