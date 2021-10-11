Function Get-vCloudUrl {
Param (
	[Parameter(ValueFromPipeline)]$VMs,
	$VDCs,
	$vCenters
)
	Process {
		Foreach ($VM in $VMs) {
			$VDC = $VDCs | Where {$_.id -in $VM.vcloudVapp.vcloudVdc.id}
			$vCenter = $vCenters | Where {$_.id -in $VDC.vcloudPvdc.vcloudVcenter.id}
			$VCenter.vcloud.uri + "/cloud/#/vAppDiagram?vapp=" + ($VM.vcloudVapp.urn -split ":" | Select -last 1) + "&org=" + ($VM.vcloudVapp.vcloudVdc.vcloudOrg.urn -split ":" | Select -last 1)
		}
	}
}

######################################################################################################################################################

Clear
$SintAPIKey = Get-Content "C:\Scripts\Technology\CSE\Triage Scripts\SINTKey.txt"
Get-EApiCreds | Get-EApiToken
Set-EApiHeaders

$VMStore = Get-Childitem | Where {$_.name -match "VMStore.xml"}
$CurrentDate = Get-Date
If(!$VMStore){
    $VMJob = Start-Job -ArgumentList $Headers,$SintAPIKey,$Answer -Scriptblock {
	    $Headers = $args[0]
	    $SintAPIKey = $args[1]
	    $Answer = $args[2]
	    Get-EApiVM
    }
    Write-Host "No VMStore present, building..."
    Start-Sleep -Seconds 1
    Write-Host "."
    Start-Sleep -Seconds 1
    Write-Host "."
    Start-Sleep -Seconds 1
    Write-Host "."
}ElseIf ([Datetime]$VMStore.LastWriteTime -lt $CurrentDate.AddDays(-1)){
    $VMJob = Start-Job -ArgumentList $Headers,$SintAPIKey,$Answer -Scriptblock {
	    $Headers = $args[0]
	    $SintAPIKey = $args[1]
	    $Answer = $args[2]
	    Get-EApiVM
    }
    Write "VMStore out of date, updating..."
    Start-Sleep -Seconds 1
    Write-Host "."
    Start-Sleep -Seconds 1
    Write-Host "."
    Start-Sleep -Seconds 1
    Write-Host "."
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

If ($VMJob){
    Try{
        $VMJob | Wait-Job | Receive-Job | Export-Clixml -Depth 20 "C:\Scripts\Technology\CSE\Triage Scripts\VMStore.xml"
    }Catch{
        Write-Host "Please delete VMStore.xml from C:\Scripts\Technology\CSE\Triage Scripts"
        Read-Host -Prompt "Press enter to exit"
    }
}
$VMStoreImportJob = Start-Job -ScriptBlock {
	Import-Clixml "C:\Scripts\Technology\CSE\Triage Scripts\VMStore.xml"
}
$UserVMName = Read-Host -Prompt "Please enter VM name"
Write-Host "Loading VM store..."
$VMs = $VMStoreImportJob | Wait-Job | Receive-Job
$VM = $VMs | Where {$_.name -match $UserVMName}

If ($VM.Count -gt 1){
	$VM = $VM | Invoke-MultiSelectForm
}Elseif ($VM.count -gt 20){
	$VM = $VM | Out-GridView -PassThru -Title "Please double click on selection"
}

If (!$VM){
	$ExitCondition = "Yes","No" | Invoke-MultiSelectForm -Message "No VM selected, do you want to search again?"
}Else{
	$VDCJob, $VCJob | Get-Job | Wait-Job
	$VDCs = $VDCJob | Receive-Job
	$vCenters = $VCJob | Receive-Job
	$Result = $VM | Get-vCloudUrl -Vdcs $VDCs -vCenters $vCenters
	$Result
	$Result | Set-Clipboard
	$ExitCondition = "Yes","No" | Invoke-MultiSelectForm -Message "Link copied to clipboard! Do you want to search again?"
}
If ($ExitCondition -match "Yes"){
	Do{
		If ($UserVMname) {Remove-Variable UserVMName}
	    If ($VM) {Remove-Variable VM}
	    If ($Result) {Remove-Variable Result}

		$UserVMName = Read-Host -Prompt "Please enter VM name"
		$VM = $VMs | Where {$_.name -match $UserVMName}
		If ($VM.Count -gt 1){
			$VM = $VM | Invoke-MultiSelectForm
		}Elseif ($VM.count -gt 20){
			$VM = $VM | Out-GridView -PassThru -Title "Please double click on selection"
		}
		$Result = $VM | Get-vCloudUrl -Vdcs $VDCs -vCenters $vCenters
	    $Result
	    $Result | Set-Clipboard
		$ExitCondition = "Yes","No" | Invoke-MultiSelectForm -Message "Do you want to search again?"
	}Until ($ExitCondition -match "No")
}
Read-Host -Prompt "Press enter to exit"