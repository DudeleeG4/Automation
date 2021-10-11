Import-Module ImportExcel
#Add-PSSnapin vmware* -ErrorAction 'silentlycontinue'
Get-Module -ListAvailable | Where-Object {$_.Name -like "VMware*"}  | ForEach-Object {import-module -name $_}
Import-Module Microsoft.Powershell.Utility -ErrorAction 'silentlycontinue' -WarningAction 'silentlycontinue'
clear
#This script will create a report with all the datastores within a selected vCenter. It will give details such as Datastore and DatastoreCluster's names, total capacity, used space, free space and provisioned space.
$unameS = "il3management\sciencelogicvcw"
$credsS = 'Sd4^l6$o9*z8^t7%r1!'
	$userPasswordS = ConvertTo-SecureString "$credsS" -AsPlainText -Force
	$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $unameS,$userPasswordS
$vCenter = @("vcw00001i3.il3management.local","vcw00002i3.il3management.local","vcw00003i3.il3management.local","vcw00004i3.il3management.local","vcw00005i3.il3management.local","vcw00007i3.il3management.local","vcw00008i3.il3management.local", "vcv00002i3.pod0000d.sys00005.il3management.local", "vcv00003i3.pod0000d.sys00005.il3management.local", "vcv00004i3.pod00012.sys00006.il3management.local", "vcv00005i3.pod00012.sys00006.il3management.local", "vcv00006i3.pod00015.sys00009.il3management.local", "vcv00008i3.pod00015.sys00009.il3management.local", "vcv00007i3.pod00016.sys0000a.il3management.local", "vcv00009i3.pod00016.sys0000a.il3management.local")
Connect-viserver -Server $vCenter -Credential $cred
Write-Output ""
Write-Host -NoNewline "Checking for datastores within $vCenter"

$progress = 0
$final = @()
$DatastoreClusters = Get-DatastoreCluster -Server $vCenter | Where-Object {$_.Name -notlike "*boot*"}
foreach ($DatastoreCluster in $DatastoreClusters)
{
Write-Progress -Activity "Calculating storage properties..." -PercentComplete ($progress/$DatastoreClusters.Count*100)
$report = $null
$report = @()
	$Datastores = Get-Datastore -Location $DatastoreCluster
	foreach ($Datastore in $Datastores) {
	
			if ($Datastore -like "*boot*") {
			break
			}
			$Datastore | %{
				$info = "" | select "vCenter", "Datastore", "Total Capacity", "Used Space", "Free Space", "Provisioned"
				$info."vCenter" = $Datastore.Client.ConnectivityService.ServerAddress
				$info."Datastore" = $Datastore
				$info."Total Capacity" = [Math]::Round(($Datastore.ExtensionData.Summary.Capacity/1GB),2)
				$info."Used Space" = [Math]::Round(($Datastore.ExtensionData.Summary.Capacity - $Datastore.ExtensionData.Summary.Freespace)/1GB,2)
				$info."Free Space" = [Math]::Round(($Datastore.ExtensionData.Summary.Freespace/1GB),2)
				$info."Provisioned" = [Math]::Round(($Datastore.ExtensionData.Summary.Capacity - $Datastore.ExtensionData.Summary.Freespace + $Datastore.ExtensionData.Summary.Uncommitted)/1GB,2)
				
				$report += $info
			}
			
				
			 
	}$DatastoreConsumption = "" | select "vCenter", "Datastore Cluster", "Total Space(TB)", "Used Space(TB)", "Provisioned Space(TB)"
                        $VC = $Datastore.Uid -split {($_ -eq "\") -or ($_ -eq ":") -or ($_ -eq "@") -or ($_ -eq ".")} | Select -Index 2
						$DatastoreConsumption."vCenter" = $VC
						$DatastoreConsumption."Datastore Cluster" = (($VC)+":"+($DatastoreCluster))
						$DatastoreConsumption."Total Space(TB)" = ([Math]::Round($DatastoreCluster.CapacityGB,2))/1000
						$DatastoreConsumption."Used Space(TB)" = ([Math]::Round((($Report."Total Capacity" | Measure-Object -sum).sum)-(($Report."Free Space" | Measure-Object -Sum).sum),2))/1000
						$DatastoreConsumption."Provisioned Space(TB)" = ([Math]::Round((($Report."Provisioned" | Measure-Object -Sum).sum),2))/1000
$progress += 1				
$final += $DatastoreConsumption	

}
Write-Output ""
$gDate = Get-Date -Format "dd-MM-yyyy"
#$DesktopPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
$outpath = "C:\ScheduledScripts\Storage Report\Datastore Clusters Report IL3 $gDate.xlsx"
$final = $final | sort-object "vCenter", "Datastore's Cluster", "Datastore" 
$oldfile = Get-Item $outpath -ErrorAction SilentlyContinue
$oldfile | Remove-Item -force



$c = New-ExcelChart -Title "DatastoreClusters" -ChartType BarClustered3D -Header "Title" -XRange "DatastoreClusters[Datastore Cluster]" -YRange @("DatastoreClusters[Used Space(TB)]","DatastoreClusters[Total Space(TB)]","DatastoreClusters[Provisioned Space(TB)]") -Height 1200 -Width 1000 -ColumnOffSetPixels -60 -SeriesHeader "Used Space (TB)", "Total Space (TB)", "Provisioned Space (TB)" -ShowPercent
$final = $final | Sort vCenter, "Datastore Cluster" -descending
$final |
    Export-Excel $outpath -AutoSize -TableName DatastoreClusters -ExcelChartDefinition $c

#Send-MailMessage -SmtpServer 10.72.81.30 -From "datastoreclusterreport@ukcloud.com" -To "storage@skyscapecloud.com" "ajohnson@ukcloud.com" -CC "nocengineers@ukcloud.com" "nocshiftleaders@ukcloud.com" -Subject "Datastore Clusters Storage Report IL3" -Body "See the attached document for information regarding the Datastore Clusters usage" -Attachments $Outpath


Disconnect-viserver * -Confirm:$false