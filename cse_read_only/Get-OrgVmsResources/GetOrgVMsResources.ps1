################ GetOrgVMsResources.ps1 ################

# Exports a CSV of all VMs with specific allocated resources within a given organisation
# Created By: Ben Rees - brees@ukcloud.com
# Created: 23/05/2019
# Last Updated: 19/09/2019

########################################################


Param (

[parameter(Mandatory=$true)]
[ValidateNotNullOrEmpty()]
[String]$Org # Takes Org parameter

)

$vcloud = Read-Host "Which vCloud: "

Connect-CIServer $vcloud

$csv = $org + "_VmList.csv"
Add-Content $csv "VM, Status, vCPU, RAM, vApp, VDC, vCloud"

$vdcs = Get-Org -Name $org | Get-OrgVdc # gets all VDCs in org

foreach ($vdc in $vdcs) { #loops through each VDC in org

	$vdcname = $vdc.name #gets VDC anme
	$vapps = Get-OrgVdc -Name $vdcname | Get-CIVApp #gets vApps

	foreach ($vapp in $vapps) { #loops through vApps
	
		$vappname = $vapp.name
		$vms = Get-CIVM -VApp $vapp #gets VMs from vApps
		

		foreach ($vm in $vms) { #loops through VMs
			
			# Gets VM resources
			$vmname = $vm.name
			$status = $vm.Status
			$CPU = $vm.CpuCount
			$RAM = $vm.MemoryGB
			
			#Writes info to CSV
			$write = "$vmname, $status, $CPU, $RAM, $vappname, $vdcname, $vcloud"
			Add-Content $csv $write

		}
	}
}
