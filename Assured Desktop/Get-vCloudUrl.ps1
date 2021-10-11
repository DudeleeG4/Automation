Function Find-VMName {
Param(
	[Parameter(ValueFromPipeline)]$Name,
	$VMList
)
	Process{
		Foreach ($VMName in $Name)
		{
			$VMList | Where {$_.name -match $VMName}
		}
	}
}

######################################################################################################################################################

Function Get-vCloudUrl {
Param (
	[Parameter(ValueFromPipeline)]$VMs,
	$VDCs,
	$vCenters
)
	Process {
		Foreach ($VM in $VMs) {
			$VDC = $VDCs | Where {$_.name -in $VM.vcloudVapp.vcloudVdc.name}
			$vCenter = $vCenters | Where {$_.name -in $VDC.vcloudPvdc.vcloudVcenter.name}
			$VCenter.vcloud.uri + "/cloud/#/vAppDiagram?vapp=" + ($VM.vcloudVapp.urn -split ":" | Select -last 1) + "&org=" + ($VM.vcloudVapp.vcloudVdc.vcloudOrg.urn -split ":" | Select -last 1)
		}
	}
}

######################################################################################################################################################

$SintAPIKey = Get-Content "C:\Scripts\Technology\CSE\Triage Scripts\SINTKey.txt"

$UserVMName = Read-Host -Prompt "Please enter VM name"

Get-EApiCreds | Get-EApiToken
Set-EApiHeaders

$VMJob = Start-Job -ArgumentList $Headers,$SintAPIKey,$Answer -Scriptblock {
	$Headers = $args[0]
	$SintAPIKey = $args[1]
	$Answer = $args[2]
	Get-EApiVM
}
$VDCJob = Start-Job -ArgumentList $Headers,$SintAPIKey,$Answer -Scriptblock {
	$Headers = $args[0]
	$SintAPIKey = $args[1]
	$Answer = $args[2]
	Get-EApiVdc
}
$VCJob = Start-Job -ArgumentList $Headers,$SintAPIKey,$Answer -Scriptblock {
	$Headers = $args[0]
	$SintAPIKey = $args[1]
	$Answer = $args[2]
	Get-EApiVCenter
}


$VMs = $VMJob | Wait-Job | Receive-Job
$VM = $VMs | Where {$_.name -match $UserVMName}
If ($VM.Count -gt 1){
	$VM = $VM.name | Invoke-MultiSelectForm | Find-VMName -VMList $VM
}Elseif ($VM.count -gt 20){
	$VM = $VM | Out-GridView -PassThru -Title "Please double click on selection"
}

Get-Job | Wait-Job
$VDCs = $VDCJob | Receive-Job
$vCenters = $VCJob | Receive-Job

$VM | Get-vCloudUrl -Vdcs $VDCs -vCenters $vCenters

$ExitCondition = "Yes","No" | Invoke-MultiSelectForm -Message "Do you want to search again?"

Do{
	If ($Username -or $VM){
		Remove-Variable UserVMName, VM
	}
	$UserVMName = Read-Host -Prompt "Please enter VM name"
	$VM = $VMs | Where {$_.name -match $UserVMName}
	If ($VM.Count -gt 1){
		$VM = $VM.name | Invoke-MultiSelectForm | Find-VMName -VMList $VM
	}Elseif ($VM.count -gt 20){
		$VM = $VM | Out-GridView -PassThru -Title "Please double click on selection"
	}
	$VM | Get-vCloudUrl -Vdcs $VDCs -vCenters $vCenters
	$ExitCondition = "Yes","No" | Invoke-MultiSelectForm -Message "Do you want to search again?"
}Until ($ExitCondition -match "No")

Read-Host -Prompt "Press enter to exit."