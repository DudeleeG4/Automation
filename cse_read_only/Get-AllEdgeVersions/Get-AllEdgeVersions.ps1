Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

# Check if user is running powershell as admin and if not, elevate to admin

If (
-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
){   
$arguments = "& '" + $myinvocation.mycommand.definition + "'"
Start-Process powershell -Verb runAs -ArgumentList $arguments
Break
}

# Load the vmware PowerCLI modules
Get-Module -ListAvailable | Where {$_.Name -like "VM*"} | Import-Module

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

Clear

# Connect to all customer vCenters using function
Connect-CustomerVIServers

# Gather all VM names starting with "vse-" using get-view
$Filter = @{Name="vse-*"}
$ViewVMs = Get-View -ViewType VirtualMachine -Filter $filter

# Build report of the Edge's listing their name, version and vCenter
$Progress = 0
$Report = $ViewVMs |% {
	$CurrentVMName = $_.Name
	Write-Progress -Activity "Gathering Edge Versions.." -Status "$CurrentVMName" -PercentComplete ($Progress/$ViewVMs.Count*100)
	Try{
		[PSCustomObject]@{
			Name = $_.Name
			Version = $_.Config.VAppConfig.Product[0].Version
			vCenter = $_.Client.ServiceUrl -split "/" | select -Index 2
		}
	}
	Catch{
	}
	$Progress ++
}

# Disconnect from the vCenters
Disconnect-VIServer * -Confirm:$false

# Output report to file
$Report | Export-Csv "C:\Scripts\Technology\CSE\All Edge Versions Report.csv" -NoTypeInformation

# Tell the user that the script is complete and where to find the output
Write-Host "Complete!"
Write-Host "Output can be found at - C:\Scripts\Technology\CSE\All Edge Versions Report.csv"

# Prompt the user for input before exiting, this stops the script from immediately exiting upon completion so that the user has time to read where the output is
Read-Host -Prompt "Press enter to exit"
