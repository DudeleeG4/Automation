# Import PowerCLI modules and clear the console
Get-Module -ListAvailable | Where {$_.Name -like "VM*"} | Import-Module
Clear

Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

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


#This allows you to connect to the IAS and pull down the list of vCloud api names that are currently in use

Function Connect-IAS 
{
	if($env:COMPUTERNAME -like "*I2*")
	{ 
    	$url = 'http://10.8.81.45/vendors'
	}
	elseif($env:COMPUTERNAME -like "*I3*")
	{
		$url = 'http://10.72.81.42/vendors'
	}
	else
	{
		$urls = @("http://10.8.81.45/vendors", "http://10.72.81.42/vendors")
		$url = $urls | Out-GridView -Title "Choose which Impact Level IAS to connect to:" -Passthru
	}
	
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $webRequest = [System.Net.WebRequest]::Create($url)
    $webRequest.ContentType = "application/vnd.api+json"
    $webRequest.ServicePoint.Expect100Continue = $false
    $webRequest.Method = "Get"
    [System.Net.WebResponse]$resp = $webRequest.GetResponse()
    $rs = $resp.GetResponseStream()
    [System.IO.StreamReader]$sr = New-Object System.IO.StreamReader -argumentList $rs
    [string]$results = $sr.ReadToEnd()
    return $results
}


################################################################################################################

# Use function to pull down a list of all vCloud instances
$VcloudsUrls = Connect-IAS | ConvertFrom-JSON

# Prompt user for credentials
$Cred = Get-Credential

# Ask the user to select which vCloud instance(s) they want to connect to.
$vCloud = Multi-Select -Title "Pick one or more options:" -Message "Pick vCloud Instance:" -Objects $vCloudsUrls.data.attributes.apiUrl
if (!$vCloud){Break}

# Ask the user if they want to retrieve the Org of the vApp also
$OrgChoice = Multi-Select -Title "Pick one option:" -Message "Would you like to retrieve the Org too?(Slower):" -Objects "Yes","No"
if (!$OrgChoice){Break}

# Connect to the selected vCloud instances
Connect-CIServer $vCloud -Credential $Cred

# Begin a loop so that the user can enter multiple vApp networks if they wish
Do{

# Prompt the user to enter the vApp network
$vAppNetwork = Read-Host "Enter vApp Network:"

# Retrieve the vApp edge
$vAppEdge = Search-Cloud -QueryType AdminVAppNetwork -Name $vAppNetwork

# If the user did not ask for the org, return just the vApp and vApp network
If ($OrgChoice -like "No")
{
	$vAppEdge | Select Name, vAppName
}

# If the user did ask for the org, return the vApp, vApp network and Org
elseif ($OrgChoice -like "Yes")
{
	$vAppEdge |% {[PSCustomObject]@{Name = $_.Name; vAppName = $_.vAppName; Org = Get-Org -Id $vAppEdge.Org}}
}

# Ask the user if they want to continue with another vApp network/vApp search
$Choice = Multi-Select -title "Pick an option:" -message "Would you like to continue looking for more?" -objects "Continue", "Exit"
if (!$Choice){Break}
}
While
($Choice -like "Continue")
Read-Host -Prompt "Press Enter to Exit"

# Disconnect from all vCloud instances
Disconnect-CIServer $vCloud -Confirm:$false
