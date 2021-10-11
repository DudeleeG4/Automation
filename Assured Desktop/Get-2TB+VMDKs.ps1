function Get-VMCustomer{
Param(
	[Parameter(ValueFromPipeline)]$VM
)
	Begin{
		if (!$Global:Accounts){
			$Global:Accounts = Get-EApiAccount
		}
	}
	Process{
		Foreach ($Machine in $VM){
			$Output = $Accounts | Where {$_.domainIdentifier -match ($Machine.Folder.Parent.Parent -split "-" | Select -Index 1)}
			if ($Output.count -gt 1){
				Continue
			}else{$Output}
		}
	}
}

#############################################################################################

Connect-CustomerVIServers

$HDDs = Get-VM | Where {$_.Name -notlike "vse-*"} | Get-HardDisk | Where {([Int]$_.CapacityGB) -gt 2000}

$Progress = 0
$Report = Foreach ($HDD in $HDDs){
	Write-Progress -Activity "Looping through Hard Disks" -PercentComplete ($Progress/$HDDs.Count*100)
	$Account = $HDD.Parent | Get-VMCustomer
	[PSCustomObject]@{
		VM = $HDD.Parent.name
		HardDisk = $HDD.Name
		"Size(GB)" = $HDD.CapacityGB
		Company = $Account.Company.Name
		Account = $Account.Name
		vCenter = $HDD.Parent.ExtensionData.Client.ServiceUrl -split "/" | Select -Index 2
	}
	$Progress ++
}

$OutPath = $Env

$Report | Export-Csv 