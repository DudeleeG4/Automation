
# Load VMWare modules and then clear the console
Get-Module -ListAvailable | Where {$_.Name -like "VM*"} | Import-Module
Clear

Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

##############################################################################################################################

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

##############################################################################################################################

# Connect to all customer facing vCenters using a function
Connect-CustomerVIServers

# Gather clusters and create object matching them to their vCenters
$Clusters = Get-Cluster
$Clusters = $Clusters |% {[PSCustomObject]@{
		ClusterObject = $_
		vCenter = $_.Client.ConnectivityService.ServerAddress
	}
}

# Sort clusters by vCenter and start looping through them
$Progress = 0
$Report = $Clusters | sort vCenter |%{
	$Cluster = $_.ClusterObject
	
# Check if the vCenter is Enhanced and if so, skip it
	$CurrentVC = $Cluster.Client.ConnectivityService.ServerAddress
	if (($CurrentVC -match "vcw00003i2") -or ($CurrentVC -match "vcw00003i3")){
		Write-Host "Skipping Stretched cluster $Cluster"
		$Progress ++
		Return
	}
	Try{
		Write-Progress -Id 1 -Activity "Working through $CurrentVC" -Status "Current Cluster: $Cluster" -PercentComplete ($Progress/$Clusters.Count*100)
	}
	Catch{
		Write-Progress -Id 1 -Activity "Working through $CurrentVC" -Status "Current Cluster: $Cluster" -PercentComplete ($Progress/1*100)
	}
	
# Get the hosts from the cluster
	$VMhosts = Get-VMHost -Location $Cluster
	if (!$VMhosts){
		Write-Host "No hosts in cluster, exiting..."
		Return
	}
	$Progress2 = 0
	
# Start looping through the hosts
	$VMhosts |%{
		Write-Progress -Id 2 -Activity "Working through hosts in Cluster" -Status "Current Host: $_" -PercentComplete ($Progress2/$VMHosts.Count*100) 
		$VMHost = $_
		
# Retrieve the Host Affinity DRS rules from the host and filter out any GEL HPC VMs or Zerto VRAs
		$HostRules = Get-DrsRule -Cluster $Cluster -VMHost $_ | Where {(($_.Name -notmatch "HPC") -and ($_.Name -notlike "Zerto_vm*"))}
		$Progress3 = 0
		$HostRules |% {
			Write-Progress -Id 3 -Activity "Working through DRS rules" -Status "$_" -PercentComplete ($Progress3/$HostRules.Count*100)
			$HostRule = $_
			$Progress4 = 0
# Start looping through the VMs listed in the Host Affinity DRS Rule
			$HostRule.VMIds |%{
				$VMId = $_
				Try{
					Write-Progress -Id 4 -Activity "Working through VMs.." -PercentComplete ($Progress4/$HostRule.VMIds.Count*100)
				}
				Catch{
				}
				Try {
					$VM = Get-VM -Id $_ -Server $CurrentVC
				}
				Catch{
				}
# Build Object with required details
				[PSCustomObject]@{
					vCenter = $CurrentVC
					Cluster = $Cluster
					Host = $VMhost
					VM = $VM
					RuleName = $HostRule.Name
					Enabled = $HostRule.Enabled
					Mandatory = $HostRule.Mandatory
				}
				$Progress4 ++
			}
			Write-Progress -Id 4 -Activity "Working through VMs.."
			$Progress3 ++
		}
		Write-Progress -Id 3 -Activity "Working through DRS rules"
		$Progress2 ++
	}
	$Progress ++
}

# Disconnect from vCenter and display results to the screen using Gridview
Disconnect-VIServer * -Confirm:$false
$Report | Out-GridView -Title "Pinned VMs" -PassThru
