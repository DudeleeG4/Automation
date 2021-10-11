###This script should act essentially as a sort of "storage DRS"###
Get-Module -ListAvailable | Where {$_.Name -like "VM*"} | Import-Module
clear
$vCenter = read-host "Please enter the name of the vCenter (example: vcw0000xix): "
$cred = Get-Credential -Message "Please enter your su username@ilxmanagement.local"
Write-Host "Connecting..."
Connect-viserver -Server $vCenter -Credential $cred
Write-Host "Finding Datastore Clusters..."

$report = @()
$final = @()
$DatastoreClusters = Get-DatastoreCluster -Server $vCenter | Out-GridView -Title "Please select a Datastore cluster" -Passthru
$tolerance = Read-Host "How close (in %) you want to balance the datastores compared to the cluster's average?"

Write-Host "Collecting datastore information (this takes a number of minutes)"
$Recommendations = 0
$ProvisioningCounter = 0
$VMUsedCounter = 0
$VMProvisionCounter = 0
$Progress = 1

###This gets storage balancing recommendations for each cluster chosen by the user###

foreach ($DatastoreCluster in $DatastoreClusters){


	###This retrieves a list of the emptiest Datastores within the chosen Datastore Cluster - $EmptyDSlist###

	$EmptiestDS = Get-Datastore -Location $DatastoreCluster | Sort FreeSpaceGB -Descending 
	$EmptyDSlist = @()
	foreach ($ds in $EmptiestDS) {
		$info3 = "" | select Provisioned, FreeSpaceGB, Name, "Total Capacity"
		$info3.Provisioned = [Math]::Round(($ds.ExtensionData.Summary.Capacity - $ds.ExtensionData.Summary.Freespace + $ds.ExtensionData.Summary.Uncommitted)/1GB,2)
		$info3.FreeSpaceGB = [Math]::Round(($ds.ExtensionData.Summary.Freespace/1GB),2)
		$info3.Name = $ds.Name
		$info3."Total Capacity" = [Math]::Round(($ds.ExtensionData.Summary.Capacity)/1GB,2)
		$EmptyDSlist += $info3
	}



	###This retrieves a list of all the over-provisioned Datastores within the chosen Datastore Dluster and then sorts them to show the most full ones first - $report###
	$Datastores = Get-Datastore -Location $DatastoreCluster
	foreach ($Datastore in $Datastores) {
		if ($Datastore -like "*boot*") {break}
		$Total = [Math]::Round(($Datastore.ExtensionData.Summary.Capacity/1GB),2)
		$Provisioned = [Math]::Round(($Datastore.ExtensionData.Summary.Capacity - $Datastore.ExtensionData.Summary.Freespace + $Datastore.ExtensionData.Summary.Uncommitted)/1GB,2)
		$Datastore | %{
			$info = "" | select "Datastore", "Datastore's Cluster", "Free Space", "Provisioning", "Over-Provisioned by:", "Top VM", "VM Disk Usage", "Recommended Move", "Destination Free Space", "Destination Provisioned", "Total Capacity"
			$info."Datastore" = $Datastore.Name
			$info."Datastore's Cluster" = $DatastoreCluster.Name
			$info."Free Space" = [Math]::Round(($Datastore.ExtensionData.Summary.Freespace/1GB),2)
			$info."Over-Provisioned by:" = [Math]::Round(($Provisioned - $Total),2)
			$info."Provisioning" = $Provisioned
			$info."Total Capacity" = $Total
			$report += $info
		}
		Write-Host -NoNewline "." 
	}
	
	
	$DatastoreConsumption = "" | select "Datastore Cluster", "Used Space %", "Provisioned Space %"
						$DatastoreConsumption."Datastore Cluster" = $DatastoreCluster
						$DatastoreConsumption."Used Space %" = (((($Report."Total Capacity" | Measure-Object -sum).sum)-(($Report."Free Space" | Measure-Object -Sum).sum))/(($Report."Total Capacity" | Measure-Object -Sum).sum)*100)
						$DatastoreConsumption."Provisioned Space %" = (((($Report.Provisioning | Measure-Object -Sum).sum)/(($Report."Total Capacity" | Measure-Object -Sum).sum))*100)
	
	#$DatastoreConsumption | Out-Gridview						
	
	$Report = $Report | Sort "Free Space"  | Select -First 20 | Where-Object {$_."Over-Provisioned by:" -gt 0}
	
	
	
	
	
	###This calculates which VMs to move from the Datastores in $Report to Datastores in $EmptyDSlist###
	foreach ($item in $report){	

					Write-Progress -Activity  "Generating Storage vMotion recommendations..." -PercentComplete ($Recommendations/$report.Count*100)
	
		
		
			###This line will sort the datastores in $EmptiestDS into Provisioned order and virtually "fill" each one before selecting the next###
			$EmptyDS = $EmptyDSlist | Sort Provisioned | Select -First $Progress | Select -last 1 
			$Target = (($DatastoreConsumption."Used Space %")+$tolerance)
			$FullDS = $item.Datastore
			$90PercentTotal = ($EmptyDS."Total Capacity" / 100 * $Target)
			$FreeSpaceCounter = ($EmptyDS."FreeSpaceGB" - "$VMUsedCounter")
			$UsedSpace = ($EmptyDS."Total Capacity" - $EmptyDS.FreeSpaceGB) 
			$NewUsedSpace = ($UsedSpace + $VMUsedCounter)
			$GoldenNumber = ($90PercentTotal - $NewUsedSpace)
		
		
			###This gets all the VMs on the full DS and calculates their total actual current usage on that DS - $Toast###		
			$VMs = Get-VM -Datastore $item.Datastore | Where-Object {$_.Name -notlike "avp*"} | Sort UsedSpaceGB -Descending
					$toast = @()
						foreach ($Virtual in $VMs){
						$TotalRootAccess = $Virtual.ExtensionData.LayoutEx.File | Where-Object {$_.Name -Like "*$FullDS*"}
						
						$Table = "" | select Name, UsedSpaceGB, DS
						$Table.Name = $Virtual.Name
						$Table.UsedSpaceGB = (($TotalRootAccess.Size | Measure-Object -sum).sum/1GB)
						$Table.DS = $FullDS
						$Toast += $Table
						}
						
			$VMs = $Toast | Sort UsedSpaceGB -descending
#$VMs | Out-Gridview
			###This calculates the provisioned space for each VM on the datastore and combines the data with the VMDK usage found in $toast - $VMDKs###						
						
					$HDs = Get-HardDisk -VM $VMs.Name | Where-Object {$_.Filename -like "*$FullDS*"}
					$VMDKs = @()
					foreach ($HD in $HDs)
					{			$VMName = $HD.ParentID
							$Filter = @{"Name" =$VMName}
						
						
							if($HD.Parent -ne $VMDKs[-1].Name)	
							{
							$NewVM = $VMs | Where-Object {$_.Name -like $VMDKs[-1].name}
     						$NewRow = "" | select Name, HDD, Provisioning, HDDatastore, ProvisioningTotal, "UsageOnDS"
							$NewRow.Name = $VMDKs[-1].Name
	 						$NewRow.ProvisioningTotal = $ProvisioningCounter
							$NewRow.HDDatastore = $HD.filename
							$NewRow."UsageOnDS" = $NewVM.UsedSpaceGB
	 						$VMDKs += $NewRow
							$ProvisioningCounter = 0
							}			
				
					$info5 = "" | Select Name, HDD, Provisioning, HDDatastore, ProvisioningTotal, "UsageOnDS"
					$info5.Name = $HD.Parent
					$info5.HDD = $HD
					$info5.Provisioning = $HD.CapacityGB
					$info5.HDDatastore = $HD.Filename
					$ProvisioningCounter +=$HD.CapacityGB
						
					$VMDKs += $info5			
					}
				

			###This decides whether to pick VMs based on largest or smallest provisioning, depending on whether the target DS is under or over-provisioned, and then picks the VM (based on other things too) - $VM###
			If ($EmptyDS."Total Capacity" -lt $EmptyDS."Provisioned")
			{
			$VM = $VMDKs | Where-Object {($_.ProvisioningTotal -notlike "") -and ($_.name -notlike "")}| Select Name, ProvisioningTotal, "UsageOnDS", HDDatastore | Sort UsageOnDS -Descending | Where-Object {$_.UsageOnDS -lt $GoldenNumber} | select -First 5 | Sort Provisioning | Select -First 1
			}
			Else 
			{
			$VM = $VMDKs | Where-Object {($_.ProvisioningTotal -notlike "") -and ($_.name -notlike "")}| Select Name, ProvisioningTotal, "UsageOnDS", HDDatastore | Sort UsageOnDS -Descending | Where-Object {$_.UsageOnDS -lt $GoldenNumber} | select -First 1
			}
		<#		If (!$VM){
				$Target = ($Target + 5)
				$90PercentTotal = ($EmptyDS."Total Capacity" / 100 * $Target)
				$GoldenNumber = ($90PercentTotal - $NewUsedSpace)
					If ($EmptyDS."Total Capacity" -lt $EmptyDS."Provisioned")
					{
					$VM = $VMDKs | Where-Object {($_.ProvisioningTotal -notlike "") -and ($_.name -notlike "")}| Select Name, ProvisioningTotal, "UsageOnDS", HDDatastore | Sort UsageOnDS -Descending | Where-Object {$_.UsageOnDS -lt $GoldenNumber} | select -First 5 | Sort Provisioning | Select -First 1
					}
					Else 
					{
					$VM = $VMDKs | Where-Object {($_.ProvisioningTotal -notlike "") -and ($_.name -notlike "")}| Select Name, ProvisioningTotal, "UsageOnDS", HDDatastore | Sort UsageOnDS -Descending | Where-Object {$_.UsageOnDS -lt $GoldenNumber} | select -First 1
					}
				}	
		#>		
			
#$VM | Out-Gridview
			###This section builds the final table and fills it with information###	
			$VMUsedCounter +=$VM.UsageOnDS	
			$VMProvisionCounter +=$VM.ProvisioningTotal
			$info2 = "" | select "Datastore", "Datastore's Cluster", "Free Space", "Over-Provisioned by:", "Top VM", "VM Disk Usage", "VMDK Provisioning", "Recommended Move", "Destination Free Space", "Destination Provisioned", "Destination Total Capacity", "Free Space Afterwards", "Provisioning Afterwards"
			$info2."Datastore" = $item.Datastore
			$info2."Datastore's Cluster" = $item."Datastore's Cluster"
			$info2."Free Space" = $item."Free Space"
			$info2."Over-Provisioned by:" = $item."Over-Provisioned by:"
			$info2."Top VM" = $VM.Name
			$info2."VM Disk Usage" = $VM.UsageOnDs
			$info2."VMDK Provisioning" = $VM.ProvisioningTotal
			$info2."Recommended Move" = $EmptyDS."Name"
			$info2."Destination Free Space" = $EmptyDS."FreeSpaceGB"
			$info2."Destination Provisioned" = $EmptyDS."Provisioned" 
			$info2."Destination Total Capacity" = $EmptyDS."Total Capacity"
			$info2."Free Space Afterwards" = ($EmptyDS."FreespaceGB" - $VMUsedCounter)
			$info2."Provisioning Afterwards" = ($EmptyDS.Provisioned + $VMProvisionCounter)
			$final += $info2
			$Recommendations +=1
		
			###This will change the destination datastore once it reaches a defined threshold (theoretically)###

					if ((($EmptyDS."Total Capacity" - $EmptyDS.FreeSpaceGB) + $VMUsedCounter) -gt ($EmptyDS."Total Capacity" / 100 * ($DatastoreConsumption."Used Space %"))){
				
				$Progress +=1
				$VMUsedCounter = 0
				$VMProvisionCounter = 0
				}
					 
				
					#Write-Host $VMUsedCounter
					#Write-Host $Progress
			
	}
	
	
	$VMUsedCounter = 0
	$VMProvisionCounter = 0
	$Progress = 1
	
	
} 
$final2 = $final | Where-Object {$_."Free Space" -lt $_."Destination Free Space"} | sort "Datastore's Cluster", "Free Space" | Out-GridView -Title "Press OK to close" -Passthru


if ($final2){
$decision = Read-Host -Prompt "Are you sure you want to move these VMs? (Yes or No)"
if ($decision -match "Yes"){
foreach ($Recommendation in $final2){
		$finalDS = $Recommendation."Datastore"
		$finalVM = $Recommendation."Top VM"
		$finalhds = Get-HardDisk -VM $finalVM | Where-Object {$_.Filename -like "*$finalDS*"} 
	
				foreach ($finalhd in $finalhds){
				Move-HardDisk -RunAsync -Confirm:$false -HardDisk $finalhd -Datastore $Recommendation."Recommended Move"}
				}
			}	
		}
$final = $null
Disconnect-VIServer * -Confirm:$False
