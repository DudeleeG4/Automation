<#
.SYNOPSIS
	Retrieves as much useful information about one or more VMs as possible
.DESCRIPTION
	This is a script which is used by the CSE triage team to gather useful information automatically to
	pass to CSE POD1 to enable easier troubleshooting.
	As it is a fully formed script, it prompts the user to enter their details as required.
.NOTES
	Author:  Dudley Andrews
#>


# Check if the user is running the script as administrator and if not, elevate to administrator privileges

If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))

{   
$arguments = "& '" + $myinvocation.mycommand.definition + "'"
Start-Process powershell -Verb runAs -ArgumentList $arguments
Break
}

# Import the PowerCLI Modules
Get-Module -ListAvailable | Where {$_.Name -like "VM*"} | Import-Module
Clear

# Try to Import the UKCloud Modules
Try {
	Import-Module UKCloud.EstateAPI
	Import-Module UKCloud.Support
}Catch{
	Write-Error -Message "Could not import UKCloud modules"
	Read-Host -Prompt "Press enter to exit"
	Break
}

Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

Function LogWrite {
<#
.SYNOPSIS
	Writes a simple string to a .txt file
.DESCRIPTION
 	Just a little custom function to write basic strings to a .txt file
.NOTES
	Author:  Dudley Andrews
#>
   Param (
   [string]$logstring,
   [Parameter(Mandatory=$True)]$file
   )

   Add-content $file -value $logstring
}


function Get-VMLog{
<#
.SYNOPSIS
	Retrieve the virtual machine logs
.DESCRIPTION
	The function retrieves the logs from one or more
	virtual machines and stores them in a local folder
.NOTES
	Author:  Luc Dekens, modified by Dudley Andrews
.PARAMETER VM
	The virtual machine(s) for which you want to retrieve
	the logs.
.PARAMETER Path
	The folderpath where the virtual machines logs will be
	stored. The function creates a folder with the name of the
	virtual machine in the specified path.
.EXAMPLE
	PS> Get-VMLog -VM $vm -Path "C:\VMLogs"
.EXAMPLE
	PS> Get-VM | Get-VMLog -Path "C:\VMLogs"
#>
 
	param(
	[parameter(Mandatory=$true,ValueFromPipeline=$true)]
	[PSObject[]]$VM,
	[parameter(Mandatory=$true)]
	[string]$Path
	)
 
	process{
		foreach($obj in $VM){
			if($obj.GetType().Name -eq "string"){
				$obj2 = Get-VM -Name $obj
				if ($obj2){$obj = $obj2}
				elseif (!$obj) {
				$objGUID = $obj -split {$_ -eq "(" -or $_ -eq ")"} | select -Index 1
				$obj = Get-VM | Where {$_.Name -match $obj}
			}
		}
		}
		$logPath = $obj.Extensiondata.Config.Files.LogDirectory
		$dsName = $logPath.Split(']')[0].Trim('[')
		$vmPath = $logPath.Split(']')#[1].Trim(' ')
		if ($vmPath.Count -gt 2){
		$vmPath2 = $vmPath[1..($vmPath.Length-1)]
		$vmpath3 = $vmPath2 -join "]"
		$vmpath4 = $vmpath3.Trim(' ')
		$vmpath5 = $vmpath4.Replace("[","``[")
		$vmPath = $vmpath5.Replace("]","``]")
		}
		else {$vmPath = $vmPath[1].Trim(' ')}
		$ds = Get-Datastore -Name $dsName
		$drvName = "MyDS" + (Get-Random)
		New-PSDrive -Location $ds -Name $drvName -PSProvider VimDatastore -Root '\' | Out-Null
		Copy-DatastoreItem -Item ($drvName + ":" + $vmPath + "\" + "*.log*") -Destination ($Path + "\" + $obj.Name + "\") -Force:$true
		Remove-PSDrive -Name $drvName -Confirm:$false
	}
}

###############################################################################################################

# Create a GUI form asking the user to enter the VM name and whether they want to gather various log files

# Ensure that the user cannot continue without completing the form
Do{
	$NewVariables = @()
	$Position = 10
	Add-Type -AssemblyName System.Windows.Forms
			
	$form = New-Object Windows.Forms.Form
	$form.Size = New-Object Drawing.Size @(500,(175))
	$form.text = "Input Details"
	$form.StartPosition = "CenterScreen"
	$form.Add_Shown({$form.Activate()})
		
	### Create Okay Button ###
	$okbtn = New-Object System.Windows.Forms.Button
	$okbtn.Location =  New-Object Drawing.Size @(275,(110))
	$okbtn.Add_Click($eventHandler)
	$okbtn.DialogResult = [System.Windows.Forms.DialogResult]::OK
	$okbtn.Text = "Go..."
	$form.Controls.Add($okbtn)
				
	### Create Cancel Button ###
	$cancelbtn = New-Object System.Windows.Forms.Button
	$cancelbtn.Location =  New-Object Drawing.Size @(175,(110))
	$cancelbtn.Add_Click($eventHandler)
	$cancelbtn.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
	$cancelbtn.Text = "Cancel"
	$form.Controls.Add($cancelbtn)
			
	### Ask First Question ###
	$objLabel = New-Object System.Windows.Forms.Label
	$objLabel.Location = New-Object System.Drawing.Size(0,10)
	$objLabel.Size = New-Object System.Drawing.Size(150,20)
	$objLabel.Text = "Enter VM name:"
	$form.Controls.Add($objLabel)
	### Text Box Answer for first question ###
	$edgeTextBox = New-Object System.Windows.Forms.TextBox
	$edgeTextBox.Location = New-Object System.Drawing.Size(150,10)
	$edgeTextBox.Size = New-Object System.Drawing.Size(320,5)
	$form.Controls.Add($edgeTextBox)
			
	$eventHandler = [System.EventHandler]{
	$textBox1.Text;
	$textBox2.Text;
	$textBox3.Text;
	$form.Close();};
			
	### Ask Second Question ###
	$objLabel2 = New-Object System.Windows.Forms.Label
	$objLabel2.Location = New-Object System.Drawing.Size(0,45)
	$objLabel2.Size = New-Object System.Drawing.Size(300,20)
	$objLabel2.Text = "Do you want to gather VMware.log(s)?:"
	$form.Controls.Add($objLabel2)	
			
	$objListBox = New-Object System.Windows.Forms.ListBox 
	$objListBox.Location = New-Object System.Drawing.Size(430,35) 
	$objListBox.Size = New-Object System.Drawing.Size(40,40) 

	$objListBox.SelectionMode = "One"		
	[void] $objListBox.Items.Add("Yes")
	[void] $objListBox.Items.Add("No")
	$LogsAnswer = $objListBox.SelectedItems 
			
	$Form.Controls.Add($objListBox)
			
	### Ask Third Question ###
	$objLabel3 = New-Object System.Windows.Forms.Label
	$objLabel3.Location = New-Object System.Drawing.Size(0,80)
	$objLabel3.Size = New-Object System.Drawing.Size(300,20)
	$objLabel3.Text = "Do you want to gather vSphere events?:"
	$form.Controls.Add($objLabel3)	
		
	$objListBox2 = New-Object System.Windows.Forms.ListBox 
	$objListBox2.Location = New-Object System.Drawing.Size(430,70) 
	$objListBox2.Size = New-Object System.Drawing.Size(40,40) 
		
	$objListBox2.SelectionMode = "One"		
	[void] $objListBox2.Items.Add("Yes")
	[void] $objListBox2.Items.Add("No")
	$EventsAnswer = $objListBox2.SelectedItems 
			
	$Form.Controls.Add($objListBox2)
				
	$result = $form.ShowDialog()
	### What to do with details entered ###
	$Cancelled = "False"
	if($result -eq [System.Windows.Forms.DialogResult]::OK){
		$Answers = [PSCustomObject]@{
			VM = $edgeTextBox.Text
			Logs = $LogsAnswer  | Select -first 1
			Events = $EventsAnswer | Select -first 1
			}	
	} 
	else {
		write-host "Cancelled..."
		$Cancelled = "True"
		Break
	}
# Check that the form is complete and print to console any areas which still need completing
	if (!$Answers.VM){
		"No VM name entered!"
	}
	if (!$Answers.Events){
		"Not all questions answered!"
	}
	if (!$Answers.Logs){
		"Not all questions answered!"
	}
}
until($Answers.VM -and $Answers.Logs -and $Answers.Events)

# If the user selects "Cancel", exit the script
if($Cancelled -like "True"){Break}

# Now that the user has initiated the script and filled out the form without cancelling, log that the script has been run.
$Logfile = "C:\Scripts\Technology\CSE\Triage Scripts\Triage Logging\TriageLog.log"
$Date = Get-Date
LogWrite -LogString "Script run at $Date" -file $logfile

# Connect to all customer facing vCenters and prompt user to enter their SINT API Key (will be simplified in future version)
Select-EApiSecurityDomain
Connect-CustomerVIServers

# Find the VM entered by the user

# First, search for an exact match (fastest)
$nameinput = $Answers.VM
$VMs = Get-VM -Name $nameinput -ErrorAction SilentlyContinue

# If there is no VM with that exact name, search for a wildcard match for the name entered
if (!$VMs){
	Write-Host "VM not found immediately, searching again..."
	$VMs = Get-VM | Where {$_.Name -match $nameinput}
}

# If there are still no VMs being returned, try to get just the GUID out of what the user entered and find the VM by that.
if (!$VMs)
{
	Write-Host "VM still not found, searching again..."
	$nameinput = $nameinput | Get-GUID
	if (!$nameinput){
		Write-Host "VM doesn't exist under that name!"
		Read-Host -Prompt "Press enter to exit"
		Disconnect-VIServer * -Confirm:$False
		Break
	}
	$VMs = Get-VM | Where {$_.Name -match $nameinput}
}
# If there are still no VMs found, inform the user and exit the script.
if (!$VMs){
	Write-Host "VM doesn't exist under that name!"
	Read-Host -Prompt "Press enter to exit"
	Disconnect-VIServer * -Confirm:$False
	Break
}

# If multiple VMs are returned, allow the user to select which VMs are the correct ones.
if ($VMs.count -gt 1)
{
	$VMs = Invoke-MultiSelectForm -Title "Pick one or more options:" -Message "Pick VM(s):" -Objects $VMs
	if(!$VMs){
		Disconnect-VIServer * -Confirm:$false
		Break
	}	
}

# Create an empty array to put multiple results in, then loop through each VM selected by the user
$Report = $null
$Report = @()
$progress = 0
foreach ($VM in $VMs)
{
	Write-Progress -ID 1 -Activity "Gathering information.." -PercentComplete ($progress/$VMs.Count*100)
	
	# Retrieve the vmware.log files for the VM if the user asked for them
	if ($Answers.Logs -like "Yes"){
		$VM | Get-VMLog -Path "C:\Scripts\Technology\CSE\Triage Scripts\VM vmware Logs"
	}
	
	# Retrieve the vsphere event logs for the VM if the user asked for them
	if ($Answers.Events -like "Yes"){
		$Events = Get-VIEvent -Entity $VM -MaxSamples 10000 | Sort CreatedTime -Descending | Select CreatedTime, FullFormattedMessage, @{N="Entity";E={$_.Entity.Name}}, @{N="Host";E={$_.Host.Name}}, UserName
		$Events | Export-Csv "C:\Scripts\Technology\CSE\Triage Scripts\VM Events\$VM.Name.csv" -NoTypeInformation
	}
	
	# Start populating variables with values for use in the final report
	$Lastboot = $VM.ExtensionData.Runtime.BootTime
	if (!$Lastboot)
	{
		$Lastboot = "Information could not be found"
	}
	$AccountInf = Get-EApiAccount -AccountDomainIdentifier ($VM.Folder.Parent.Parent -split "-" | select -index 1)
	$VMDK = Get-HardDisk -VM $VM
	$MemoryUsedPercent = get-stat -Entity $VM -Realtime -Stat "Mem.Usage.Average" -MaxSamples 1 -ErrorAction SilentlyContinue
	$CPUUsage = get-stat -Entity $VM -Realtime -Stat "cpu.usage.average" -MaxSamples 1 -errorAction SilentlyContinue
	$HostMemoryUsage = [Math]::Round($VM.VMHost.MemoryUsageGB*100/$VM.VMHost.MemoryTotalGB,2)	
	$HostCPUUsage = [Math]::Round($VM.VMHost.CpuUsageMhz*100/$VM.VMHost.CpuTotalMhz,2)
	$Snapshots = Get-Snapshot -VM $VM
	# Retrieve all network adapters which are attached to networks and find any Edge Gateways associated with the network(s)
	$VMNA = $VM | Get-NetworkAdapter | Where {$_.NetworkName -notlike "none"}
	if($VMNA){
		$EdgesNAs = Get-VM -Server $vm.Client.ConnectivityService.ServerAddress | Where {$_.Name -like "vse-*"} | Get-NetworkAdapter | Where {$_.NetworkName -like $VMNA.NetworkName}
		if ($EdgesNAs){ 
			$EdgeNames = $EdgesNAs.Parent -join ", "
			$Edgehost = $EdgesNAs.Parent.VMHost -join ", "
			$EdgeVMDKs = Get-HardDisk -VM $EdgesNAs.Parent
			$FinalEdgeVMDKs = $EdgeVMDKs.Filename -join ", "
		}
		Else{
			$EdgeNames = "Could not gather information"
			$Edgehost = "Could not gather information"
			$FinalEdgeVMDKs = "Could not gather information"
		}
	}
	Else{
		$EdgeNames = "Could not gather information"
		$Edgehost = "Could not gather information"
		$FinalEdgeVMDKs = "Could not gather information"
	}
	$CurrentEdgeNA = $EdgesNAs | Where {$_.NetworkName -Like $VMNA.NetworkName}
	if ($VM.Client.ConnectivityService.ServerAddress -match "il2management"){
		$Environment = "Assured"
	}
	elseif ($VM.Client.ConnectivityService.ServerAddress -match "il3management"){
		$Environment = "Elevated"
	}
	if (!$Snapshots) {
		$SnapshotNames = "No Snapshots Present"
		$SnapshotTotalSize = "N/A"
		$OldestSnapshot = "N/A"
		$NewestSnapshot = "N/A"
	}
	else{
		$SnapshotNames = $Snapshots.Name -join "`", `""
		$SnapshotTotalSize = (($Snapshots.SizeGB | Measure-Object -sum).sum)
		$OldestSnapshot = $Snapshots.Created | Sort | Select DateTime -First 1
		$OldestSnapshot = $OldestSnapshot.Datetime
		$NewestSnapshot = $Snapshots.Created | Sort -Descending | Select DateTime -First 1
		$NewestSnapshot = $NewestSnapshot.Datetime
	}
	# Populate first section of VM report with information about the customer, taken from the variables defined above
	$info = [PSCustomObject]@{
		"### Ticket Info ###" = ""
		"Environment" = $Environment
		"Impact/Extent" = ""
		"Problem Statement" = ""
		"Event Date/Time" = ""
		Company = $AccountInf.company.name
		Account = $AccountInf.name
		Bluelight = $AccountInf.company.blueLight
		Limited = $AccountInf.limited
		Organisation = $VM.Folder.Parent.Parent
		OrgVDC = $VM.Folder.Parent
		vCenter = $VM.Client.ConnectivityService.ServerAddress
		vApp = $VM.Folder
		"OrgVDC Link" = ""
	}
	# Append this first section onto the report and then append a blank line onto the report
	$Report += $info
	$info = ""
	$Report += $info
	
	# Create the second section of the VM report with information about the VM itself
	$info = [PSCustomObject]@{
		"### VM ###" = ""
		VM = $VM.Name
		"CPU Provisioning MHz" = $VM.ExtensionData.Runtime.MaxCpuUsage
		"CPU Usage %" = $CPUUsage
		"Memory MB" = $VM.MemoryMB
		"Memory Used %" = $MemoryUsedPercent
		Host = $VM.VMHost
		"Host Memory Usage %" = $HostMemoryUsage
		"Host CPU Usage %" = $HostCPUUsage
		Cluster = Get-Cluster -VMHost $VM.vmhost
		VMDK = $VMDK.Filename -join ", "
		"VM Last Boot" = $Lastboot
		"Snapshot Names" = $SnapshotNames
		"Snapshots Total Size" = $SnapshotTotalSize
		"Oldest Snapshot" = $OldestSnapshot
		"Newest Snapshot" = $NewestSnapshot
	}
	
	# Append this second section onto the report and then append a blank line onto the report
	$Report += $info
	$info = ""
	$Report += $info
	
	# Create third section of report which contains information about any edge gateways involved
	$info = [PSCustomObject]@{
		"### Edge ###" = ""
		Edge = $EdgeNames
		"Edge's Host" = $Edgehost
		"Edge VMDKs" = $FinalEdgeVMDKs
	}
	# Append this third section onto the report and then append a blank line onto the report
	$Report += $info
	$info = ""
	$Report += $info
	
	# Create the final section of the report which allows the user to fill in the rest of the triage template manually
	$info = [PSCustomObject]@{
		"### Actions Taken ###" = ""
		"### Other Useful URLs###" = ""
		"### Log Messages ###" = ""
		"### vSphere Events ###" = ""
	}
	
	# Apend final section of VM report to report and then loop through any more VMs
	$Report += $info
	$Progress += 1
}
Write-Progress -ID 1 -Activity "Gathering information.." -Completed

# Export the triage report to a .txt file so that it can be easily copy-pasted into triage notes
$Report | Out-File "C:\Scripts\Technology\CSE\Triage Scripts\VMReport.txt"


# Build a GUI form telling the user where to find the various output files, based on what they have selected
Add-Type -AssemblyName System.Windows.Forms

$form2 = New-Object Windows.Forms.Form
$form2.Size = New-Object Drawing.Size @(500,(120))
$form2.text = "Results"
$form2.StartPosition = "CenterScreen"
$form2.Add_Shown({$form.Activate()})
	
### Create Okay Button ###
$okbtn2 = New-Object System.Windows.Forms.Button
$okbtn2.Location =  New-Object Drawing.Size @(200,(70))
$okbtn2.Add_Click($eventHandler)
$okbtn2.DialogResult = [System.Windows.Forms.DialogResult]::OK
$okbtn2.Text = "OK"
$form2.Controls.Add($okbtn2)
			
$eventHandler = [System.EventHandler]{
$textBox1.Text;
$textBox2.Text;
$textBox3.Text;
$form.Close();};


$objLabel2 = New-Object System.Windows.Forms.Label
$objLabel2.Location = New-Object System.Drawing.Size(0,30)
$objLabel2.Size = New-Object System.Drawing.Size(470,20)
if ($Answers.Events -like "Yes"){
	if ($Events){
		$objLabel2.Text = "VM Events generated at C:\Scripts\Technology\CSE\Triage Scripts\VM Events\"
	}
	else{
		$objLabel2.Text = "VM has no vSphere events"
	}
}
else{
	$objLabel2.Text = "No VM Events Generated"
}
$form2.Controls.Add($objLabel2)


$objLabel1 = New-Object System.Windows.Forms.Label
$objLabel1.Location = New-Object System.Drawing.Size(0,10)
$objLabel1.Size = New-Object System.Drawing.Size(470,20)
if ($Answers.Logs -like "Yes"){
	$objLabel1.Text = "VMware.log files generated at C:\Scripts\Technology\CSE\Triage Scripts\VM vmware Logs\"
}
Else{
	$objLabel1.Text = "No VMware.log(s) generated"
}
$form2.Controls.Add($objLabel1)

$objLabel2 = New-Object System.Windows.Forms.Label
$objLabel2.Location = New-Object System.Drawing.Size(0,50)
$objLabel2.Size = New-Object System.Drawing.Size(470,20)
$objLabel2.Text = "VM report generated at C:\Scripts\Technology\CSE\Triage Scripts\VMReport.txt"
$form2.Controls.Add($objLabel2)

$result2 = $form2.ShowDialog()
### What to do with details entered ###
if($result2 -eq [System.Windows.Forms.DialogResult]::OK){
	Disconnect-VIServer * -Confirm:$false
	Break
} 
else {
	Disconnect-VIServer * -Confirm:$false
	Break
}
