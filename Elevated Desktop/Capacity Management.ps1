Get-Module -ListAvailable | Where {$_.Name -like "VM*"} | Import-Module
Clear
#####################################################################################################################

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

#####################################################################################################################

Connect-CustomerVIServers

$Hosts = Get-VMHost

$Report = $Hosts |% {
	$MemoryUsage = [Math]::Round($_.MemoryUsageGB*100/$_.MemoryTotalGB,2)
	if ([Int]$MemoryUsage -gt 80){
		$Note = "Warning! Lack of CAPACITY"
	}
	Else{
		Clear-Variable Note
	}
	[PSCustomObject]@{
		vCenter = $_.Client.ConnectivityService.ServerAddress
		Cluster = $_.Parent
		Host = $_.Name
		CPU = [Math]::Round($_.CpuUsageMhz*100/$_.CpuTotalMhz,2)
		Memory = $MemoryUsage
		Note = $Note
	}
}

$Date = Get-Date -Format "hh:mm dd/MM"
$OutPath = "C:\ScheduledScripts\Capacity Management\Compute\Compute Report $Date.csv"
$Report = $Report | Sort vCenter, Cluster | Export-Csv "$OutPath" -NoTypeInformation 

If ($env:USERDOMAIN -match "IL2"){
	Send-MailMessage -To "dandrews@ukcloud.com" -From "nocapacitymanagement@fail.com" -Bcc "" -Subject "Host Thresholds $Date" -SmtpServer rly00001i2 -Body $Body -BodyAsHtml  -Attachments $OutPath
}
Else {
	Send-MailMessage -To "dandrews@ukcloud.com" -From "nocapacitymanagement@fail.com" -Bcc "" -Subject "Host Thresholds $Date" -SmtpServer 10.72.81.30 -Body "Please find the report on apw00029i3 at $OutPath" -BodyAsHtml 
}