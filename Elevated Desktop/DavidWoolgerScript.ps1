$Companies = Get-EApiAccount

$vCenters = Get-CustomerVIServers -Domain $SecurityDomain
$Vcreds = Get-Credential

Foreach ($VC in $vCenters){
	Start-Job -ArgumentList $VC, $Vcreds, $Companies, $workspace -ScriptBlock {
        #$job_space = $args[3]
		#Import-Module -Name $job_space\Modules\PSModules\UKCloud.CSEJenkins.VMware
		Import-Module UKCloud.Support
		Connect-VIServer $args[0] -Credential $args[1] | Out-Null
		$VMs = Get-VM | Where {$_.name -notlike "vse-*"}
		Foreach ($VM in $VMs){
			# Get account numbers from the org retrieved from the VM
			$AccountNumber = $VM.Folder.Parent.Parent -split "-" | select -Index 1

			if (!$AccountNumber){Continue}
			elseif($AccountNumber.count -gt 1){Continue}

			# Retrieve company and account from estate Api
			$CompanyAccount = $args[2] | Where-Object {$_.domainIdentifier -like $AccountNumber }
		
			[PSCustomObject]@{
				Company = ($CompanyAccount.Company.Name | Out-String).Trim()
				Account = ($CompanyAccount.Name | Out-String).Trim()
        		OrgVDC = $VM.Folder.Parent | Split-vCloudID | Select -Index 0
				vApp = $VM.Folder | Split-vCloudID | Select -Index 0
				VM = $VM.Name | Split-vCloudID | Select -Index 0
				OS = $VM.Guest.OSFullName
				Cluster = $VM.VMHost.Parent.Name
				vCenter = $VM.Client.ConnectivityService.ServerAddress
		        Organisation = $VM.Folder.Parent.Parent | Split-vCloudID | Select -Index 0
			}
		}
	} | Out-Null
}

$Results = Get-Job | Wait-Job | Receive-Job
$Report = $Results | Select Company, Account, OrgVDC, vApp, VM, OS, Cluster, vCenter, Organisation
$Report | Export-Csv "C:\Users\sudandrews\Desktop\OSReport.csv" -NoTypeInformation