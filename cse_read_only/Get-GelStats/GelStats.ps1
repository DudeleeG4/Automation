Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

# Connect to the vCenter which holds GEL's PV1 environment
Connect-VIServer vcw00009i2

# Get the resource pool that was specified by TAM
$OrgVDC = Get-ResourcePool | Where {$_.Name -match "Microbiology"}

# Get the VMs from this resource pool
$VMs = $OrgVDC | Get-VM

# Build report by looping through all the VMs returned
$report = $VMs |% {

	# Retrieve all snapshots from the current VM
	$Snapshots = Get-Snapshot -VM $_
	
	# Check if any snapshots were retrieved and populate the variables which will be put in the report to reflect the results
	if (!$Snapshots) {
	$SnapshotNames = "No Snapshots Present"
	$SnapshotTotalSize = "N/A"
	$OldestSnapshot = "N/A"
	$NewestSnapshot = "N/A"
	}else{
	$SnapshotNames = $Snapshots.Name -join "`", `""
	$SnapshotTotalSize = (($Snapshots.SizeGB | Measure-Object -sum).sum)
	$OldestSnapshot = $Snapshots.Created | Sort | Select DateTime -First 1
	$OldestSnapshot = $OldestSnapshot.Datetime
	$NewestSnapshot = $Snapshots.Created | Sort -Descending | Select DateTime -First 1
	$NewestSnapshot = $NewestSnapshot.Datetime
	}
	
	# Retrieve the Disk names, IP addresses, CPU/Memory stats and the stats of the VM's host
	$VMDK = Get-HardDisk -VM $_
	$IPv4 = $_.Guest.IPAddress | Where {$_ -like "*.*.*.*"}
	$IPv6 = $_.Guest.IPAddress | Where {$_ -like "*:*"}
	$MemoryUsed = get-stat -Entity $_ -Realtime -Stat "Mem.Consumed.Average" -MaxSamples 1 -ErrorAction SilentlyContinue
	$MemoryUsedPercent = [Math]::Round((($memoryused.Value/1000/1000)/($_.MemoryGB)*100),2)
	$CPUUsage = get-stat -Entity $_ -Realtime -Stat "cpu.usage.average" -MaxSamples 1 -errorAction SilentlyContinue
	$HostMemoryUsage = [Math]::Round($_.VMHost.MemoryUsageGB*100/$_.VMHost.MemoryTotalGB,2)	
	$HostCPUUsage = [Math]::Round($_.VMHost.CpuUsageMhz*100/$_.VMHost.CpuTotalMhz,2)
	
	#Build the final report for the current VM
	[PSCustomObject]@{
	Name = $_.Name
	vApp = $_.Folder
	OrgVDC = $_.Folder.Parent
	"Power State" = $_.PowerState
	OS = $_.ExtensionData.Config.GuestFullName
	"VMWare Tools Status" = $_.Guest.ExtensionData.ToolsStatus
	VMDKs = $VMDK.Filename -join ", "
	"Snapshot Names" = $SnapshotNames
	"Snapshot Total Size" = $SnapshotTotalSize
	"Oldest Snapshot" = $OldestSnapshot
	"Newest Snapshot" = $NewestSnapshot
	"IPv4 Addresses" = $IPv4 -join ", "
	"IPv6 Addresses" = $IPv6 -join ", "
	"VM Memory MB" = $_.MemoryMB
	"VM Memory Used %" = $MemoryUsedPercent
	"VM CPU Provisioning MHz" = $_.ExtensionData.Runtime.MaxCpuUsage
	"VM CPU Usage %" = $CPUUsage
	"VMHost Memory Usage %" = $HostMemoryUsage
	"VMHost CPU Usage %" = $HostCPUUsage
	}
}

# Export the report to the specified filepath
$report | Export-Csv -NoTypeInformation "C:\Scripts\Technology\CSE\GELInfo.csv"

Write-Host "Report Generated at --> C:\Scripts\Technology\CSE\GELInfo.csv"
Read-Host -Prompt "Press enter to exit."
