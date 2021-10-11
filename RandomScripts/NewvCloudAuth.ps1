Function Invoke-MultiSelectForm{
<#
.SYNOPSIS
    This function brings up a GUI interface for multiple or single selection of objects
.PARAMETER Title
    Specifies the text in the title bar of the window
.PARAMETER Objects
    Specifies the objects that will be selectable by the user
.PARAMETER Message
    Specifies the text within the window
#>
Param (
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
		$objListBox.HorizontalScrollbar = $True
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

Function Get-UKCAPICreds{
<#
.SYNOPSIS
    This function will retrieve the API Username and Service name for each account in a User's portal Login (it does not retrieve passwords as that would just be the user's portal password)

.PARAMETER Accounts
    This would be a portal account object, retrieved using a Get request against the portal URL, with /accounts on the end. More detail can be found on the UKC portal API documentation here:
    https://docs.ukcloud.com/articles/portal/ptl-ref-portal-api.html#get-apiaccounts
#>
Param (
    [Parameter(ValueFromPipeline)]$Accounts
)
    Process {
        Foreach ($Account in $Accounts){
            $ComputeEP = ("https://" + $Global:PortalEP + "/api/accounts/") + $Account.id + "/api_credentials"
            $Result = Invoke-RestMethod -Method GET -Uri $ComputeEP -WebSession $CoreSession
            $Result | GM -MemberType NoteProperty | Select -ExpandProperty Name |% {$Result.($_)}
        }
    }
}

Function Split-UKCAPIUsername {
<# 
.SYNOPSIS
	This function takes a UKCloud API username in the format "username@orgid" and splits it to return just the username - necessary for connecting to vCloud via PowerCLI

.PARAMETER Usernames
	This would be one or more API username(s) retrieved as part of the Get-UKCAPICreds cmdlet
#>
Param(
    [Parameter(ValueFromPipeline)]$Usernames
)
    Process {
        Foreach ($Username in $Usernames){
            $Username -Split "@" | Select -First 1
        }
    }
}

Function Get-SimpleCred {
<# 
.SYNOPSIS
	This function takes a powershell credential object and returns the username and password un-encrypted

.PARAMETER Credentials
	This would be a powershell credential object, such as would be created using "Get-Credential"
#>
param(
	[Parameter(ValueFromPipeline)][Management.Automation.PSCredential]$Credentials
)
Process {
	    $Username = $Credentials.Username
	    $Password = $Credentials.GetNetworkCredential().Password
        Return $Username, $Password
    }
}

Function Set-UKCPortalEP {
<#
.SYNOPSIS
    Set the currect Portal API Endpoint based on security domain
.PARAMETER SecurityDomain
    Must be either "Assured" or "Elevated
#>
Param(
    [Parameter(ValueFromPipeline)]$SecurityDomain
)
    if ($SecurityDomain -match "Elevated"){
        $Global:PortalEP = "portal.skyscapecloud.gsi.gov.uk"
    }elseif ($SecurityDomain -Match "Assured"){
        $Global:PortalEP = "portal.skyscapecloud.com"
    }
}

##################################################################################################################################

### Prompt the user to choose the security domain ###
$SecurityDomain = Invoke-MultiSelectForm -Objects "Assured", "Elevated" -Title "Environment" -Message "Select your environment:"
$SecurityDomain | Set-UKCPortalEP

### Set CIServer
$CIServers = "vcd.pod00002.sys00002.portal.skyscapecloud.com"


### Prompt user to enter their Portal login creds ###
$Creds = Get-Credential -Message "Please enter your $($SecurityDomain) UKCloud portal Credentials"

### Get the simple Username and Password out of $Creds to be used for portal authentication and vCloud authentication ###
$SimpleCred = $Creds | Get-SimpleCred
$PortalEmail = $SimpleCred[0]
$PortalPassword = $SimpleCred[1]

### Initial authentication with the portal to create authentication cookies in web session ###
Invoke-WebRequest -Uri ("https://" + $Global:PortalEP + "/api/authenticate") -Method POST -Body @{email=$PortalEmail;password=$PortalPassword} -SessionVariable CoreSession

### Tell the user what is happening ###
Write-Host "Retrieving your accounts..."

### Retrieve the accounts that your Portal user has access to ###
$Accounts = Invoke-RestMethod -Method GET -Uri ("https://" + $Global:PortalEP + "/api/accounts") -WebSession $CoreSession

### Prompt user to select which account they'd like to access
$AccountSelection = Invoke-MultiSelectForm -Objects $Accounts -Title "Accounts" -Message "Select which account you'd like to access:"

### Retrieve the API credentials (without passwords) for every service listed in the account ###
$APICreds = $AccountSelection | Get-UKCAPICreds

### Tell the user what is happening ###
Write-Host "Connecting to environment(s), please wait."

### Loop through all API credential/Service pairs and connect via PowerCLI ###
Foreach ($APICred in $APICreds){
    $CurrentAPIUsername = $APICred | Select -ExpandProperty username | Split-UKCAPIUsername
    Foreach ($CIServer in $CIServers){
        Connect-CIServer $CIServer -Org ($APICred.service_id) -Username $CurrentAPIUsername -Password $PortalPassword -ErrorAction SilentlyContinue -ErrorVariable AuthFail
        if ($AuthFail){
            $AuthFailedOrgs += $APICred.service_id + "`n"
        }
    }
}

