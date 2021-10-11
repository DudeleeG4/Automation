Connect-VIServer vcw00009i2
$VMs = Get-VM | Where {$_.name -notlike "vse-*"}

$Progress = 0
$Report = Foreach ($VM in $VMs){
	Write-Progress -Activity "Looping Through VMs" -PercentComplete ($Progress/$VMs.Count*100)
    [PSCustomObject]@{
        Name = $VM.Name
        MemoryGB = [Int]$VM.MemoryGB
		VMHost = $VM.VMHost
		Org = $VM.Folder.Parent.Parent | Split-vCloudID | Select -First 1
		VDC = $VM.Folder.Parent | Split-vCloudID | Select -First 1
    }
	$Progress ++
}

$Report | Where {($_.Org -notlike "") -and ($_.VDC -notlike "vm") -and ($_.Org -notlike "vm")} | Export-Csv "C:\Users\sudandrews\Desktop\MattGough.csv" -NoTypeInformation