# Declare Variables
$JobArray = @()
Connect-VIServer vcw00002i2
$VMHosts = Get-View -ViewType HostSystem -Property Name | Select-Object -ExpandProperty Name
 
#Create runspace
$InitialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault2()
$InitialSessionState.ImportPSModule((Get-Module -listavailable -Name "*VMware*"))
$RunspacePool = [runspacefactory]::CreateRunspacePool($InitialSessionState)
$RunspacePool.SetMaxRunspaces($VMHosts.Count)
$RunspacePool.Open()

# Start jobs for checking hosts
foreach ($VMHost in $VMHosts) {
#Actual Scriptblock
$ScriptBlock = @"
Set-PowerCLIConfiguration -DisplayDeprecationWarnings:`$false -Scope Session -confirm:`$False | out-null;
Connect-ViServer -Server $($DefaultVIServer.name) -session $($DefaultVIServer.SessionSecret) | out-null;
`$Stat = Get-Stat -Entity $VMHost -MaxSamples 1 -Stat net.usage.average
[PSCustomObject]@{
Host = $VMHost.name
"NetworkUsage(KBps)" = [Int]`$Stat.Value
}
"@
$scriptBlock = [Scriptblock]::Create($ScriptBlock)
$job2 = [Powershell]::Create().AddScript($ScriptBlock)
$Job2.RunspacePool = $RunspacePool
$ASyncHandler2 = $Job2.BeginInvoke()
$JobArray += [PSCustomObject]@{
	Job = $job2
	ASyncHandler = $ASyncHandler2
}
}
# Wait for all jobs to be completed
while ($JobArray.job.InvocationStateInfo.State -contains "Running") {
Start-Sleep 1
}

# Retrieve info from jobs
forEach ($jobs in $JobArray) {
$result = $Jobs.Job.EndInvoke($Jobs.ASyncHandler)
Write-Host $result
}

# Close runspace
$RunspacePool.Dispose()