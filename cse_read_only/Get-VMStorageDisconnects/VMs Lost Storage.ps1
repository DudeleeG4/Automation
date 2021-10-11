# Load the PowerCLI modules and clear the console
Get-Module -ListAvailable | Where {$_.Name -like "VM*"} | Import-Module
Clear

Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

# Bring up a date selection GUI form
###############################################################

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object Windows.Forms.Form 

$form.Text = "Select a Date" 
$form.Size = New-Object Drawing.Size @(243,230) 
$form.StartPosition = "CenterScreen"

$calendar = New-Object System.Windows.Forms.MonthCalendar 
$calendar.ShowTodayCircle = $False
$calendar.MaxSelectionCount = 1
$form.Controls.Add($calendar) 

$OKButton = New-Object System.Windows.Forms.Button
$OKButton.Location = New-Object System.Drawing.Point(38,165)
$OKButton.Size = New-Object System.Drawing.Size(75,23)
$OKButton.Text = "OK"
$OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.AcceptButton = $OKButton
$form.Controls.Add($OKButton)

$CancelButton = New-Object System.Windows.Forms.Button
$CancelButton.Location = New-Object System.Drawing.Point(113,165)
$CancelButton.Size = New-Object System.Drawing.Size(75,23)
$CancelButton.Text = "Cancel"
$CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.CancelButton = $CancelButton
$form.Controls.Add($CancelButton)

$form.Topmost = $True

$result = $form.ShowDialog() 

if ($result -eq [System.Windows.Forms.DialogResult]::OK)
{
    $dtmdate = $calendar.SelectionStart
    Write-Host "Date selected: $($dtmdate.ToShortDateString())"
}

######################################################################

# Take the date from the form and format it
$filedate = $($dtmdate.ToShortDateString()) -Replace "/", "-"

# Prompt the user to enter the vCenter they want to connect to
$vCenterServer = Read-Host "Enter the vCenter"

# Get the current date and store it in a variable
$Today = Get-Date -Format "dd-MM-yyyy"

# Get Desktop Path
$DesktopPath = [Environment]::GetFolderPath("Desktop")

# Define the output path in the variable $output
$outpath = "$DesktopPath\StorageDisconnects.csv"

$Items = 0

# Create 2 variables containing the start and end dates to search for events between
$StartDate = $dtmDate
$FinishDate = $StartDate.AddDays(1)

# Connect to the specified vCenter
Write-Host "Connecting to $vCenterServer..."
Connect-VIServer $vCenterServer

$Final = @()

# Retrieve all vCenter events between the specified dates which indicate host storage disconnects
$Report = Get-VIEvent -maxsamples 300000 -Start $StartDate -Finish $FinishDate | Where {$_.FullFormattedMessage -match "Lost access"} |select * |sort CreatedTime -Descending

# Re-order and strip the results to just the properties we need
$Report2 = $Report | Select @{N="Host";E={$_.Host.Name}},@{N="Message";E={$_.FullFormattedMessage}}, @{N="Time";E={$_.CreatedTime}} | Sort Time

# Retrieve the datastores which hosts have reported a loss of access to
$report3 = $Report2.Message -split " " | Where {$_ -match "San"}
if (!$report3){
	$report3 = $Report2.message |% {$_ -split " \(" | Select -Last 1}
	$Datastores = $report3 |%{$_ -split "\) " | Select -First 1 } | Select -Unique
}else{
	$Report3 = $report3 -split "\)"
	$report3 = $report3 -split "\("
	$Datastores = $report3 | where {$_ -match "san"} | Select -unique
}

# From the affected datastores, retrieve the VMs which were also running on one of the affected hosts at the time of the disconnect, and are currently powered on
$VMs = Get-VM -Datastore $Datastores | Where {$_.PowerState -Like "PoweredOn"} | Where {$_.VMHost -in $Report2.Host} -ErrorAction SilentlyContinue

# Gather all events from the initial startdate onwards and filter for the VMs which have already been retrieved. Then, search for any that have been powered off or restarted since the storage disconnect.
$VMEventsRaw = Get-VIEvent -Start $StartDate -MaxSamples 100000 
$VMEvents = $VMEventsRaw | Where {$_.VM.Name -in $VMs.Name} | Where {$_.FullFormattedMessage -match "Powered"} | Where {$_.VM -notlike "$null"}
$VMEvents2 = $VMEventsRaw | Where {$_.FullFormattedMessage -match "restarted"}

# Retrieve the VMs from the first list of VMs which are not in the newer list of VMs. This leaves us with just VMs which have not been powered off or restarted since they had a storage disconnect.
$VMS2 = $VMs | Where {$_.Name -notin $VMEvents.VM.Name}# | Select @{N="VM";E={$_.Name}}

# Gather Affected VM Details
$Progress = 0
$Report = $VMs2 |%{
	Write-Progress -Activity "Gathering final VM Data.." -PercentComplete ($Progress/$VMs2.Count*100)
	[PSCustomObject]@{
		VM = $_
		vApp = $_.Folder
		OrgVDC = $_.Folder.Parent
		Organisation = $_.Folder.Parent.Parent
	}
	$Progress ++
}

# Export a CSV of the results to the user's desktop
$Report | Export-Csv $Outpath -NoTypeInformation

Disconnect-VIServer * -Confirm:$false
