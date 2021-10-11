# Declare Variables
$JobArray = @()
Connect-VIServer vcw00002i2
$VMHosts = Get-VMHost
Disconnect-VIServer * -Confirm:$false

#Scriptblock for connecting to vcenters
$ConnectVCenters = {
	Connect-VIServer vcw00002i2
	$Global:VMHosts = Get-VMHost
}
 
#Actual Scriptblock
$ScriptBlock = {
	$Stat = Get-Stat -Entity $VMHost -MaxSamples 1 -Stat net.usage.average 
	[PSCustomObject]@{
		Host = $VMHost.name
		"NetworkUsage(KBps)" = [Int]$Stat.Value
	}
}

#Create runspace
$Runspaces = [runspacefactory]::CreateRunspace()
$Runspaces.Open()

# Create job that connects to vcentres
$job1 = [Powershell]::Create().AddScript($ConnectVCenters)
$Job1.Runspace = $Runspaces
$ASyncHandler = $Job1.BeginInvoke()

# Wait for job to connect to vcentres
Start-Sleep 1
while ($Job1.InvocationStateInfo.State -eq "Running") {
	Start-Sleep 1
}

$Job1.EndInvoke($ASyncHandler)

# Start jobs for checking hosts
foreach ($VMHost in $VMHosts) {
	$job2 = [Powershell]::Create().AddScript($ScriptBlock)
	$Job2.Runspace = $Runspaces
	$ASyncHandler2 = $Job2.BeginInvoke()
	$JobArray += [PSCustomObject]@{
		Job = $job2
		ASyncHandler = $ASyncHandler2
	}
}

# Wait for all jobs to be completed
while ($Job2.InvocationStateInfo.State -contains "Running") {
	Start-Sleep 1
}
 
# Retrieve info from jobs
forEach ($jobs in $JobArray) {
	$result = $Jobs.Job.EndInvoke($Jobs.ASyncHandler)
	Write-Host $result
}
 
# Close runspace
$Runspaces.Dispose() | Out-Null
