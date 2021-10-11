
<#
.SYNOPSIS
Saves vCloud Edge configuration XML to file
	
.DESCRIPTION
Saves the full vCloud Edge configuration XML to file, and optionally prepares a separate XML file with VPN and/or Static Routes XML configuration pre-filled, ready to manually modify and upload later using Set-EdgeConfig.ps1
	
.EXAMPLE
PS C:\> Connect-CIServer api.vcd.portal.skyscapecloud.com
PS C:\> .\Get-EdgeConfig.ps1 -Name "nft000xxi3"

.EXAMPLE
PS C:\> Connect-CIServer vcloud
PS C:\> .\Get-EdgeConfig.ps1 -Name "nft001a4i2 -1" -PrepareXML
	
.NOTES
Author: Adam Rush
Created: 2016-11-25
This version updated by: Dylan Coombes

---------------------THIS VERSION IS FOR USE WITH GET-VMEDGE ONLY---------------------

#>
	
Param (

[parameter(Mandatory=$true)]
[ValidateNotNullOrEmpty()]
[String]$Name,

[parameter(Mandatory=$false)]
[Switch]$PrepareXML
)    	

# Variables
$timestamp = (Get-Date -Format ("yyyy-MM-dd_HH-mm"))
$SavePath = "$(Get-Location)\EdgeExports"
$EdgeXMLPath = "$SavePath\EdgeConfig.xml"

    
# Create save path if it does not exist
if(!(Test-Path -Path $SavePath)){
	$TempObj = New-Item -ItemType Directory -Force -Path $SavePath
}

# Check for vcloud connection
if (-not $global:DefaultCIServers) {
    Write-Warning "Please connect to vcloud before using this function, eg. Connect-CIServer vcloud"
    Break
}

# Find Edge
try {
	$EdgeView = Search-Cloud -QueryType EdgeGateway -Name $Name -ErrorAction Stop | Get-CIView
} catch {
    Write-Warning "Edge Gateway with name $Name not found, exiting..."
    Break
}

# Test for null object
if ($EdgeView -eq $null) {
      Write-Warning "Edge Gateway result is NULL, exiting..."
      Break    
}

# Test for 1 returned object
if ($EdgeView.Count -gt 1) {
      Write-Warning "More than 1 Edge Gateway found, exiting..."
      Break   
}

# Set headers
$Headers = @{
    "x-vcloud-authorization"=$EdgeView.Client.SessionKey
    "Accept"=$EdgeView.Type + ";version=30.0"
}

# Get Edge Configuration in XML format
$Uri = $EdgeView.href
[XML]$EGWConfXML = Invoke-RestMethod -URI $Uri -Method Get -Headers $Headers 

# Export XML
$EGWConfXML.save($EdgeXMLPath)
Write-Host -ForegroundColor yellow "XML Config saved to $SavePath"
