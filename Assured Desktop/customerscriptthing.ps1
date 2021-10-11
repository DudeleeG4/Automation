Function Get-VMPerfStats {
	Param(
		[Parameter(ValueFromPipeline)]$ResourcePool
	)
	Process{
		#$RPs = Get-ResourcePool | Where {($_.name -match "YJFT-CUG-IL3-PROD") -or ($_.name -match "YJFT-GSI-IL3-PROD")}
		$VMs = $ResourcePool | Get-VM
		$Progress = 0
		foreach ($VM in $VMs){
			Write-Progress -Activity "Looping through VMs" -PercentComplete ($Progress/$VMs.Count*100) -Id 0
			if ($VM.PowerState -match "PoweredOn"){
				$CPUStats = $VM | Get-Stat -Stat "cpu.usage.average"
				$MemStats = $VM | Get-Stat -Stat "mem.usage.average"
				$Progress2 = 0
				foreach ($CPUStat in $CPUStats){
					Write-Progress -Activity "Looping through stats" -PercentComplete ($Progress2/$CPUStats.Count*100) -Id 1
					$MemStat = $MemStats[$Progress2]
					[PSCustomObject]@{
						VM = $VM.Name
						Timestamp = $CPUStat.Timestamp
						CPUStat = $CPUStat.MetricId
						CPUValue = [Float]$CPUStat.Value
						CPUUnit = [String]$CPUStat.Unit
						MemStat = $MemStat.MetricId
						MemValue = [Float]$MemStat.Value 
						MemUnit = [String]$MemStat.Unit
					}
					$Progress2 ++
				}
				$Progress ++
			}
			else {
				Continue
			}
		}
	}
}


Connect-VIServer (Get-CustomerVIServers | Invoke-MultiSelectForm)

$RPs = Get-ResourcePool | Where {($_.name -match "YJFT-TRN-IL2-PROD") -or ($_.name -match "A-POW-YJAF-Gateway")}

$Report = $RPs | Get-VMPerfStats