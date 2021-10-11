Clear

Get-Module -ListAvailable | Where {$_.Name -like "vm*"} | Import-Module

$date = Get-Date -Format "dd-MM-yyyy"
$outpath = "C:\ScheduledScripts\PvDC Health Checks\PvDC-Health-$Date.csv"
$Report = $null
$Report = @()
$Progress = 0

################ Alert in SL using API #######################
function SLAPI($text)
{
    if($env:COMPUTERNAME -like "*I2*"){
     
    	$url = "https://sciencelogic.il2management.local/api/alert"
        $user = "em7admin"
        $pass=  "Ia4a6s1p2a2q7"
	}else{

		$url = "https://sciencelogic.il3management.local/api/alert"
        $user = "em7admin"
        $pass=  "Ng4z1x9t4z2g5"
	}

    $json = "{""force_ytype"":""0"",
            ""force_yid"":""0"",""force_yname"":""1"",
            ""message"": ""$text"",""value"":"""",""threshold"":""0"",
            ""message_time"":""0"",
            ""aligned_resource"":""/device/1492""}"
    $json         
    $secpasswd = ConvertTo-SecureString -String $pass -AsPlainText -Force
    $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, $secpasswd
    #[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true} (This one liner will ignore SSL certificate error)
    $r = Invoke-RestMethod -Uri $url -Method Post -Credential $cred -Body $json -ContentType 'application/json'
     
}

###############  Get Vcloud Directors URLs using IAS API ###########################
Function connect_to_IAS_API 
{
	if($env:COMPUTERNAME -like "*I2*"){ 
    	$url = 'http://10.8.81.45/vendors'
	}else{
		$url = 'http://10.72.81.42/vendors'
	}
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $webRequest = [System.Net.WebRequest]::Create($url)
    $webRequest.ContentType = "application/vnd.api+json"
    $webRequest.ServicePoint.Expect100Continue = $false
    $webRequest.Method = "Get"
    [System.Net.WebResponse]$resp = $webRequest.GetResponse()
    $rs = $resp.GetResponseStream()
    [System.IO.StreamReader]$sr = New-Object System.IO.StreamReader -argumentList $rs
    [string]$results = $sr.ReadToEnd()
    return $results
}
############## Get usernames and passwords from SINT ################################

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
    ######### Connect to Vcloud Director #######
    if ($username -and $password)
	{
		Connect-ciserver -server $Vurl -user $username -password $password
        $Progress += 1
	    Write-Progress -Activity "Gathering PvDC Data" -PercentComplete ($Progress/$VcloudsUrls.Data.Count*100)
        $PvDCs = Get-ProviderVdc | Where {$_.Name -notmatch "DeC"} | Where {$_.Name -notmatch "hadoop"}

        foreach ($PvDC in $PvDCs)
        {
	        
	        $StorageTotal = 0
			$StorageUsed = 0
	        $storageProfiles = $pvdc.ExtensionData.StorageProfiles.ProviderVdcStorageProfile
	        foreach ($p in $storageProfiles) 
	        {
		        $profile = Get-CIView -Id $p.Href
		        $StorageTotal += $PROFILE.CapacityTotal
		        $StorageUsed += $PROFILE.CapacityUsed
	        }
	        $vCloudName = $PvDC.Client.ConnectivityService.ServiceUri -split {$_ -eq "/" -or $_ -eq ":"} | Select -Index 3
	
	        $info = "" | Select vCloud, PvDC, ProcessorUsed, MemoryUsed, StorageUsed
	        $info.vCloud = $vCloudName
	        $info.PvDC = $PvDC.Name -split "\." | Select -First 1
	        $info.ProcessorUsed = [Math]::Round(($PvDC.CpuUsedGHz/$PvDC.CpuTotalGHz)*100,2)
	        $info.MemoryUsed = [Math]::Round(($PvDC.MemoryUsedGB/$PvDC.MemoryTotalGB)*100,2)
	        $info.StorageUsed = [Math]::Round(($StorageUsed/$StorageTotal)*100,2)
            
	        $Report += $info
           
        }
    Disconnect-CIServer * -Confirm:$False       
    }

}

foreach ($item in $report)
{
    if ($item.ProcessorUsed -gt 75 -or $item.MemoryUsed -gt 75 -or $item.StorageUsed -gt 75)
    {
        $Message = "PvDC Health Check error, Please check the latest report at C:\\ScheduledScripts\\PvDC Health Checks on the Task Scheduler"
        SLAPI($message)
    }
}
$Report | Sort "vCloud", "PvDC" | Export-Csv $OutPath -NoTypeInformation