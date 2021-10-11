clear

Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

$report = @()
$VMs = Get-VM | Where {$_.Powerstate -like "PoweredOn"} | Select -first 200 
foreach ($VM in $vms){
	$memoryused = get-stat -Entity $VM -Realtime -Stat "Mem.Consumed.Average" -MaxSamples 1
	$cpuused = Get-Stat -Entity $VM -Realtime -Stat "cpu.usage.average" -MaxSamples 1
	$info = "" | Select MemoryUsed, TotalMemory, CPU
	$info.MemoryUsed = ($memoryused.Value/1000/1000)/($VM.MemoryGB)*100
	$info.TotalMemory = $VM.MemoryGB
	$info.cpu = $cpuused
	$report += $info
	}
