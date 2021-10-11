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