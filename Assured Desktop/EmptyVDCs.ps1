<#
.SYNOPSIS
	This script retrieves the Uptime information for all VMs on the given vCenter(s).

.DESCRIPTION
    This script is for use on the CSE Jenkins cluster. It will fail to retrieve the uptime for VMs 
	which do not have VMWare Tools installed.

.PARAMETER SecurityDomain
    This is the security domain that the script will run in

.PARAMETER SintAPIKey
	This is the API key that will be used to retrieve credentials from Sint
		
.NOTES
	Author: Dudley Andrews
	Last Update: 28/02/2019
#>

Param(
    [String][ValidateSet("Assured","Elevated")]$SecurityDomain,
	[Parameter(Mandatory)]$SintAPIKey
)

# Retrieve current location within Jenkins slave
$workspace = Get-Location 

# Import local modules from the workspace
Try{
	Import-Module -Name $workspace\Modules\PSModules\UKCloud.CSEJenkins.EstateAPI
	Import-Module -Name $workspace\Modules\PSModules\UKCloud.CSEJenkins.Sint 
    Import-Module -Name $workspace\Modules\PSModules\UKCloud.CSEJenkins.VMware
}Catch{
	Write-Error -Message "Pre-requisite modules not installed!"
    Write-Host -ForegroundColor Yellow "Please install the prerequisite modules: UKCloud.Sint, UKCloud.vCentre & UKCloud.EstateAPI"
    exit
}

############################################################################################################################

# Setting variables for estate api
$Global:Answer = $SecurityDomain
$Global:SintAPIKey = $SintAPIKey

# Setting variables for output
$GDate = Get-Date -Format "yyyy-MM-dd"
$FilePath = "$($workspace)\Script\VMUptimeReport($GDate).csv"
$Filepath2 = "$($workspace)\Script\VMUptimeReport2.csv"

# Sets the credentials based on the security domain
if($SecurityDomain -match "Assured"){	
	$VUsename = 'Scheduled Task User'
	$VCI = 'dom00001i2'	
	$ReportDomain = "il2"
	$ReportDomain2 = "2"
} ElseIf ($SecurityDomain -match "Elevated") {	
	$VUsename = 'Scheduled Task User'
	$VCI = 'dom00001i3'
	$ReportDomain = "il3"
	$ReportDomain2 = "3"	
}

$VCreds = Get-CredentialFromSINT -SecurityDomain $SecurityDomain -SintAPIKey $SintAPIKey -User $VUsename -CI $VCI

############################################################################################################################

# Retrieve company data from estate Api
$Companies = Get-EApiAccount

$vClouds = Get-CustomerCIServers -Domain $SecurityDomain

Foreach ($vCloud in $vClouds){
	Start-Job -ArgumentList $vCloud, $vCreds, $Companies, $workspace -ScriptBlock {
		Import-Module -Name $args[3]\Modules\PSModules\UKCloud.CSEJenkins.VMware
		Connect-CIServer $args[0] -Credential $args[1] | Out-Null
		
		# Retrieve OrgVDCs which are not using any storage space
		$OrgVDCs = Get-OrgVdc | Where {$_.StorageUsedGB -eq 0}
		
	    Foreach ($OrgVDC in $OrgVDCs){
		# Get Account number from VDCs' Org number
		$AccountNumber = $OrgVDC.Org -split "-" | Select -Index 1
		
		# Retrieve company and account from estate Api
		$CompanyAccount = $args[2] | Where-Object {$_.domainIdentifier -like $AccountNumber}
		
			[PSCustomObject]@{
				Company = ($CompanyAccount.Company.Name | Out-String).Trim()
				Account = ($CompanyAccount.Name | Out-String).Trim()
				OrgVDC = $OrgVDC.Name
				Organisation = $OrgVDC.Org
			}
		}
	} | Out-Null
}
$Results = Get-Job | Wait-Job | Receive-Job
$Report = $Results | Select Company, Account, OrgVDC, "Organisation" 
$Report | Export-Csv $FilePath -NoTypeInformation
$Report | Export-Csv $FilePath2 -NoTypeInformation