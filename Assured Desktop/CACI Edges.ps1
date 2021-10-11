Connect-CIServer vcloud

$Orgs = Get-Org | Where {$_.name -like "8-*"}

$Progress = 0
$Report = foreach ($Org in $Orgs){
	Write-Progress -Activity "Looping through Orgs" -PercentComplete ($Progress/$Orgs.Count*100)
	$OrgVDCs = Get-OrgVdc -Org $Org
	$Progress2 = 0
	foreach ($OrgVDC in $OrgVDCs){
		Write-Progress -Activity "Looping through VDCs" -PercentComplete ($Progress2/$OrgVDCs.Count*100) -Id 1
		$PvDC = Get-ProviderVdc -OrgVdc $OrgVDC
		[PSCustomObject]@{
			OrgVDC = $OrgVDC.Name
			vCenter = [String]$PvDC.ExtensionData.VimServer.Name
		}
		$Progress2 ++
	}
	$Progress ++	
}
$CDSZVDCs = $Report | Where-Object {($_.vCenter -like "vcw00007i3") -or ($_.vCenter -like "vcw00008i3")}

Connect-VIServer vcw00007i3, vcw00008i3

$RPs = foreach ($CDSZVDC in $CDSZVDCs){
	Get-ResourcePool | Where {$_.Name -match ([Regex]::Escape($CDSZVDC.OrgVDC))}
}

$VMs = $RPs |%{Get-VM -Location $_}
$VMNAs = $VMs | Get-NetworkAdapter | Where {$_.NetworkName -notmatch "none"}
$VSEs = Get-VM | Where {$_.name -like "vse-*"}
$VSENAs = $VSEs | Get-NetworkAdapter
$CACIVSEs = $VSENAs | Where {$_.NetworkName -in $VMNAs.NetworkName} | Select -ExpandProperty Parent | Sort -Unique

$Progress = 0
$Report = foreach ($CACIVSE in $CACIVSEs){
	Write-Progress -Activity "Looping through VMs" -PercentComplete ($Progress/$CACIVSEs.Count*100) -Id 0
	$Stats = $CACIVSE | Get-Stat -Stat net.usage.average -IntervalMins 30
	$Progress2 = 0
	foreach ($Stat in $Stats){
		Write-Progress -Activity "Looping through stats" -PercentComplete ($Progress2/$Stats.Count*100) -Id 1
		[PSCustomObject]@{
			Edge = $CACIVSE.name | Split-vCloudID | Select -First 1
			Time = $Stat.Timestamp.TimeOfDay
			Date = $Stat.Timestamp.Date -split " " | Select -First 1
			"Usage(Kbps)" = $Stat.Value
		}
		$Progress2 ++
	}
	$Progress ++
}