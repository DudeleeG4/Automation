<#
This is a list of my custom made functions for use with powercli
#>
Get-Module -ListAvailable | Where {$_.name -like "VM*"} | Import-Module

################################################################################################################
# This function pulls down the PVDC XML files from the vCloud API
Function Get-PVDCs { 
if (-not $global:DefaultCIServers) {Connect-CIServer}
$Uri = $global:DefaultCIServers.ServiceUri.AbsoluteUri + "admin/extension/providerVdcReferences/query"
$head = @{"x-vcloud-authorization"=$global:DefaultCIServers.SessionSecret} + @{"Accept"="application/*+xml;version=5.6;vr-version=3.0"}
$r = Invoke-WebRequest -URI $Uri -Method Get -Headers $head -ErrorAction:Stop
[xml]$sxml = $r.Content
$PVDCs = $sxml.QueryResultRecords.VMWProviderVdcRecord

$PVDCs
}

################################################################################################################

<#This function accepts vm view objects and gets their vOrgs. It accepts the objects from the pipeline aswell as a specified 
variable. It will also accept an array of objects. #>
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

################################################################################################################

#This function accepts a string or array of strings containing two brackets () with text between the two, and returns just that text
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

################################################################################################################

#This just returns an object containing information about the vCloud cells for all vCloud instances currently connected to

#There are no parameters for this function
Function Get-VRCells {
<#
.SYNOPSIS
Discovers all vCloud Director cells
.DESCRIPTION
Discovers all vCloud Director cells including Cloud Proxies and report their status and version and if they ran VC proxy .EXAMPLE PS C:\> Get-VRCells
.NOTES
Author: Tomas Fojta
#>
 
if (-not $global:DefaultCIServers) {Connect-CIServer}
 
$Uri = $global:DefaultCIServers.ServiceUri.AbsoluteUri + "query?type=cell"
$head = @{"x-vcloud-authorization"=$global:DefaultCIServers.SessionSecret} + @{"Accept"="application/*+xml;version=5.6;vr-version=3.0"}
$r = Invoke-WebRequest -URI $Uri -Method Get -Headers $head -ErrorAction:Stop
[xml]$sxml = $r.Content
$VRCells = $sxml.QueryResultRecords.CellRecord
 
 
$VRCells
}

################################################################################################################

Function Get-EdgeGateways {
	Param (
	$filter
	)
	if (-not $global:DefaultCIServers) {Connect-CIServer}

	foreach ($Server in $global:DefaultCIServers)
	{
		$pagenumber = 1
		Do 
		{
			if($filter){$Uri = $Server.ServiceUri.AbsoluteUri + "query?type=edgeGateway&pageSize=128&page=" + $pagenumber + "&filter=" + "$filter"}
			else {$Uri = $Server.ServiceUri.AbsoluteUri + "query?type=edgeGateway&pageSize=128&page=" + $pagenumber}
			$head = @{"x-vcloud-authorization"=$Server.SessionSecret} + @{"Accept"="application/*+xml;version=5.6;vr-version=3.0"}
			$r = Invoke-WebRequest -URI $Uri -Method Get -Headers $head -ErrorAction:Stop
			[xml]$sxml = $r.Content
			$EdgeGateways = $sxml.QueryResultRecords.EdgeGatewayRecord
			$pagenumber += 1
			if ($EdgeGateways){$EdgeGateways}
		}
		while ($EdgeGateways.count -like "128")
	}
}

################################################################################################################

# This allows you to connect to all Customer facing vCloud instances currently in use

Function Connect-CustomerCIServers{
	Param(
	$Credential
	)
	Begin{
		if($env:USERDOMAIN -match "IL2"){ 
	    	$url = 'http://10.8.81.45/vendors'
		}
		elseif($env:USERDOMAIN -match "IL3")	{
			$url = 'http://10.72.81.42/vendors'
		}else{
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
	    $vCloudURLs = $Results | ConvertFrom-Json |% {$_.Data.Attributes.APIUrl}
	}
	Process{
		if ($Credential){
			Connect-CIServer $vCloudURLs -Credential $Credential
		}else{
			$Credential = Get-Credential
			Connect-CIServer $vCloudURLs -Credential $Credential
		}
	}
}

################################################################################################################
# This function will simply pull down the vCloud PowerCLI API endpoints and return them to the pipeline

Function Get-CustomerCIServers{
	Process{
		if($env:USERDOMAIN -match "IL2"){ 
		   	$url = 'http://10.8.81.45/vendors'
		}
		elseif($env:USERDOMAIN -match "IL3")	{
			$url = 'http://10.72.81.42/vendors'
		}else{
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
		$Results | ConvertFrom-Json |% {$_.Data.Attributes.APIUrl}
	}
}

################################################################################################################

### This function will connect to all vCenters currently listed in IAS (just customer facing vCenters) ###

Function Connect-CustomerVIServers{
	Param(
		$Credential
	)
	Process{
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

################################################################################################################

Function Get-CustomerVIServers{
	Process
	{
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
			$vCenterServer.providerMetadata[1].MetadataValue
		}
	}
}

################################################################################################################

#These 2 functions allow you to contact the SINT API to request a specific username and password for a device. 
Function Connect-SINTAPI {
Param($url, $SintAPIKey)

	$auth_key= $SintAPIKey
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $webRequest = [System.Net.WebRequest]::Create($url)
    $webRequest.ServicePoint.Expect100Continue = $false
    $webRequest.Method = "Get"
    $webRequest.Headers.Add("Authorization",$auth_key)
    $webRequest.Accept = "application/json"
    [System.Net.WebResponse]$resp = $webRequest.GetResponse()
    $rs = $resp.GetResponseStream()
    [System.IO.StreamReader]$sr = New-Object System.IO.StreamReader -argumentList $rs
    $results = $sr.ReadToEnd() | ConvertFrom-Json
    return $results 
}

Function Get-SintCreds {	
	Param($CI, $Username, $Answer)

	If($env:USERDOMAIN -match "IL2"){ 
		$url_il = "https://sint.il2management.local"
	}
	ElseIf($env:USERDOMAIN -match "IL3"){
		$url_il = "https://sint.il3management.local"
	}
	ElseIf($Answer -match "Assured"){
		$url_il = "https://sint.il2management.local"
	}
	ElseIf(($Answer -match "Elevated") -or ($Answer -match "Combined")){
		$url_il = "https://sint.il3management.local"
	}
	else{
		$urls_il = @("https://sint.il2management.local", "https://sint.il3management.local")
		$url_il = $urls_il | Out-GridView -Title "Choose which Impact Level SINT to connect to:" -Passthru
	}
    $hostname = $CI
    $passlabel = $Username
    $url = "$url_il/api/cmdb/search?hostname=$hostname"
    $pwd = Connect-SINTAPI -url $url -SintAPIKey $SintAPIKey
    $url ="$url_il/api/ci/ci/"+$pwd.data.id+"/credentials"
    $pwds = Connect-SINTAPI -Url $url -SintAPIKey $SintAPIKey
    foreach($pwd in $pwds){
        $id = $pwd.label

        if ($id -match $passlabel)
        {
            $usr   = $pwd.username 
            $pwdId = $pwd.id 
        }  
    }
    $url = "$url_il/api/pwdb/credentials/$pwdId/password"
    $pwd = Connect-SINTAPI -url $url -SintAPIKey $SintAPIKey
    return $usr,$pwd
}

################################################################################################################

#This function allows you to push alerts out in sciencelogic against devices specified
function Invoke-SLAPI($text)
{
    if($env:COMPUTERNAME -like "*I2*"){
     
    	$url = "https://sciencelogic.il2management.local/api/alert"
        $user = "em7admin"
        $pass=  "Ia4a6s1p2a2q7"
	}else{

		$url = "https://sciencelogic.il3management.local/api/alert"
        $user = "em7admin"
        $pass=  "Ng4z1x9t4z2g5"
	}

    $json = "{""force_ytype"":""0"",
            ""force_yid"":""0"",""force_yname"":""1"",
            ""message"": ""$text"",""value"":"""",""threshold"":""0"",
            ""message_time"":""0"",
            ""aligned_resource"":""/device/887""}"
    $json         
    $secpasswd = ConvertTo-SecureString -String $pass -AsPlainText -Force
    $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, $secpasswd
    #[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true} (This one liner will ignore SSL certificate error)
    $r = Invoke-RestMethod -Uri $url -Method Post -Credential $cred -Body $json -ContentType 'application/json'  
}

################################################################################################################

#This function brings up a multiple selection for objects, non-gui
function Initialize-ChoicePrompt
{
	Param (
	[Parameter(Mandatory=$true)]$Title,
	[Parameter(Mandatory=$true)]$Message,
	[Parameter(Mandatory=$true)]$Options
	)
	process
	{	
	$defaultchoice = 0
	$host.UI.PromptForChoice($Title , $Message , $Options, $defaultchoice)
	}
}

################################################################################################################

#This function brings up a GUI interface for multiple or single selection of objects
function Invoke-MultiSelectForm
{
	Param 
	(
		[Parameter(Mandatory=$true,ValueFromPipeline=$true)]$Objects,
		$Title,
		$Message
	)
	Begin{
		If (!$Title){
			$Title = "Item Selection"
		}
		If (!$Message){
			$Message = "Please select an item:"
		}
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
	}
	Process{
		foreach ($Object in $Objects){
		[void] $objListBox.Items.Add($Object)
		}
	}
	End{
		$output = $objListBox.SelectedItems 

		$objForm.Controls.Add($objListBox)
		$objForm.Topmost = $True

		$objForm.Add_Shown({$objForm.Activate()})
		[void] $objForm.ShowDialog()
		
		$output
	}
}

################################################################################################################

### This will take any string(s) containing vCenter names in PV1 and return their availability Zone(s)
Function Get-AvailabilityZones
{
    Param
    (
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    $vCenter
    )
	Process{
	    switch -wildcard ($vcenter)
	    {
			"*vcw00002i2*"
	        {
	        	[PSCustomObject]@{
					Name = "vcw00002i2"
					Site = "Farnborough"
					Region = "1"
					Zone = "1(AF1)"
				}
	        }
			"*vcw00003i2*"
	        {
	        	[PSCustomObject]@{
					Name = "vcw00003i2"
					Site = "Farnborough & Corsham"
					Region = "1 & 2"
					Zone = "1,2(AE1)"
				}
	        }
	        "*vcw00005i2*"
	        {
				[PSCustomObject]@{
					Name = "vcw00005i2"
					Site = "Corsham"
					Region = "2"
					Zone = "2(AC1)"
				}
	        }
			"*vcw00007i2*"
	        {
				[PSCustomObject]@{
					Name = "vcw00007i2"
					Site = "Farnborough"
					Region = "1"
					Zone = "1(AF2)"
				}
	        }
			"*vcw00008i2*"
	        {
				[PSCustomObject]@{
					Name = "vcw00008i2"
					Site = "Farnborough"
					Region = "1"
					Zone = "1(AF3)"
				}
	        }
			"*vcw00009i2*"
	        {
				[PSCustomObject]@{
					Name = "vcw00009i2"
					Site = "Corsham"
					Region = "2"
					Zone = "2(AC2)"
				}
	        }
	        "*vcw0000ai2*"
	        {
				[PSCustomObject]@{
					Name = "vcw0000ai2"
					Site = "Corsham"
					Region = "2"
					Zone = "2(AC3)"
				}
	        }
			"*vcv00004i2*"
			{
				[PSCustomObject]@{
					Name = "vcv00004i2"
					Site = "Farnborough"
					Region = "1"
					Zone = "1(AF4)"
				}
			}
			"*vcv00005i2*"
			{
				[PSCustomObject]@{
					Name = "vcv00005i2"
					Site = "Corsham"
					Region = "2"
					Zone = "2(AC4)"
				}
			}
			"*vcv00007i2*"
			{
				[PSCustomObject]@{
					Name = "vcv00007i2"
					Site = "Corsham"
					Region = "4"
					Zone = "3"
				}
			}
			"*vcv0000ci2*"
			{
				[PSCustomObject]@{
					Name = "vcv0000ci2"
					Site = "Corsham"
					Region = "5"
					Zone = "B"
				}
			}
			"*vcv0000ei2*"
			{
				[PSCustomObject]@{
					Name = "vcv0000ei2"
					Site = "Farnborough"
					Region = "6"
					Zone = "F"
				}		
			}
			"*vcw00002i3*"
	        {
				[PSCustomObject]@{
					Name = "vcw00002i3"
					Site = "Farnborough"
					Region = "7"
					Zone = "10(EF1)"
				}
	        }
			"*vcw00003i3*"
	        {
				[PSCustomObject]@{
					Name = "vcw00003i3"
					Site = "Farnborough & Corsham"
					Region = "7 & 8"
					Zone = "10,11(EE1)"
				}
	        }
			"*vcw00005i3*"
	        {
				[PSCustomObject]@{
					Name = "vcw00005i3"
					Site = "Corsham"
					Region = "8"
					Zone = "11(EC1)"
				}
	        }
			"*vcw00007i3*"
	        {
				[PSCustomObject]@{
					Name = "vcw00007i3"
					Site = "Farnborough"
					Region = "7"
					Zone = "10(CDS)"
				}
	        }
			"*vcw00008i3*"
	        {
				[PSCustomObject]@{
					Name = "vcw00008i3"
					Site = "Corsham"
					Region = "8"
					Zone = "11(CDS)"
				}
	        }
			"*vcv0003i3*"
			{
				[PSCustomObject]@{
					Name = "vcv00003i3"
					Site = "Corsham"
					Region = "5"
					Zone = "D"
				}
			}
			"*vcv00005i3*"
			{
				[PSCustomObject]@{
					Name = "vcv00005i3"
					Site = "Farnborough"
					Region = "6"
					Zone = "12"
				}
			}
	    }
	}
}
 
 <#
Example
 
Getting creds to login to vcenters:
$Cred = Get-Credential

Setting which vcenters to connect to:
$vCenterServers = @("vcw00003i2","vcw00005i2","vcw00005i7","vcv0000ei2")

The function works by specifying the parameter "vCenter", or by piping them in.
You can gather the the availability zones from the global variable $DefaultVIServers once you have connected to the vCenters using Connect-VIServer:
Get-AvailabilityZones -vCenter $DefaultVIServers.ServiceUri

Or you can get the availability zones from an array of strings contained in a variable:
$vCenterServers | Get-AvailabilityZones


Output will look like this:
Name       Site                  Region Zone    
----       ----                  ------ ----    
vcw00003i2 Farnborough & Corsham 1 & 2  1,2(AE1)
vcw00005i2 Corsham               2      2(AC1)  
vcw00007i2 Farnborough           1      1(AF2)  
vcv0000ei2 Farnborough           6      F              

#>

####################################################################################################################

Function Invoke-GUIForm{
	Param(
		$Title,
		$Questions
	)
	Process{
		$Position = 10
	    Add-Type -AssemblyName System.Windows.Forms
		
	    $form = New-Object Windows.Forms.Form
	    $form.Size = New-Object Drawing.Size @(500,(80+25*$Questions.Count))
	    $form.text = $Title
	    $form.StartPosition = "CenterScreen"
	    $form.Add_Shown({$form.Activate()})
		$NewVariables =@()
		Foreach ($Question in $Questions)
		{				
	    	$objLabel = New-Object System.Windows.Forms.Label
	    	$objLabel.Location = New-Object System.Drawing.Size(0,$Position)
	    	$objLabel.Size = New-Object System.Drawing.Size(200,20)
	    	$objLabel.Text = $Question
	    	$form.Controls.Add($objLabel)
		
	    	$edgeTextBox = New-Object System.Windows.Forms.TextBox
	    	$edgeTextBox.Location = New-Object System.Drawing.Size(275,$Position)
	    	$edgeTextBox.Size = New-Object System.Drawing.Size(125,5)
	    	$form.Controls.Add($edgeTextBox)
			
			
		    $eventHandler = [System.EventHandler]{
		    $textBox1.Text;
		    $textBox2.Text;
		    $textBox3.Text;
		    $form.Close();};
			$Position += 25
			
			$info = [PSCustomObject]@{
				Question = $Question
				Answer = $edgeTextBox
			}
			$NewVariables += $info
		}
		### Create Okay Button ###
		$okbtn = New-Object System.Windows.Forms.Button
		$okbtn.Location =  New-Object Drawing.Size @(275,(30*$questions.Count))
		$okbtn.Add_Click($eventHandler)
		$okbtn.DialogResult = [System.Windows.Forms.DialogResult]::OK
		$okbtn.Text = "Go..."
		$form.Controls.Add($okbtn)
			
		### Create Cancel Button ###
		$cancelbtn = New-Object System.Windows.Forms.Button
		$cancelbtn.Location =  New-Object Drawing.Size @(175,(30*$questions.Count))
		$cancelbtn.Add_Click($eventHandler)
		$cancelbtn.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
		$cancelbtn.Text = "Cancel"
		$form.Controls.Add($cancelbtn)
			
		$result = $form.ShowDialog()
		### What to do with details entered ###
		if($result -eq [System.Windows.Forms.DialogResult]::OK){
			$NewVariables |% {
				[PSCustomObject]@{
				Question = $_.Question
				Answer = $_.Answer.Text
				}
			}	
		} 
		else {
			write-host "Cancelled..."
		}
	}
}

####################################################################################################################

Function Invoke-GUIDropdownForm{
	Param(
		$Title,
		[Parameter(Mandatory=$true)]
		$Questions,
		[Parameter(Mandatory=$true)]
		$Answers
	)
	Process{
		
		$position2 = 0
		$Position = 15
		$NewVariables =@()
		$AnswerVariables = @()
		$Final = @()
		
	    $form = New-Object Windows.Forms.Form
	    $form.Size = New-Object Drawing.Size @(500,(80+25*$Answers.Count))
	    $form.text = $Title | out-null
	    $form.StartPosition = "CenterScreen"
		
		$Form.KeyPreview = $True
		
		$Form.Add_KeyDown({if ($_.KeyCode -eq "Enter") 
    	{$x=$objListBox.SelectedItem;$objForm.Close()}})
		$Form.Add_KeyDown({if ($_.KeyCode -eq "Escape") 
    	{$Form.Close()}})
		
		### Create Okay Button ###
		$okbtn = New-Object System.Windows.Forms.Button
		$okbtn.Location =  New-Object Drawing.Size @(275,(20+26*$Answers.Count))
		$okbtn.Add_Click($eventHandler)
		$okbtn.DialogResult = [System.Windows.Forms.DialogResult]::OK
		$okbtn.Text = "Go..."
		$form.Controls.Add($okbtn)
		
		### Create Cancel Button ###
		$cancelbtn = New-Object System.Windows.Forms.Button
		$cancelbtn.Location =  New-Object Drawing.Size @(175,(20+26*$Answers.Count))
		$cancelbtn.Add_Click($eventHandler)
		$cancelbtn.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
		$cancelbtn.Text = "Cancel"
		$form.Controls.Add($cancelbtn)
		
		### Create Questions from input ###
		Foreach ($Question in $Questions)
		{				
	    	$objLabel = New-Object System.Windows.Forms.Label
	    	$objLabel.Location = New-Object System.Drawing.Size(0,$Position)
	    	$objLabel.Size = New-Object System.Drawing.Size(200,20)
	    	$objLabel.Text = $Question 
	    	$form.Controls.Add($objLabel)
			$info = [PSCustomObject]@{
				Question = $Question
			}
			$NewVariables += $info
			$Position += 25.5
		}
		$Position = 10
		
		### create answers from input ###		
		Foreach ($Answer in $Answers)
		{
			$objListBox = New-Object System.Windows.Forms.ListBox 
			$objListBox.Location = New-Object System.Drawing.Size(275,$Position) 
			$objListBox.Size = New-Object System.Drawing.Size(100,25) 			
			$objListBox.SelectionMode = "One"
				
			Foreach ($Item in $Answer)
			{
				[void]$objListBox.Items.Add($Item)
			}
			$form.Controls.Add($objListBox)
			$info2 = [PSCustomObject]@{
				Answer = $objListBox.SelectedItems
			}
			$AnswerVariables += $info2
			$Position += 25
				
		}
				
		$result = $form.ShowDialog()
		### What to do with details entered ###
		if($result -eq [System.Windows.Forms.DialogResult]::OK){
			Foreach ($NewVariable in $NewVariables)
			{
				$Info3 = [PSCustomObject]@{
				Question = $NewVariable.Question
				Answer = $AnswerVariables.Answer | select -Index $Position2
				}
			$Final += $Info3
			$position2 += 1
			}
			$Final
		} 
		else {
			write-host "Cancelled..."
		}
	}
}

####################################################################################################################

Function Invoke-DateForm {
	Param(
		$Title
	)

	Add-Type -AssemblyName System.Windows.Forms
	Add-Type -AssemblyName System.Drawing

	$form = New-Object Windows.Forms.Form 

	$form.Text = $Title
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
	    return $calendar.SelectionStart
	}
}

####################################################################################################################

Function Write-Log
{
   Param (
   [string]$logstring,
   [Parameter(Mandatory=$True)]$file
   )

   Add-content $file -value $logstring
}

####################################################################################################################

Function Split-vCloudID{
	Param(
		[Parameter(ValueFromPipeline)]$String
	)
	if ($String -like "*(*-*-*-*-*)*"){
		$SplitString = $String -split " "
		$SplitString1 = $SplitString | Select -First ($SplitString.count -1)
		$SplitString1 -join " "
		$SplitString | Select -Last 1
	}else{
		$String
	}
}

####################################################################################################################

Function Get-EdgeConfig ($EdgeGateway)  { 
    $Edgeview = $EdgeGateway | get-ciview
    $webclient = New-Object system.net.webclient
    $webclient.Headers.Add("x-vcloud-authorization",$Edgeview.Client.SessionKey)
    $webclient.Headers.Add("accept",$EdgeView.Type + ";version=5.1")
    [xml]$EGWConfXML = $webclient.DownloadString($EdgeView.href)
     $Holder = "" | Select Firewall,NAT,LoadBalancer,DHCP
    $Holder.Firewall = $EGWConfXML.EdgeGateway.Configuration.EdgegatewayServiceConfiguration.FirewallService.FirewallRule
     $Holder.NAT = $EGWConfXML.EdgeGateway.Configuration.EdgegatewayServiceConfiguration.NatService.NatRule
     $Holder.LoadBalancer = $EGWConfXML.EdgeGateway.Configuration.EdgegatewayServiceConfiguration.LoadBalancerService.VirtualServer
     $Holder.DHCP = $EGWConfXML.EdgeGateway.Configuration.EdgegatewayServiceConfiguration.GatewayDHCPService.Pool
     Return $Holder
}
### Example ###

<# Search for an Edge by it's name by using:
$edge = Search-Cloud -querytype edgegateway -name "xxxxxxxxx"

Then use the function like so to retrieve the config:

$config = Get-EdgeConfig -EdgeGateway $edge
#>
####################################################################################################################