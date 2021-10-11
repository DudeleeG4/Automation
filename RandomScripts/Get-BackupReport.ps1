Function Get-UKCComputeService{
<#
.SYNOPSIS
This takes account objects and retrieves the compute services associated with them

.DESCRIPTION
You can pipe in objects retrieved using the "api/accounts" endpoint against the UKC Portal REST API and this function will use the ID field
to loop through all of the accounts and retrieve the compute services for them, containing information on Organisations, OrgVDCs, vApps and VMs.

.PARAMETER Accounts
This should be a UKC Portal object retrieved using the "api/accounts" endpoint.
For more information, please refer to https://docs.ukcloud.com/articles/portal/ptl-ref-portal-api.html

.EXAMPLE
$Accounts = Invoke-RestMethod -Method GET -Uri "https://portal.skyscapecloud.com/api/accounts" -WebSession $CoreSession
$Accounts | Get-UKCComputeService
#>
Param (
    [Parameter(ValueFromPipeline)]$Accounts
)
    Process {
        Foreach ($Account in $Accounts){
            $ComputeEP = "https://portal.skyscapecloud.com/api/accounts/" + $Account.id + "/compute_services"
            Invoke-RestMethod -Method GET -Uri $ComputeEP -WebSession $CoreSession
        }
    }
}

##################################################################################################################################

### Initial authentication - token will expire after 15 minutes - fill in your portal email and password and they will be passed into the body of the request
$PortalEmail = "YourPortalUsername"
$PortalPassword = "YourPortalPassword"
Invoke-WebRequest -Uri https://portal.skyscapecloud.com/api/authenticate -Method POST -Body @{email=$PortalEmail;password=$PortalPassword} -SessionVariable CoreSession 

### Retrieve the accounts that your Portal user has access to
$Accounts = Invoke-RestMethod -Method GET -Uri "https://portal.skyscapecloud.com/api/accounts" -WebSession $CoreSession

### Retrieve the compute services associated with those accounts
$ComputeServices = $Accounts | Get-UKCComputeService

### Loop through and drill down to build a backup report for each VM
$Report = Foreach ($ComputeService in $ComputeServices){
    Foreach ($vOrg in $ComputeService.vOrgs){
        Foreach ($VDC in $vOrg.VDCs){
            Foreach ($vApp in $VDC.vApps){
                Foreach ($VM in $VApp.VMs){
                    [PSCustomObject]@{
                        Organisation = $vOrg.serviceId
                        VDC = $VDC.name
                        vApp = $vApp.name
                        VM = $VM.name
                        "Last Backup Status" = $VM.lastBackupStatus
                        "In Backup" = $VM.inBackup
                        "Last Backup Date" = $VM.LastBackup
                    }
                }
            }
        }
    }
}

### Output report to pipeline
$Report