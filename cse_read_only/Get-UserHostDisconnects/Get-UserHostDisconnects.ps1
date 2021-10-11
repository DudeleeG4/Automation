Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

# Prompt the user to enter the vCenter
$vCenter = Read-Host -Prompt "Please enter the vCenter 'vcv00003i2'"

# Connect to selected vCenter
Connect-VIServer $vCenter

# Get 100000 events off of the vCenter
$Events = Get-VIEvent -MaxSamples 1000000 -Types Error 
$Events | Select CreatedTime, FullFormattedMessage, UserName | Sort CreatedTime -Descending | Out-Gridview

# Filter the events down to just host disconnect events
$Disconnects = $Events | Select CreatedTime, FullFormattedMessage, @{N="Host";E={$_.Host.Name}} | Sort CreatedTime -Descending | Where {$_.FullFormattedMessage -match "Host" -and ($_.FullFormattedMessage -match "is not responding")}
$Report = @()
$Progress = 0

# Loop through each event
Foreach ($Disconnect in $Disconnects)
{
	$TotalRootAccess = 0
	Write-Progress -Activity "Plundering anus" -PercentComplete ($Progress/$Disconnects.Count*100)
	$Date = [DateTime]$Disconnect.CreatedTime
	$HostEvents = Get-VIEvent -Entity $Disconnect.Host -Start $Date.AddHours(-1) -Finish $Date
	
	# Filter for just events triggered by users
	Foreach ($HostEvent in $HostEvents)
	{
		if ($HostEvent.Username -match "il2management\su")
		{
			$TotalRootAccess = 1
			break
		}
	}
	if ($TotalRootAccess = 1)
	{
		$Disconnect
	}
	else{$Report += $Disconnect}
	$Progress ++
}

$Report | Out-Gridview
Disconnect-VIServer * -Confirm:$false
