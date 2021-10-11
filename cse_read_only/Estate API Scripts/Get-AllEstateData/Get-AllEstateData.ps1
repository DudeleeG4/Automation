Clear

#################################################################################################################################################
Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}
function Multi-Select
{
	Param (
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

##############################################################################################################

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

###########################################################################################################################

Function Get-SintCreds {	
	Param($CI, $Username, $Answer)

	If($env:USERDOMAIN -match "IL2"){ 
		$url_il = "https://sint.il2management.local"
	}
	ElseIf($env:USERDOMAIN -match "IL3"){
		$url_il = "https://sint.il3management.local"
	}
	ElseIf($Answer -match "IL2"){
		$url_il = "https://sint.il2management.local"
	}
	ElseIf(($Answer -match "IL3") -or ($Answer -match "Combined")){
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

###########################################################################################################################
Function Read-SintAPIKey {
	Param($ImpactLevel)
	If ($ImpactLevel -match "IL2"){
		$securedValue = Read-Host -Prompt "Please enter your IL2 SINT API Key:" -AsSecureString
	}
	ElseIf ($ImpactLevel -match "IL3"){
		$securedValue = Read-Host -Prompt "Please enter your IL3 SINT API Key:" -AsSecureString
	}
	ElseIf ($ImpactLevel -match "Combined"){
		$securedValue = Read-Host -Prompt "Please enter your IL3 SINT API Key:" -AsSecureString
	}
	$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securedValue)
	[System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
}		
###########################################################################################################################


if($env:USERDOMAIN -match "IL2"){
		$Answer = "IL2"
		$SintAPIKey = Read-SintAPIKey -ImpactLevel $Answer
		$username,$password = Get-SintCreds -CI "oss00001i2" -Username "internal-user-assured" -Answer $Answer -SintAPIKey $SintAPIKey
	}
	elseif($env:USERDOMAIN -match "IL3"){
		$Answer = "IL3"
		$username,$password = Get-SintCreds -CI "oss00001" -Username "internal-user-elevated" -Answer $Answer -SintAPIKey $SintAPIKey
	}
	else{
		$Answer = Multi-Select -message "Where do you want to pull data from?" -title "Pick an option:" -objects "IL2", "IL3", "Combined"
		If ($Answer -match "IL2"){
			Write-Host "Selected: IL2"
			$SintAPIKey = Read-SintAPIKey -ImpactLevel $Answer
			$username,$password = Get-SintCreds -CI "oss00001i2" -Username "internal-user-assured" -Answer $Answer -SintAPIKey $SintAPIKey
		}
		ElseIf ($Answer -match "IL3"){
			Write-Host "Selected: IL3"
			$SintAPIKey = Read-SintAPIKey -ImpactLevel $Answer
			$username,$password = Get-SintCreds -CI "oss00001" -Username "internal-user-elevated" -Answer $Answer -SintAPIKey $SintAPIKey
		}
			ElseIf ($Answer -match "Combined"){
			Write-Host "Selected: Combined"
			$SintAPIKey = Read-SintAPIKey -ImpactLevel $Answer
			$username,$password = Get-SintCreds -CI "oss00001" -Username "internal-users-combined" -Answer $Answer -SintAPIKey $SintAPIKey
		}
	}

Write-Host "Working, please wait..."

[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
$URL1 = "https://keycloak.combined.local/auth/realms/estate-api/protocol/openid-connect/token"

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

$URL = "https://estate-api.combined.local/api"

$dict = @{}
$dict.Add("Authorization",$R1.access_token)
	   
$Body2 = @{query = "query VDCsOnAVcenter(`$vcenterName: String) {
	vcloudVcenters(name: `$vcenterName) {
	    urn
	    name
	    vcloudPvdcs {
			name
	     	vcloudVdcs {
	        	name
				vcloudVapps{
					name
					vcloudVms{
						name
						powerStatus
						operatingSystem
					}
				}
	        	vcloudOrg {
					name
		          	service {
		           		securityDomain
		            	name
		            	account {
		              		name
		              		company {
		                		name
							}
		            	}
		          	}
	        	}
	      	}
	   	}
	}
}"
<#;variables = '{"vcenterName":' + '"'  + $vCenterSelection + '"}'#>}

$Zones = @()
$Zones += [PSCustomObject]@{
	Name = "vcw00002i2"
	Site = "Farnborough"
	Region = "1"
	Zone = "1(AF1)"
}
$Zones += [PSCustomObject]@{
	Name = "vcw00003i2"
	Site = "Farnborough & Corsham"
	Region = "1 & 2"
	Zone = "1,2(AE1)"
}
$Zones += [PSCustomObject]@{
	Name = "vcw00005i2"
	Site = "Corsham"
	Region = "2"
	Zone = "2(AC1)"
}
$Zones += [PSCustomObject]@{
	Name = "vcw00007i2"
	Site = "Farnborough"
	Region = "1"
	Zone = "1(AF2)"
}
$Zones += [PSCustomObject]@{
	Name = "vcw00008i2"
	Site = "Farnborough"
	Region = "1"
	Zone = "1(AF3)"
}
$Zones += [PSCustomObject]@{
	Name = "vcw00009i2"
	Site = "Corsham"
	Region = "2"
	Zone = "2(AC2)"
}
$Zones += [PSCustomObject]@{
	Name = "vcw0000ai2"
	Site = "Corsham"
	Region = "2"
	Zone = "2(AC3)"
}
$Zones += [PSCustomObject]@{
	Name = "vcv00004i2"
	Site = "Farnborough"
	Region = "1"
	Zone = "1(AF4)"
}
$Zones += [PSCustomObject]@{
	Name = "vcv00005i2"
	Site = "Corsham"
	Region = "2"
	Zone = "2(AC4)"
}
$Zones += [PSCustomObject]@{
	Name = "vcv00007i2"
	Site = "Corsham"
	Region = "4"
	Zone = "3"
}
$Zones += [PSCustomObject]@{
	Name = "vcv0000ci2"
	Site = "Corsham"
	Region = "5"
	Zone = "B"
}
$Zones += [PSCustomObject]@{
	Name = "vcv0000ei2"
	Site = "Farnborough"
	Region = "6"
	Zone = "F"
}		
$Zones += [PSCustomObject]@{
	Name = "vcw00002i3"
	Site = "Farnborough"
	Region = "7"
	Zone = "10(EF1)"
}
$Zones += [PSCustomObject]@{
	Name = "vcw00003i3"
	Site = "Farnborough & Corsham"
	Region = "7 & 8"
	Zone = "10,11(EE1)"
}
$Zones += [PSCustomObject]@{
	Name = "vcw00005i3"
	Site = "Corsham"
	Region = "8"
	Zone = "11(EC1)"
}
$Zones += [PSCustomObject]@{
	Name = "vcw00007i3"
	Site = "Farnborough"
	Region = "7"
	Zone = "10(CDS)"
}
$Zones += [PSCustomObject]@{
	Name = "vcw00008i3"
	Site = "Corsham"
	Region = "8"
	Zone = "11(CDS)"
}
$Zones += [PSCustomObject]@{
	Name = "vcv00003i3"
	Site = "Corsham"
	Region = "5"
	Zone = "D"
}
$Zones += [PSCustomObject]@{
	Name = "vcv00005i3"
	Site = "Farnborough"
	Region = "6"
	Zone = "12"
}

$R = Invoke-RestMethod -Uri $URL -Headers $dict -Method Post -Body $Body2 -ContentType "application/x-www-form-urlencoded"
$Report = $R.data.vcloudVcenters |% {
	$vCenter = $_
	$_.vcloudPvdcs |%{
		$PvDC = $_
		$_.vcloudVdcs |%{
			$OrgVdc = $_
			$OrgID = $_.vCloudOrg.Name
			$_.vcloudOrg.Service |%{
				$service = $_
				$_.Account |%{
					$Account = $_
					$_.Company |%{
						$Company = $_
					}
				}
			}
			$_.vcloudVapps |%{
				$vApp = $_
				$_.vCloudVMs |%{
					$VM = $_
					$Zone = $Zones | Where {$_.Name -match $vCenter.name}
					[PSCustomObject]@{
						Company = $Company.Name
						Account = $Account.Name
						"Security Domain" = $service.securityDomain
						Site = $Zone.Site
						Region = $Zone.Region
						Zone = $Zone.Zone
						vCenter = $vCenter.Name
						PvDC = $PvDC.name
						Service = $service.name
						OrgID = $OrgID
						OrgVdc = $OrgVdc.name
						vApp = $vApp.Name
						VM = $VM.Name
						"Power State" = $VM.powerStatus
						OS = $VM.OperatingSystem			
					}
				}
			}
		}
	}
}

If ($Report){
	$DesktopPath = [Environment]::GetFolderPath("Desktop")
	$OutPath = "$DesktopPath\EstateAPIVMList.csv"
	$Report | Export-Csv -NoTypeInformation $OutPath
	Clear
	Write-Host "EstateAPIVMList.csv has been exported to your Desktop."
	Read-Host -Prompt "Press Enter to exit"
}Else{
	Clear
	Write-Host "Something went wrong, no data was retrieved."
	Read-Host -Prompt "Press Enter to exit"
}