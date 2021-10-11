Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))

{   
$arguments = "& '" + $myinvocation.mycommand.definition + "'"
Start-Process powershell -Verb runAs -ArgumentList $arguments
Break
}
Get-Module -ListAvailable | Where {$_.Name -like "VM*"} | Import-Module
Clear

Function LogWrite
{
   Param (
   [string]$logstring,
   [Parameter(Mandatory=$True)]$file
   )

   Add-content $file -value $logstring
}

######################################################################################################
function Get-VMLog{
<#
.SYNOPSIS
	Retrieve the virtual machine logs
.DESCRIPTION
	The function retrieves the logs from one or more
	virtual machines and stores them in a local folder
.NOTES
	Author:  Luc Dekens
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

######################################################################################################
Function Connect-CustomerVIServers
{
	[CmdletBinding()]
	Param
	(
		$Credential
	)
	Process
	{
		if (!$Credential)
		{
			$Credential = Get-Credential -Message "Please provide credentials to log in to the vCenters:"
		}

		if($env:COMPUTERNAME -like "*I2*")
		{ 
		    $url = 'http://10.8.81.45/providers'
		}
		elseif($env:COMPUTERNAME -like "*I3*")
		{
			$url = 'http://10.72.81.42/providers'
		}
		else
		{
			$urls = @("http://10.8.81.45/providers", "http://10.72.81.42/providers")
			$url = $urls | Out-GridView -Title "Choose which Impact Level IAS to connect to:" -Passthru
		}
		$Data = (Invoke-WebRequest -Uri $url).Content
		$enc = [System.Text.Encoding]::ASCII
		$Json = $enc.GetString($Data) | ConvertFrom-Json

		$VCList = @()
		ForEach($Item in ($Json.Data | Select -expandproperty attributes))
		{

		                $VCList += $Item
		}
		foreach ($vCenterServer in $VCList){
		Connect-VIServer $vCenterServer.providerMetadata[1].MetadataValue -Credential $Credential
		}
	}
}
###############################################################################################################


function Multi-Select
{
	Param 
	(
		[Parameter(Mandatory=$true)]$objects,
		[Parameter(Mandatory=$true)]$title,
		[Parameter(Mandatory=$true)]$message
	)
	Process
	{
	[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
	[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")

	$objForm = New-Object System.Windows.Forms.Form 
	$objForm.Text = $title
	$objForm.Size = New-Object System.Drawing.Size(600,300) 
	$objForm.StartPosition = "CenterScreen"

	$objForm.KeyPreview = $True
	
	$objForm.Add_KeyDown({if ($_.KeyCode -eq "Enter") 
    {$x=$objListBox.SelectedItem;$objForm.Close()}})
	$objForm.Add_KeyDown({if ($_.KeyCode -eq "Escape") 
    {$objForm.Close()}})
	
	$OKButton = New-Object System.Windows.Forms.Button
	$OKButton.Location = New-Object System.Drawing.Size(425,240)
	$OKButton.Size = New-Object System.Drawing.Size(75,23)
	$OKButton.Text = "OK"
	$OKButton.Add_Click({$x=$objListBox.SelectedItem;$objForm.Close()})
	$objForm.Controls.Add($OKButton)
	
	$CancelButton = New-Object System.Windows.Forms.Button
	$CancelButton.Location = New-Object System.Drawing.Size(500,240)
	$CancelButton.Size = New-Object System.Drawing.Size(75,23)
	$CancelButton.Text = "Cancel"
	$CancelButton.Add_Click({$objForm.Close()})
	$objForm.Controls.Add($CancelButton)

	$objLabel = New-Object System.Windows.Forms.Label
	$objLabel.Location = New-Object System.Drawing.Size(10,20) 
	$objLabel.Size = New-Object System.Drawing.Size(280,20) 
	$objLabel.Text = $message
	$objForm.Controls.Add($objLabel)
	
	$objListBox = New-Object System.Windows.Forms.ListBox 
	$objListBox.Location = New-Object System.Drawing.Size(10,40) 
	$objListBox.Size = New-Object System.Drawing.Size(560,350) 
	$objListBox.Height = 190

	$objListBox.SelectionMode = "MultiExtended"
	$Items = $objects
	foreach ($Item in $Items){
	[void] $objListBox.Items.Add($item)
	}

	$output = $objListBox.SelectedItems 
	
	$objForm.Controls.Add($objListBox)
	$objForm.Topmost = $True

	$objForm.Add_Shown({$objForm.Activate()})
	[void] $objForm.ShowDialog()
	
	$output
	}
}


###############################################################################################################


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


###############################################################################################################

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
	$objLabel.Text = "Enter Edge name:"
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

	if (!$Answers.VM){
		"No Edge name entered!"
	}
	if (!$Answers.Events){
		"Not all questions answered!"
	}
	if (!$Answers.Logs){
		"Not all questions answered!"
	}
}
until($Answers.VM -and $Answers.Logs -and $Answers.Events)

if($Cancelled -like "True"){Break}

$Logfile = "C:\Scripts\Technology\CSE\Triage Scripts\Triage Logging\TriageLog.log"
$Date = Get-Date



Connect-CustomerVIServers

$nameinput = $Answers.VM
$VSEs = Get-VM -Name $nameinput -ErrorAction SilentlyContinue
if (!$VSEs){
	Write-Host "VSE not found immediately, searching again..."
	$VSEs = Get-VM | Where {$_.Name -Match $nameinput}
}
if (!$VSEs)
{
	Write-Host "VSE still not found, searching again..."
	$nameinput = $nameinput | Get-GUID
	$VSEs = Get-VM | Where {$_.Name -match $nameinput}
}
if (!$VSEs){
	Write-Host "VSE doesn't exist under that name!"
	Disconnect-VIServer * -Confirm:$False
	Break
}
LogWrite -LogString "Script run at $Date" -file $logfile
if ($VSEs.count -gt 1)
{
	$VSEs = Multi-Select -Title "Pick one or more options:" -Message "Pick VSE(s):" -Objects $VSEs
	if(!$VSEs){
		Disconnect-VIServer * -Confirm:$false
		Break
	}
}
$VMs = Get-VM -Server $VSEs.Client.ConnectivityService.ServerAddress | where {$_.Name -notlike "vse-*"}
$NAs = Get-NetworkAdapter -VM $VMs | Where {$_.NetworkName -NotLike "none"}

$Report = $null
$Report = @()
$progress = 0

foreach ($VSE in $VSEs)
{
	Write-Progress -ID 1 -Activity "Gathering information.." -PercentComplete ($progress/$VSEs.Count*100)
	$VSENAs = $VSE | Get-NetworkAdapter
	$InitialList = $NAs | where {$_.NetworkName -in $VSENAs.NetworkName} | Select -unique
	if (!$InitialList)
	{
		if ($VSEs.Count -like "1")
		{
			if ($Answers.Logs -like "Yes"){
				Write-Host "$VSE does not share a network with any VMs, therefore not all information can be found"
				Read-Host -Prompt "Press enter to continue"
				Continue
			}
			elseif ($Answers.Events -like "Yes"){
				Write-Host "$VSE does not share a network with any VMs, therefore not all information can be found"
				Read-Host -Prompt "Press enter to continue"
				Continue
			}
			else{
				Read-Host -Prompt "No information found, press enter to exit"
				Disconnect-VIServer * -Confirm:$false
				Exit
			}
		}
		else
		{
			Write-Host "$VSE does not share a network with any VMs, therefore not all information can be found"
			Read-Host -Prompt "Press enter to continue"
			Continue
		}
	}
	if ($Answers.Logs -like "Yes")
	{
		$VSE | Get-VMLog -Path "C:\Scripts\Technology\CSE\Triage Scripts\VSE vmware Logs"
	}
	if ($Answers.Events -like "Yes")
	{
		$Events = Get-VIEvent -Entity $VSE -MaxSamples 10000 | Sort CreatedTime -Descending | Select CreatedTime, FullFormattedMessage, @{N="Entity";E={$_.Entity.Name}}, @{N="Host";E={$_.Host.Name}}, UserName
		$Events | Export-Csv "C:\Scripts\Technology\CSE\Triage Scripts\VSE Events\$VSE.Name.csv" -NoTypeInformation
	}
	$SecondaryList = $InitialList.Parent.Folder.Parent | Select -unique
	$Organisation = $InitialList.Parent.Folder.Parent.Parent | select -unique
	$Lastboot = $VSE.ExtensionData.Runtime.BootTime
	if (!$Lastboot)
	{
		$Lastboot = "Information could not be found"
	}
	$VSEVMDK = Get-HardDisk -VM $VSE
	$MemoryUsed = get-stat -Entity $VSE -Realtime -Stat "Mem.Consumed.Average" -MaxSamples 1 -ErrorAction SilentlyContinue
	$MemoryUsedPercent = [Math]::Round((($memoryused.Value/1000/1000)/($VSE.MemoryGB)*100),2)
	$CPUUsage = get-stat -Entity $VSE -Realtime -Stat "cpu.usage.average" -MaxSamples 1 -errorAction SilentlyContinue
	$HostMemoryUsage = [Math]::Round($VSE.VMHost.MemoryUsageGB*100/$VSE.VMHost.MemoryTotalGB,2)	
	$HostCPUUsage = [Math]::Round($VSE.VMHost.CpuUsageMhz*100/$VSE.VMHost.CpuTotalMhz,2)
	$Snapshots = Get-Snapshot -VM $VSE
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
	Foreach ($item in $SecondaryList)
	{
		$info = [PSCustomObject]@{
		vCenter = $VSE.Client.ConnectivityService.ServerAddress;
		Edge = $VSE.Name;
		Host = $VSE.VMHost;
		VMDK = $VSEVMDK.Filename -join ", ";
		OrgVDC = $item;
		Organisation = $Organisation
		"Last Boot" = $Lastboot
		"Snapshot Names" = $SnapshotNames
		"Snapshots Total Size" = $SnapshotTotalSize
		"Oldest Snapshot" = $OldestSnapshot
		"Newest Snapshot" = $NewestSnapshot		
		"Memory MB" = $VSE.MemoryMB
		"Memory Used %" = $MemoryUsedPercent
		"CPU Provisioning MHz" = $VSE.ExtensionData.Runtime.MaxCpuUsage
		"CPU Usage %" = $CPUUsage
		"Host Memory Usage %" = $HostMemoryUsage
		"Host CPU Usage %" = $HostCPUUsage
		}
		$Report += $info
	}
	$Progress += 1
}
Write-Progress -ID 1 -Activity "Gathering information.." -Completed
if ($Report){
$Report | Export-Csv "C:\Scripts\Technology\CSE\Triage Scripts\vShield Edge Report.csv" -NoTypeInformation
}

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
if ($Events){
	$objLabel2.Text = "VSE Events generated at C:\Scripts\Technology\CSE\Triage Scripts\VSE Events\"
}
else{
	$objLabel2.Text = "No VSE Events generated"
}

$form2.Controls.Add($objLabel2)

$objLabel1 = New-Object System.Windows.Forms.Label
$objLabel1.Location = New-Object System.Drawing.Size(0,10)
$objLabel1.Size = New-Object System.Drawing.Size(470,20)
if ($Answers.Logs -like "Yes"){
	$objLabel1.Text = "VMware.log files generated at C:\Scripts\Technology\CSE\Triage Scripts\VSE vmware Logs\"
}
Else{
	$objLabel1.Text = "No VMware.log files generated"
}
$form2.Controls.Add($objLabel1)

$objLabel2 = New-Object System.Windows.Forms.Label
$objLabel2.Location = New-Object System.Drawing.Size(0,50)
$objLabel2.Size = New-Object System.Drawing.Size(470,20)
if ($Report){
	$objLabel2.Text = "VSE report generated at C:\Scripts\Technology\CSE\Triage Scripts\vShield Edge Report.csv"
}
else{
	$objLabel2.Text = "No VSE information could be found"
}
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
