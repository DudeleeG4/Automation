# Import the PowerCLI modules and clear the console
Get-Module -ListAvailable | where {$_.Name -like "VM*"} | Import-Module
Clear

Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

# prompt the user for their management credentials
$cred = Get-Credential -Message "Please enter your su username@il3management.local"

# find the current user's path to their desktop and store it in a variable
$DesktopPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
$Progress = 0

# define which vCenters to connect to
$vCenterServers = @("vcw00001i3.il3management.local","vcw00002i3.il3management.local","vcw00003i3.il3management.local","vcw00004i3.il3management.local","vcw00005i3.il3management.local","vcw00007i3.il3management.local","vcw00008i3.il3management.local", "vcv00002i3.pod0000d.sys00005.il3management.local", "vcv00003i3.pod0000d.sys00005.il3management.local", "vcv00004i3.pod00012.sys00006.il3management.local", "vcv00005i3.pod00012.sys00006.il3management.local")
Write-Host "Connecting to $vCenter..."

# Connect to the vCenters defined in $vCenterServers
Connect-VIServer -Server $vCenterServers -Credential $cred
Write-Host "Searching for deltas..."

# Retrieve all of the VMs on the vCenters using Get-View and loop through them
$VMList = get-view -viewtype virtualmachine
$report = foreach ($vmview in $VMList){ 
$Progress += 1
Write-Progress -Activity "Retrieving Deltas..." -PercentComplete ($Progress/$VMList.Count*100)
		# Dive into the VM's hardware info and create a report for only disks which match the snapshot naming convention
       $vmview.Config.Hardware.Device | ? {$_ -is [VMware.Vim.VirtualDisk]} |
              %{
              $_.Backing | select @{N="VMname";E={$vmview.name}},Filename | ?{$_.FileName.Split('/')[-1] -match ".*\-[0-9]{6}\.vmdk"} 
              }  
			  
}
$report | sort VMName | Export-Csv "$DesktopPath\Deltas IL3.csv"
Disconnect-VIServer * -Confirm:$false
