Get-Module -ListAvailable | Where {$_.Name -like "VM*"} | Import-Module
clear
$Org = Read-Host -Prompt "Please enter your organisation"
Connect-CIServer "api.vcd.portal.skyscapecloud.gsi.gov.uk" -Org $Org
$OrgVDCName = Read-Host -Prompt "Please enter an OrgVDC"
if ($OrgVDCName)
{
	$OrgVDC = Get-OrgVdc -Name $OrgVDCName*
	$vApp = Get-CIVapp -OrgVdc $OrgVDC | Out-GridView -Title "Please select a vApp" -PassThru
	if ($vApp)
	{
		$VMs = Get-CIVM -VApp $vApp | Out-GridView -Title "Please select a VM" -PassThru
	}
	else
	{
		$VMs = Get-CIVM -OrgVdc $OrgVDC | Out-GridView -Title "Please select a VM" -PassThru
	}
}
Else
{
	$VMs = Get-CIVM 
	$VMs = $VMs | Out-GridView -Title "Please select a VM" -Passthru
}
$Report = $null
$Report = @()
$Progress = 0
foreach ($VM in $VMs)
{	
	Write-Progress -Activity "Gathering Network Adapters" -Id 1 -PercentComplete ($Progress/$VMs.Count*100)
	$VMNA = Get-CINetworkAdapter -VM $VM
	$info = "" | Select "VM", "OS", "Number of Adapters", "Adapter Types"
	$info.VM = $VM.Name
	$info.OS = $VM.GuestOsFullName
	$info."Number of Adapters" = $VMNA.Count
	$info."Adapter Types" = $VMNA.ExtensionData.NetworkAdapterType -join ', '
	$Progress += 1
	$Report += $info
}
Write-Progress -Activity "Gathering Network Adapters" -Id 1 -Completed
Disconnect-CIServer * -Confirm:$False
$FinalCount = $Report.Count
$Report | Out-Gridview -Title "$FinalCount VMs"