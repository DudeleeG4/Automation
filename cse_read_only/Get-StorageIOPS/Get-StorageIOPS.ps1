Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

# Connect to vCenter vcw00003i2
Connect-VIServer vcw00003i2

# Get Accenture's resource pool(s)
$RP = Get-ResourcePool | where{ $_.name -Like "Accenture - Production*"}

# Build an object containing the metrics I want to gather from the VMs
$metrics = "disk.numberwrite.summation","disk.numberread.summation"

# Get yesterday's date and store it in a variable
$start = (Get-Date).AddDays(-1)
$report = @()

# Get all of the VMs from the Resource Pools given.
$VMs = Get-VM -Location $RP | where {$_.PowerState -eq "PoweredOn"}

# Retrieve the read and write performance stats for the VMs
$stats = Get-Stat -Realtime -Stat $metrics -Entity $vms -Start $start

# Take the first stat from the results
$interval = $stats[0].IntervalSecs

# Get the VMFS disk data from the Datastores for each VM
$lunTab = @{}
foreach($ds in (Get-Datastore -VM $vms | where {$_.Type -eq "VMFS"})){
	$ds.ExtensionData.Info.Vmfs.Extent | %{
		$lunTab[$_.DiskName] = $ds.Name
	}
}

# Build Final report
$report = $stats | Group-Object -Property {$_.Entity.Name},Instance | %{
	[PSCustomObject] @{
		VM = $_.Values[0] | Select -Unique
		IOPSMax = ($_.Group | Group-Object -Property Timestamp | %{$_.Group[0].Value + $_.Group[1].Value} | Measure-Object -Maximum).Maximum / $interval
		IOPSWriteAvg = ($_.Group | where{$_.MetricId -eq "disk.numberwrite.summation"} | Measure-Object -Property Value -Average).Average / $interval
		IOPSReadAvg = ($_.Group | where{$_.MetricId -eq "disk.numberread.summation"} | Measure-Object -Property Value -Average).Average / $interval
		#Datastore = $lunTab[$_.Values[1]]
	}
}

# Export report to CSV
$report | sort -uniq -Property VM | Export-Csv "C:\Scripts\Technology\CSE\Accenture - Production IOPS Performance.csv"
