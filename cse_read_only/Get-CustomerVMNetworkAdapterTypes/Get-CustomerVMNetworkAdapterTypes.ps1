Get-Module -ListAvailable | Where {$_.Name -like "VM*"} | Import-Module
clear

Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

# Ask user for to input their Organisation
$Org = Read-Host -Prompt "Please enter your organisation"

# Connect to vCloud through the specified Org
Connect-CIServer "api.vcd.portal.skyscapecloud.gsi.gov.uk" -Org $Org

# Ask the user to enter the OrgVDC name
$OrgVDCName = Read-Host -Prompt "Please enter an OrgVDC"

# If the user has entered an OrgVDC, limit results to just this OrgVDC
if ($OrgVDCName){
	# Retrieve OrgVDC from the specified OrgVDC name
	$OrgVDC = Get-OrgVdc -Name $OrgVDCName*
	
	# Retrieve all vApps from the VDC and ask the user to pick from the list - then retrieve the VMs from the specified vApp(s)
	$vApp = Get-CIVapp -OrgVdc $OrgVDC | Out-GridView -Title "Please select a vApp" -PassThru
	
	# If the user does not select a vApp, just retrieve all VMs from the OrgVDC, then ask the user to pick the VM(s)
	if ($vApp)	{
		$VMs = Get-CIVM -VApp $vApp | Out-GridView -Title "Please select a VM(s)" -PassThru
	}else{
		$VMs = Get-CIVM -OrgVdc $OrgVDC | Out-GridView -Title "Please select a VM(s)" -PassThru
	}
	
# If the user does not input an OrgVDC, retrieve all the VMs in the OrgVDC, then ask the user to pick the VM(s)
}Else{
	$VMs = Get-CIVM 
	$VMs = $VMs | Out-GridView -Title "Please select a VM" -Passthru
}
$Report = $null
$Report = @()

# Loop through the selected VMs and get the network adapters for them, build report with results
$Progress = 0
foreach ($VM in $VMs){	
	Write-Progress -Activity "Gathering Network Adapters" -Id 1 -PercentComplete ($Progress/$VMs.Count*100)
	$VMNA = Get-CINetworkAdapter -VM $VM
	$info = "" | Select "VM", "OS", "Number of Adapters", "Adapter Types"
	$info.VM = $VM.Name
	$info.OS = $VM.GuestOsFullName
	$info."Number of Adapters" = $VMNA.Count
	$info."Adapter Types" = $VMNA.ExtensionData.NetworkAdapterType -join ', '
	$Progress += 1
	$Report += $info
}
Write-Progress -Activity "Gathering Network Adapters" -Id 1 -Completed

# Disconnect from vCloud and display results on-screen via Gridview
Disconnect-CIServer * -Confirm:$False
$FinalCount = $Report.Count
$Report | Out-Gridview -Title "$FinalCount VMs" -PassThru
