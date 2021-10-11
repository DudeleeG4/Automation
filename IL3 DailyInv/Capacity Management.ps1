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

Function ConnectSINTAPI($url)
{
	if($env:COMPUTERNAME -like "*I2*"){ 
		$auth_key= "d1e73d74b02e0a0b27232e5170c9f16c446578a3"
    }
	else{
		$auth_key= "2fa6ea567589aaef94ff8f841c021aa2c27bbc33"
	}
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $webRequest = [System.Net.WebRequest]::Create($url)
    $webRequest.ServicePoint.Expect100Continue = $false
    $webRequest.Method = "Get"
    $webRequest.Headers.Add("Authorization",$auth_key)
    $webRequest.Accept = "application/json"
    [System.Net.WebResponse]$resp = $webRequest.GetResponse()
    $rs = $resp.GetResponseStream()
    [System.IO.StreamReader]$sr = New-Object System.IO.StreamReader -argumentList $rs
    $results = $sr.ReadToEnd() | ConvertFrom-Json
    return $results 
}


Function GetcredentialsSint($inputs)
{	
	if($env:COMPUTERNAME -like "*I2*"){ 
		$url_il = "https://sint.il2management.local"
	}else{
		$url_il = "https://sint.il3management.local"
	}
    $hostname = $inputs[1]
    $passlabel = $inputs[0]
    $url = "$url_il/api/cmdb/search?hostname=$hostname"
    $pwd = ConnectSINTAPI($url)
    $url ="$url_il/api/ci/ci/"+$pwd.data.id+"/credentials"
    $pwds = ConnectSINTAPI($url)
    foreach($pwd in $pwds){
        $id = $pwd.label

        if ($id -match $passlabel)
        {
            $usr   = $pwd.username 
            $pwdId = $pwd.id 
        }  
    }
    $url = "$url_il/api/pwdb/credentials/$pwdId/password"
    $pwd = ConnectSINTAPI($url)
    return $usr,$pwd
}

#####################################################################################################################

$VcloudsUrls = connect_to_IAS_API | ConvertFrom-JSON
foreach($VcloudsUrl in $VcloudsUrls.data){

    ######### Get vCloud url from IAS #######
	$Vurl = $VcloudsUrl.attributes.uiUrl
	######### Get credential from SINT #############
	$args = New-Object System.Collections.Generic.List[System.Object]
    $hostname = $VcloudsUrl.attributes.name.Split('.')[0]
    $pwdlabel = "vCloud Monitoring Account"
    $args.Add($pwdlabel)
    $args.Add($hostname)
    $username,$password = GetcredentialsSint($args)

Connect-CustomerVIServers

$Hosts = Get-VMHost

$Report = $Hosts |% {
	$MemoryUsage = [Math]::Round($_.MemoryUsageGB*100/$_.MemoryTotalGB,2)
	if ([Int]$MemoryUsage -gt 80){
		$Note = "Warning! Lack of CAPACITY"
	}
	Elseif($Note){
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

$Date = Get-Date -Format "dd-MM HHmm"
$OutPath = "C:\ScheduledScripts\Capacity Management\Compute\Compute Report $Date.csv"
$Report = $Report | Sort vCenter, Cluster | Export-Csv "$OutPath" -NoTypeInformation 

If ($env:USERDOMAIN -match "IL2"){
	Send-MailMessage -To "dandrews@ukcloud.com" -From "nocapacitymanagement@fail.com" -Bcc "" -Subject "Host Thresholds $Date" -SmtpServer rly00001i2 -Body $Body -BodyAsHtml  -Attachments $OutPath
}
Else {
	Send-MailMessage -To "dandrews@ukcloud.com" -From "nocapacitymanagement@fail.com" -Bcc "" -Subject "Host Thresholds $Date" -SmtpServer 10.72.81.30 -Body "Please find the report on apw00029i3 at $OutPath" -BodyAsHtml 
}