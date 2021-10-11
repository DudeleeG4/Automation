Get-Module -ListAvailable | Where {$_.Name -like "VM*"} | Import-Module
Clear

##########################################################################################################

Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

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

##########################################################################################################

# Connect to all customer facing vCenters using a function
Connect-CustomerVIServers

# Get all compute clusters
$Clusters = Get-Cluster

# Loop through all the clusters
$Progress = 0
$Report = $Clusters |%{
	Write-Progress -Activity "Gathering DRS Rules.." -Status "Cluster: $_" -PercentComplete ($Progress/$Clusters.Count*100) -Id 1
	$Cluster = $_
	
	# Gather the DRS Rules from the current cluster
	$DRSRules = Get-DrsRule -Cluster $Cluster
	
	# Loop through the DRS rules on the cluster
	$Progress2 = 0
	$DRSRules |%{
		Write-Progress "Getting VMs.." -PercentComplete ($Progress2/$DRSRules.Count*100) -Id 2 -ParentId 1
		$DRSRule = $_
		
		# Gather the VMs that are part of the rule
		$VMs = Get-VM -Id $_.VMIds
		
		# Loop through VMs and build report
		$VMs |% {
			[PSCustomObject]@{
				vCenter = $DRSRule.Client.ConnectivityService.ServerAddress -split "\." | Select -First 1
				"DRS Rule" = $DRSRule.Name
				"Type" = $DRSRule.Type
				VM = $_.Name
				CPUs = $_.NumCpu
				"Memory MB" = $_.MemoryMB
				OrgVDC = $_.Folder.Parent.name
				Org = $_.Folder.Parent.Parent.Name
				Cluster = $Cluster
				Mandatory = $DRSRule.Mandatory
			}
		}
		$Progress2 ++
	}
	$Progress ++
}

# Export the report to CSV
$Report | Where {$_."DRS Rule" -like "*:*-*-*-*-*"} | Sort vCenter, "DRS Rule", "Type" | Export-Csv "C:\Scripts\Technology\CSE\Customer Affinity Rules.csv" -NoTypeInformation
