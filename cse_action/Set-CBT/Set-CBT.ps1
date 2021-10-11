Get-Module -ListAvailable | Where {$_.Name -like "VM*"} | Import-Module
Clear

################################################################################################################

#This function brings up a GUI interface for multiple or single selection of objects
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

######################################################################################################################

### This function will connect to all vCenters currently listed in IAS (just customer facing vCenters) ###
Function Connect-CustomerVIServers
{
	[CmdletBinding()]
	Param
	(
		$Credential
	)
	Process
	{
		if (!$Credential){
			$Credential = Get-Credential -Message "Please provide credentials to log in to the vCenters:"
		}

		if($env:USERDOMAIN -match "IL2"){ 
		    $url = 'http://10.8.81.45/providers'
		}
		elseif($env:USERDOMAIN -match "IL3"){
			$url = 'http://10.72.81.42/providers'
		}
		else{
			$urls = @("http://10.8.81.45/providers", "http://10.72.81.42/providers")
			$url = $urls | Out-GridView -Title "Choose which Impact Level IAS to connect to:" -Passthru
		}
		$Data = (Invoke-WebRequest -Uri $url).Content
		$enc = [System.Text.Encoding]::ASCII
		$Json = $enc.GetString($Data) | ConvertFrom-Json

		$VCList = @()
		ForEach($Item in ($Json.Data | Select -expandproperty attributes)){

		                $VCList += $Item
		}
		foreach ($vCenterServer in $VCList){
		Connect-VIServer $vCenterServer.providerMetadata[1].MetadataValue -Credential $Credential
		}
	}
}

######################################################################################################################

# Get list of VM names from text file and put this in a variable
$Filepath = Read-Host -Prompt "Enter filepath - Example `"C:\path\to\your\textFile\vms.txt`""
$vms = import-csv $Filepath

# check that the VMs variable has been populated
if (!$vms){
Write-Host "No File Specified or file does not exist"
Read-Host "Press enter to exit"
exit
}
# Prompt for credentials and connect to all customer facing vCenters
$Cred = Get-Credential
Connect-CustomerVIServers -Credential $Cred

# Ask the user if they want to disable or enable CBT on the selected VMs
$Choices = @("Enable","Disable")
$Choice = Multi-Select -title "Choice selection:" -message "Do you want to Enable or Disable CBT on the selected VMs?" -objects $Choices

# Open a blank array ready to record the results in
$Report = @()
$Progress = 1
if ($Choice -match "Disable"){
	foreach($vm in $vms){
		Write-Progress -Activity "Disabling CBT on VMs" -PercentComplete ($Progress/$vms.Count*100)
		
# Check for square brackets in the VM name and account for it
		if (($vm -match "\[") -or ($vm -match "]")){
			$vm2 = $vm.vm -split " " | select -Last 1
			$tempVM = Get-VM | Where {$_.Name -match $vm2}
			$vm =  $tempVM | get-view
		}
		else{
	    $vm = Get-vm $vm.VM| get-view
		}
		
# Build a new config spec object to push on the VM, containing the desired CBT state
	    $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec 
	    $vmConfigSpec.changeTrackingEnabled = $false
	    $vm.reconfigVM($vmConfigSpec)
		
# Attempt to snapshot the VM - if the VM has special characters in the name, account for it
	    try {$snap=New-Snapshot $vm.Name -Name "Disable CBT"}
		catch{
			Write-Host "Trying snapshot again"
			$snap = New-Snapshot -VM $TempVM -Name "Disable CBT"
		}
		
# Remove the snapshot, allowing the CBT changes to take hold
	    $snap | Remove-Snapshot -confirm:$false
		
# Retrieve the VM object again and report the new CBT status
		If ($tempVM){	
			$finalVM = Get-VM | Where {$_.Name -match $vm2}
			$final = $finalVM.ExtensionData.Config.ChangeTrackingEnabled
			$Result = "Enable CTK on $($vm.Name) is set to $final"
		}
		else{	
			$Result = "Enable CTK on $($vm.Name) is set to $((Get-VM -Name $vm.Name).ExtensionData.Config.ChangeTrackingEnabled)"
		}
		Write-Host $Result
		$Progress ++
		$Report += $Result
   	} 
}	
elseif ($Choice -match "Enable"){
	foreach($vm in $vms){	
		Write-Progress -Activity "Enabling CBT on VMs" -PercentComplete ($Progress/$vms.Count*100)
		
# Check for square brackets in the VM name and account for it
		if (($vm -match "\[") -or ($vm -match "]")){
			$vm2 = $vm.vm -split " " | select -Last 1
			$tempVM = Get-VM | Where {$_.Name -match $vm2}
			$vm =  $tempVM | get-view
		}
		else{
	    	$vm = Get-vm $vm.VM| get-view
		}
		
# Build a new config spec object to push on the VM, containing the desired CBT state

		$vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
		$vmConfigSpec.changeTrackingEnabled = $true
	    $vm.reconfigVM($vmConfigSpec)

# Attempt to snapshot the VM - if the VM has special characters in the name, account for it
	   	try {$snap = New-Snapshot $vm.Name -Name "Enable CBT"}
		catch{
			Write-Host "Trying snapshot again"
			$snap = New-Snapshot -VM $TempVM -Name "Enable CBT"
		}

# Remove the snapshot, allowing the CBT changes to take hold
	    $snap | Remove-Snapshot -confirm:$false

# Retrieve the VM object again and report the new CBT status
		If ($tempVM){	
			$finalVM = Get-VM | Where {$_.Name -match $vm2}
			$final = $finalVM.ExtensionData.Config.ChangeTrackingEnabled
			$Result = "Enable CTK on $($vm.Name) is set to $final"
		}
		else{	
			$Result = "Enable CTK on $($vm.Name) is set to $((Get-VM -Name $vm.Name).ExtensionData.Config.ChangeTrackingEnabled)"
		}		
		Write-Host $Result
		$Progress ++
		$Report += $Result
		}
	}
	
# Tell the user that they have failed to select either Enable or Disable and then exit
Else {
	Write-Host "No option selected!"
	Read-Host "Press Enter to exit"
	Exit
}

# Disconnect from all vCenters
Disconnect-VIServer * -Confirm:$False

# Display results to the screen
$Report | Out-GridView -Title "Results" -Passthru