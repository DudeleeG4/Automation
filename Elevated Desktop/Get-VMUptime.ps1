Function Get-VMUptime {
Param(
	[Parameter(ValueFromPipeline)]$vCenters,
	$Cred
)
	Process{
		Foreach ($vCenter in $vCenters){
			Start-Job -ArgumentList $vCenter, $Cred -ScriptBlock {
				Connect-VIServer $args[0] -Credential $args[1] | Out-Null
				$VMs = Get-VM
				Foreach ($VM in $VMs){
					$Stat = $VM | Get-Stat -Stat sys.uptime.latest -Realtime -MaxSamples 1 -ErrorAction SilentlyContinue
					Try {
						$Timespan = New-Timespan -Seconds $Stat.Value
						$OSUptime = "" + $Timespan.Days + " Days, " + $Timespan.Hours + " Hours, " + $Timespan.Minutes + " Minutes"
						if($Timespan.Days -gt 182.5){
							$6Month = "Yes"
						}else{$6Month = "No"}
					}
					Catch{
						$OSUptime = "Not Retrieved"
						$6Month = "Unknown"
					}
					[PSCustomObject]@{
						vCenter = $VM.Client.ConnectivityService.ServerAddress
						Name = $VM.name
						OSUptime = $OSUptime
						"6 Months +" = $6Month
					}
				}
			} | Out-Null
		}
		$Results = Get-Job | Wait-Job | Receive-Job
		$Results | Select vCenter, Name, OSUptime, "6 Months +"
	}
}