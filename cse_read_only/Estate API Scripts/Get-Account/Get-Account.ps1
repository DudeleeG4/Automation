Clear

####################################################################################################################
Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

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

###########################################################################################################################


Function Connect-SINTAPI($url)
{
	if($env:COMPUTERNAME -like "*I2*")
	{ 
		$auth_key= "d1e73d74b02e0a0b27232e5170c9f16c446578a3"
    }
	elseif($env:COMPUTERNAME -like "*I3*")
	{
		$auth_key= "2fa6ea567589aaef94ff8f841c021aa2c27bbc33"
	}
	ElseIf($Global:Answer -match "IL2"){
		$auth_key= "d1e73d74b02e0a0b27232e5170c9f16c446578a3"
	}
	ElseIf($Global:Answer -match "IL3"){
		$auth_key= "2fa6ea567589aaef94ff8f841c021aa2c27bbc33"
	}
	else
	{
		$auth_keys = @("d1e73d74b02e0a0b27232e5170c9f16c446578a3", "2fa6ea567589aaef94ff8f841c021aa2c27bbc33")
		$auth_key = $auth_keys | Out-GridView -Title "Choose which authorisation key to use to connect to SINT (the first is IL2):" -Passthru
	}	
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

###########################################################################################################################

Function Get-SintCreds {	
	Param($CI, $Username)

	If($env:COMPUTERNAME -like "*I2*"){ 
		$url_il = "https://sint.il2management.local"
	}
	ElseIf($env:COMPUTERNAME -like "*I3*"){
		$url_il = "https://sint.il3management.local"
	}
	ElseIf($Global:Answer -match "IL2"){
		$url_il = "https://sint.il2management.local"
	}
	ElseIf($Global:Answer -match "IL3"){
		$url_il = "https://sint.il3management.local"
	}
	else
	{
		$urls_il = @("https://sint.il2management.local", "https://sint.il3management.local")
		$url_il = $urls_il | Out-GridView -Title "Choose which Impact Level SINT to connect to:" -Passthru
	}
    $hostname = $CI
    $passlabel = $Username
    $url = "$url_il/api/cmdb/search?hostname=$hostname"
    $pwd = Connect-SINTAPI $url
    $url ="$url_il/api/ci/ci/"+$pwd.data.id+"/credentials"
    $pwds = Connect-SINTAPI $url
    foreach($pwd in $pwds){
        $id = $pwd.label

        if ($id -match $passlabel)
        {
            $usr   = $pwd.username 
            $pwdId = $pwd.id 
        }  
    }
    $url = "$url_il/api/pwdb/credentials/$pwdId/password"
    $pwd = Connect-SINTAPI $url
    return $usr,$pwd
}


###########################################################################################################################



if($env:COMPUTERNAME -like "*I2*")
	{ 
		$username,$password = Get-SintCreds -CI "oss00001i2" -Username "internal-user-assured"
		$ImpactLevel = "Assured"
	}
	elseif($env:COMPUTERNAME -like "*I3*")
	{
		$username,$password = Get-SintCreds -CI "oss00001" -Username "internal-user-elevated"
		$ImpactLevel = "Elevated"
	}
	else
	{
		$choices = @("IL2", "IL3")
		$Answer = Multi-Select -title "Impact Level Selection" -message "Choose an Impact Level" -objects $Choices
		If ($Answer -match "IL2"){
		$username,$password = Get-SintCreds -CI "oss00001i2" -Username "internal-user-assured"
		$ImpactLevel = "Assured"
		}
		ElseIf ($Answer -match "IL3"){
		$username,$password = Get-SintCreds -CI "oss00001" -Username "internal-user-elevated"
		$ImpactLevel = "Elevated"
		}
	}

[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
$URL1 = "https://keycloak-keycloak.beta.openshift.combined.local/auth/realms/estate-api/protocol/openid-connect/token"

$Body = @{
grant_type = "client_credentials"
client_id = $Username
client_secret = $Password
}
Try{
$R1 = Invoke-RestMethod -Uri $URL1 -Method Post -Body $body -ContentType "application/x-www-form-urlencoded"
}
Catch{
$TheError = $_
Write-Host "It hasn't bloody worked!"
Write-Host $_.CategoryInfo
Write-Host $_.Exception.Message
Write-Host $_.Exception.InnerException.Message
Read-Host "Press Enter to exit"
Break
}

$URL = "https://estate-api-estate-api.beta.openshift.combined.local/api"

$dict = @{}
$dict.Add("Authorization",$R1.access_token)

$CompanyNumber = Invoke-GUIForm -Questions "Enter Company Number:", "Enter Account Number:"
#$ImpactLevel = Multi-Select -title "Security Domain" -message "Please select a security domain" -objects "Assured","Elevated"

$Query = @{query = "query findCompanyByDomainId(
  `$securityDomain: [SecurityDomain!],
  `$companyId: [Int!],
  `$accountId: [Int!]
) {
  services(
  companyDomainIdentifier: `$companyId,
  accountDomainIdentifier: `$accountId,
  securityDomain: `$securityDomain){
    name
    account{
      name
	  company{
	  	name
		}
    }  
  }
}";variables = '{"companyId":' + $CompanyNumber[0].Answer + ', "accountId":' + $CompanyNumber[1].Answer + ', "SecurityDomain":"' + $ImpactLevel + '"}'}



$R = Invoke-RestMethod -Uri $URL -Headers $dict -Method Post -Body $query -ContentType "application/x-www-form-urlencoded"
$Report = $R.data.services |% {
	[PSCustomObject]@{
		Company = $_.Account.Company.Name
		Account = $_.Account.Name
		Service = $_.Name
	}
}

$Report | Out-GridView -Title "Results" -PassThru

if (!$Report){
Write-Host "No results."
Read-Host "Press Enter to exit"
Break
}
