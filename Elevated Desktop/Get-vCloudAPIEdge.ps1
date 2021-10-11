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
		#$objListBox.SelectionMode = "MultiExtended"
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

$vCloudUrl = Invoke-MultiSelectForm -Objects "https://vcd.z00031.r00006.frn.portal.skyscapecloud.gsi.gov.uk", "https://vcd.z00030.r00005.cor.portal.skyscapecloud.gsi.gov.uk" -Title "Environment" -Message "Select your environment:"

### Enter endpoint and credentials here
$vCloudUrl = "https://vcd.portal.skyscapecloud.gsi.gov.uk"
$Username = "1318.9.1fd2ce@1-9-12-c352d4"
$Password = "Password321#"

### Convert credentials into Base64 encoded string
$Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username,$password)))

### Create headers for initial authentication request
$Headers = @{}
$Headers.Add("Authorization", "Basic $($Base64AuthInfo)")
$Headers.Add("Accept", "application/*+xml;version=32.0")

### POST initial authentication request with user's portal API credentials
$InitialResponse = Invoke-WebRequest -Method POST ($vCloudUrl + "/api/sessions") -Headers $Headers

### Create headers using the returned x-vcloud-authorization token, to be user with all further requests
$Headers = @{}
$Headers.Add("x-vcloud-authorization", $InitialResponse.Headers.'x-vcloud-authorization')
$Headers.Add("Accept", "application/*+xml;version=32.0")

### Gather Org
[XML]$RawOrgs = Invoke-WebRequest -Method GET ($vCloudUrl + "/api/org") -Headers $Headers

### Dive into Orgs and return their hrefs
$Orghrefs = $RawOrgs.OrgList.Org.href

$Report = @()
### Loop through each Org href and gather full Org object
foreach ($Orghref in $Orghrefs){
    [XML]$Org = Invoke-Webrequest -Method GET $Orghref -Headers $Headers

    ### Gather OrgVDC hrefs
    $OrgVDCHrefs = $Org.Org.Link | Where {$_.type -match "application/vnd.vmware.vcloud.vdc\+xml"} | Select -ExpandProperty href

    ### Loop through OrgVDC hrefs and get full objects
    $OrgVDCs = foreach ($OrgVDChref in $OrgVDChrefs){
        [XML]$OrgVDC = Invoke-Webrequest -Method GET $OrgVDChref -Headers $Headers

        ### Gather VDC Edge Gateways endpoint
        $EdgeGatewayEndpointHrefs = $OrgVDC.Vdc.Link | Where {($_.type -match "application/vnd.vmware.vcloud.query.records\+xml") -and ($_.rel -match "edgeGateways")} | Select -ExpandProperty href

        ### Loop through Edge Gateway enpoint hrefs and get full objects
        foreach ($EdgeGatewayEndpointhref in $EdgeGatewayEndpointhrefs){
            [XML]$EdgeGatewayEndpoint = Invoke-Webrequest -Method GET $EdgeGatewayEndpointhref -Headers $Headers

            ### Gather edge gateway endpoints
            $EdgeGatewayhrefs = $EdgeGatewayEndpoint.QueryResultRecords.EdgeGatewayRecord.href

            ### Get actual xml export of edge ###
            $EdgeGateways = foreach ($EdgeGatewayhref in $EdgeGatewayhrefs){
                [XML]$EdgeGateway = Invoke-Webrequest -Method GET $EdgeGatewayhref -Headers $Headers
                $Report += $EdgeGateway
            }
        }
    }
}


[$EdgeGateway.EdgeGateway | Export-Clixml -Path ("C:\Users\sudandrews\Desktop\" + $EdgeGateway.EdgeGateway.Name + ".xml")




