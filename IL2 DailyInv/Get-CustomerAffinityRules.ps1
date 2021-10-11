Get-Module -ListAvailable | Where {$_.Name -like "VM*"} | Import-Module
Clear

##########################################################################################################

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
if($env:USERDOMAIN -match "IL2"){ 
    # Hardcoded Credentials - will be removed soon
    $unameS = "il2management\sciencelogicvcw"
    $credsS = "As5^l2%j9^j1*u7*s9!"
	$userPasswordS = ConvertTo-SecureString "$credsS" -AsPlainText -Force
	$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $unameS,$userPasswordS
}
elseif($env:USERDOMAIN -match "IL3"){
    $unameS = "il3management\sciencelogicvcw"
    $credsS = 'Sd4^l6$o9*z8^t7%r1!'
	$userPasswordS = ConvertTo-SecureString "$credsS" -AsPlainText -Force
	$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $unameS,$userPasswordS
}


# Connect to all customer facing vCenters using a function
Connect-CustomerVIServers -Credential $Cred

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

$Date = Get-Date -Format dd-MM-yyyy
$FilePath = "C:\ScheduledScripts\Affinity Rules Report\Customer Affinity Rules $Date .csv"

# Export the report to CSV
$Report | Where {$_."DRS Rule" -like "*:*-*-*-*-*"} | Sort vCenter, "DRS Rule", "Type" | Export-Csv $FilePath -NoTypeInformation


$style = "<style>"

$style += "body{background-color:#ffffff; font-size:12px;}"
$style += "table{border:1px solid #000000; padding:0px; margin 0px;}"
$style += "th{background-color:#266dc9;padding:0px;margin:0px;color:#ffffff;padding-left:3px;padding-right:3px;}"
$style += "td{padding:0px;padding-right:10px;margin:0px;padding-left:5px}"
$style += "tr{padding0px;margin:0px;border-bottom:border:1px solid #000000;padding-right:10px}"

$style += "</style>"

$scriptResultsHTML = $Report | Where {$_."DRS Rule" -like "*:*-*-*-*-*"} | Sort vCenter, "DRS Rule", "Type" | ConvertTo-Html -Head $style | Out-String

If ($env:USERDOMAIN -like "*il2*"){
	Send-MailMessage -To triage@ukcloud.com -Bcc dandrews@ukcloud.com -From AffinityRulesIL2@ukcloud.com -Subject "Affinity rules on Assured" -Body $scriptResultsHTML -Attachments $FilePath -BodyAsHtml -SmtpServer rly00001i2
}
Else {
	Send-MailMessage -To triage@ukcloud.com -Bcc dandrews@ukcloud.com -From AffinityRulesIL3@ukcloud.com -Subject "Affinity rules on Elevated" -Body "Results can be found on apw00029i3 at $FilePath" -BodyAsHtml -SmtpServer 10.72.81.30
}