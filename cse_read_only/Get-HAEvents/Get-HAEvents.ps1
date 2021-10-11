# Load the VMWare Modules and then clear the console
Get-Module -listavailable | Where {$_.Name -like "VM*"} | Import-Module
clear

Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

# Prompt the user to enter the vCenter
$vCenterServer = Read-Host "Enter the vCenter"
#########################################################################################################################################################

# Takes a VM retrieved via Get-View and retrieves the vOrg and OrgVDC/ResourcePool name
function Get-vOrg
{
	Param (

	[Parameter(ValueFromPipeline = $true)]
	[VMware.Vim.VirtualMachine[]]
	$ViewVM

	)
	process
	{
		foreach ($Item in $ViewVM)
		{
			$Parent = Get-View $Item.Parent
			$ParentParent = Get-View $Parent.Parent
			$OrgIDs = Get-View $ParentParent.Parent | Select -ExpandProperty Name	
			$OrgID = $OrgIDs -split {$_ -eq " " -or $_ -eq "-"} | select -First 3
			[PSCustomObject]@{
				ResourcePool = $ParentParent.Name
				vOrg = (($OrgID | Select -Index 0)+"-"+($OrgID | Select -Index 1)+"-"+($OrgID | Select -Index 2))
			}
		}
	}
}

#########################################################################################################################################################

# Takes a VM name and retrieves the GUID from it
function Get-GUID
{
	Param 
	(
		[Parameter(ValueFromPipeline = $true)]
		[String[]]
		$String
	)
	Process
	{
		foreach ($Item in $String)
		{
			$Item -split {$_ -eq "(" -or $_ -eq ")"} | select -Index 1
		}
	}
}

#########################################################################################################################################################

# Create a calendar pop up form for the user to select the date
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

##########################################################################################################################################################


# Get current date in UK format
$Today = Get-Date -Format "dd-MM-yyyy"

# Get the date the user selected previously
$filedate = $($dtmdate.ToShortDateString()) -Replace "/", "-"

# Define output path for script
$outpath = "C:\Scripts\Technology\NOC\HA Events\HA Events on $FileDate.csv"
$Items = 0

# Define the timeframe to search for HA events, starting at the date selected by the user and finishing 1 day after
$StartDate = $dtmDate
$FinishDate = $StartDate.AddDays(1)

# Connect to the selected vCenters
Write-Host "Connecting to $vCenterServer..."
Connect-VIServer $vCenterServer

# Open an array to start building the report
$Final = @()

# Get all HA events that are in the specified timeframe
$Report = Get-VIEvent -maxsamples 10000 -Start $StartDate -Finish $FinishDate -type warning | Where {$_.FullFormattedMessage -match "restarted"} |select * |sort CreatedTime -Descending 
if (!$Report){
Write-Host "No HA events found"
Exit
}
# Loop through each event found
foreach ($Event in $Report)
{
	$Progress = $Event.FullFormattedMessage
	Write-Progress -Activity  "Finding HA Events..." -PercentComplete ($Items/$report.Count*100) -Status $Progress
    
    # Get the exact date of the HA event
	$Date = [datetime]$Event.CreatedTime
    
    # Get the VM Name from the Event
	$VM = $Event.ObjectName

    # Split the VM name string into just the GUID
	$VMGUID = Get-GUID ($VM)
	if (!$VMGUID)
	{
		$VMGUID = $VM
	}

    # Using the GUID, retrieve the Virtual machine using get-view
	$Filter = @{"Name" = $VMGUID}
	$CurrentVM = Get-View -ViewType VirtualMachine -Filter $Filter
	If ($CurrentVM)
	{	
        # Search for an event on the VM within an hour timeframe of the HA event which contains the text "To Green", this will be considered the time the VM has fully recovered
		$FinishedEvent = Get-VIEvent -entity $VM -maxsamples 100 -Start $Date -Finish $Date.AddHours(1)| Where {$_.FullFormattedMessage -match "to Green"} | sort CreatedTime | Select-Object -First 1	
		If ($FinishedEvent)
		{
            # Calculate the amount of time the VM was offline for
			$outage = New-TimeSpan -Start $Event.CreatedTime -End $FinishedEvent.CreatedTime
		}

        # Bit of string manipulation to get the date into UK format
		$outage2 = $outage -split {$_ -eq "." -or $_ -eq ":"} | select -First 3	
		$EventDate = $Date -split {$_ -eq " " -or $_ -eq "/"} | select -First 3
		$OutageEnd = $FinishedEvent.CreatedTime -split " " | select -Index 1
		$Downtime = (($outage2 | Select -Index 1)+":"+($outage2 | select -Index 2))
        
        # Retrieve the OrgVDC and vOrg from the VM
		$VMRPInfo = Get-vOrg ($CurrentVM)
		$ResourcePool = $VMRPInfo.ResourcePool
		$FinalvOrg = $VMRPInfo.vOrg
	}
	Elseif (!$CurrentVM)
	{	
		Write-Host "VM '$VM' no longer exists or has been renamed"
		$OutageEnd = "N/A"
		$Downtime = "N/A"
		$FinalvOrg = "N/A"
		$ResourcePool = "VM No longer exists or has been renamed"
	}

    # Build the report
	$info = [PSCustomObject]@{
	Date = (($EventDate | Select -Index 1)+"/"+($EventDate | select -Index 0)+"/"+($EventDate | Select -Index 2))
	VM = $VM
	"Resource Pool" = $ResourcePool
	"Customer Org ID" = $FinalvOrg
	"Outage Start" = $Event.CreatedTime -split " " | select -Index 1
	"Outage End" = $OutageEnd
	"Downtime" = $Downtime
	}
$Final += $info
$Items += 1
}

# Export the report
$Final | Export-Csv  $outpath -NoTypeInformation
Write-Host "Report created --> $outpath"
explorer /select,$outpath

Disconnect-VIServer * -Confirm:$false
