Get-Module -listavailable | Where {$_.Name -Like "VM*"} | Import-Module
Clear

Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

# Create variable for the user's desktop path
$DesktopPath = [Environment]::GetFolderPath("Desktop")
# Ask for the user's management credentials
$Credential = Get-Credential -Message "Please enter your management credentials"
# Connect to all PV1 assured vCenters
$vCenterServers = @("vcw00001i2", "vcw00002i2", "vcw00003i2", "vcw00004i2", "vcw00005i2", "vcw00007i2", "vcw00008i2", "vcw00009i2", "vcw0000ai2")
Connect-VIServer $vCenterServers -Credential $Credential

# Open an empty array, ready to add the results into
$Report = @()

# Get the View objects for all avamar proxies
$avpsraw = Get-View -ViewType VirtualMachine -Filter @{Name = "avp0"}
# From these View objects, retrieve the full Vim objects
$AVPs = Get-VM -Name $avpsraw.name | where {$_.Name -like "avp0*"}
# Create a variable to contain the state that I want to retrieve for each VM
$stats = "cpu.costop.summation"
# Start looping through the VMs
$percent = 0
foreach ($AVP in $AVPs){
$percent += 1
Write-Progress -Activity "Getting co-stop data.." -PercentComplete ($percent/$AVPs.Count*100) -Id 1

# Gather the AVPs' Co-Stop statistics and build an array with the results
$progress = 0
$Stats = $avp | Get-Stat -Start (Get-Date).AddDays(-1) -Stat cpu.costop.summation -ErrorAction SilentlyContinue
	foreach ($stat in $stats)
	{	
		$progress += $stat.Value
	}
# Build an object listing the VM's general details plus the Average co-stop figure
$stats = $AVP | select @{N="vCenter";E={$_.Client.ConnectivityService.ServerAddress}}, Name, NumCpu, MemoryGB, PowerState,  @{N="Co Stop Average";E={$progress/$stats.count}}
# Add the object to the report
$Report += $stats
}
Write-Progress -Activity "Getting co-stop data.." -Completed -Id 1
# Export the report to the user's desktop
$Report | sort vCenter | Export-Csv "$DesktopPath\AVPsList.csv" -NoTypeInformation
Disconnect-VIServer * -Confirm:$False
