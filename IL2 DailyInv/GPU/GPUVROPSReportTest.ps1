### https://10.40.16.160/suite-api/docs/rest/index.html#getRelationship





#### Connect to vROps

function Ignore-SelfSignedCerts {
    add-type -TypeDefinition  @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
        public class TrustAllCertsPolicy : ICertificatePolicy {
            public bool CheckValidationResult(
                ServicePoint srvPoint, X509Certificate certificate,
                WebRequest request, int certificateProblem) {
                return true;
            }
        }
"@
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
}#function
Ignore-SelfSignedCerts
 

$Username = "schedTaskUser@il2management.local"
$Password = "Zj6@i4&l5&a4%i1&v7*"
$vROPSServers = @("10.40.16.160","10.40.48.160")

#### Export Variables ####

$gDate = get-date -Format "dd-MM-yyyy"
$gDateFull = get-date
$DomainName = $env:userdomain.tolower()

$ExportCSV = "C:\temp\vROpsGPUReport-$gDate-$DomainName.csv"

$FullArrayReport = @()

$VMsCount = @()
ForEach ($vROPSServer in $vROPSServers) {  

#Get epoch date
$Epoch = [decimal]::Round((New-TimeSpan -Start (get-date -date "01/01/1970") -End (get-date).ToUniversalTime()).TotalMilliseconds)
$auth = $Username + ':' + $Password
$Encoded = [System.Text.Encoding]::UTF8.GetBytes($auth)
$EncodedPassword = [System.Convert]::ToBase64String($Encoded)
$headers = @{"Authorization"="Basic $($EncodedPassword)";}
$TotalCount = "50000"






#### Get All Resources 

[xml]$AAA = Invoke-webrequest -uri "https://$vROPSServer/suite-api/api/resources?pageSize=$TotalCount" -Headers $headers -contenttype "application/xml" #-Method post


#### Filter All Resources


$GPUStuff = $AAA.resources.resource | Where {$_.ResourceKey.AdapterKindKey -like "NVIDIA_VGPU" -and  $_.ResourceKey.resourceKindKey -like "gpu" }

#### Create Report
$GReport = @()

ForEach ($GPU in $GPUStuff)

{
$GPUID = $GPU.Identifier
[xml]$HostGPURelation = Invoke-webrequest -uri "https://$vROPSServer/suite-api/api/resources/$GPUID/relationships/parents" -Headers $headers -contenttype "application/xml" #-Method post
[xml]$GPUStats = Invoke-webrequest -uri "https://$vROPSServer/suite-api/api/resources/$GPUID/stats/latest" -Headers $headers -contenttype "application/xml" #-Method post
[xml]$GPUChildren = Invoke-webrequest -uri "https://$vROPSServer/suite-api/api/resources/$GPUID/relationships/children" -Headers $headers -contenttype "application/xml" #-Method post
[xml]$GPUProperties = Invoke-webrequest -uri "https://$vROPSServer/suite-api/api/resources/$GPUID/properties" -Headers $headers -contenttype "application/xml" #-Method post
$HostID = $HostGPURelation."resource-relation".resource.identifier
[xml]$HostProperties = Invoke-webrequest -uri "https://$vROPSServer/suite-api/api/resources/$HostID/properties" -Headers $headers -contenttype "application/xml" #-Method post
[xml]$HostStats = Invoke-webrequest -uri "https://$vROPSServer/suite-api/api/resources/$HostID/stats/latest" -Headers $headers -contenttype "application/xml" #-Method post
$GPUStatsArray = $GPUStats."stats-of-resources"."stats-of-resource"."stat-list".stat  | select @{N='Key';E ={ ($_.statKey.Key )}},@{N='StatValue';E ={ ($_.Data )}}
$VMsCount += ($GPUChildren."resource-relation".resource.resourceKey.Name).count


$GPUReport = [pscustomobject]@{

HostName = $HostGPURelation."resource-relation".resource.resourceKey.Name
Cluster = ($HostProperties."resource-property".property |  Where-Object {$_.Name -like "summary|parentCluster"}).InnerText
VC = ($HostProperties."resource-property".property |  Where-Object {$_.Name -like "summary|parentVcenter"}).InnerText
Datacenter = ($HostProperties."resource-property".property |  Where-Object {$_.Name -like "summary|parentDatacenter"}).InnerText
HostServiceTag = ($HostProperties."resource-property".property |  Where-Object {$_.Name -like "hardware|serviceTag"}).InnerText
ServerType = ($HostProperties."resource-property".property |  Where-Object {$_.Name -like "hardware|vendorModel"}).InnerText


GPUID = $GPU.Identifier
GPUName = $GPU.resourceKey.Name
GPUType = ($GPUProperties."resource-property".property | Where-Object {$_.Name -like "summary|name"}).InnerText
GPUSerialNo = ($GPUProperties."resource-property".property | Where-Object {$_.Name -like "summary|serial"}).InnerText 
GPUMemorySizeMB = ($GPUProperties."resource-property".property | Where-Object {$_.Name -like "summary|fb_size"}).InnerText
GPUDrivers = ($GPUProperties."resource-property".property | Where-Object {$_.Name -like "summary|driver_version"}).InnerText
GPUCreateableProfiles = ($GPUProperties."resource-property".property | Where-Object {$_.Name -like "vgpu_Info|creatable_vgpu_types"}).InnerText
GPUAvailableProfiles = ($GPUProperties."resource-property".property | Where-Object {$_.Name -like "vgpu_info|supported_vgpu_types"}).InnerText
GPUApproachingShutdown = ($GPUProperties."resource-property".property | Where-Object {$_.Name -like "temperature|temperature_approaching_shutdown"}).InnerText
GPUChildren = $GPUChildren."resource-relation".resource.resourceKey.Name -join ","
VMCount = ($GPUChildren."resource-relation".resource.resourceKey.Name).count

GPUActiveAlarms = ($GPUStatsArray | Where-Object {$_.Key -like "System Attributes|active_alarms"}).StatValue
GPUActiveAlarmsInfo = ($GPUStatsArray | Where-Object {$_.Key -like "System Attributes|alert_count_info"}).StatValue
GPUNewAlarms = ($GPUStatsArray | Where-Object {$_.Key -like "System Attributes|new_alarms"}).StatValue
GPUTotalAlarms = ($GPUStatsArray | Where-Object {$_.Key -like "System Attributes|total_alarms"}).StatValue
GPUHealthStatus = ($GPUStatsArray | Where-Object {$_.Key -like "System Attributes|health"}).StatValue
GPUMemoryUtilisation = ($GPUStatsArray | Where-Object {$_.Key -like "utilization|memory_utilization"}).StatValue
GPUCurrentTemperature = ($GPUStatsArray | Where-Object {$_.Key -like "temperature|current_temperature"}).StatValue
}

$ChildrenArray = @()
$ParentsArray = @()

ForEach ($GpuChild in $GPUChildren."resource-relation".resource.identifier)
{
$GpuChildId = $GpuChild
[xml]$GPUVMProperties = Invoke-webrequest -uri "https://$vROPSServer/suite-api/api/resources/$GpuChildId/properties" -Headers $headers -contenttype "application/xml" #-Method post
[xml]$GPUVMParents = Invoke-webrequest -uri "https://$vROPSServer/suite-api/api/resources/$GpuChildId/relationships/parents" -Headers $headers -contenttype "application/xml" #-Method post
$ParentsId = ($GPUVMParents."resource-relation".resource | Where-Object {$_.resourcekey.adapterKindKey -like "VMWARE" -and $_.resourcekey.resourceKindKey -like "VirtualMachine"}).identifier
[xml]$GPUVMParentsProperties = Invoke-webrequest -uri "https://$vROPSServer/suite-api/api/resources/$ParentsId/properties" -Headers $headers -contenttype "application/xml" #-Method post

$ParentsArray += $GPUVMParentsProperties
$ChildrenArray += $GPUVMProperties
}

$i = 0
ForEach ($VMProp in ($ChildrenArray | Where-Object {$_."resource-property".property.Name -like "vm_info|vm_name" -or $_."resource-property".property.Name -like "summary|license_status" -or $_."resource-property".property.Name -like "summary|name" -or $_."resource-property".property.Name -like "summary|total_Fb_memory"  }))
{
$CloudDetails = ($GPUVMParentsProperties."resource-property".property | Where-Object {$_.Name -like "summary|folder"}).InnerText -split ","

$GPUReport | Add-Member -Name VMName${i} -Value ($VMProp."resource-property".property | Where-Object {$_.Name -like "vm_info|vm_name"}).InnerText -MemberType NoteProperty
$GPUReport | Add-Member -Name Licence${i} -Value ($VMProp."resource-property".property | Where-Object {$_.Name -like "summary|license_status"}).InnerText -MemberType NoteProperty
$GPUReport | Add-Member -Name GPUProfile${i} -Value ($VMProp."resource-property".property | Where-Object {$_.Name -like "summary|name"}).InnerText -MemberType NoteProperty
$GPUReport | Add-Member -Name GPUMemory${i} -Value ($VMProp."resource-property".property | Where-Object {$_.Name -like "summary|total_Fb_memory"}).InnerText -MemberType NoteProperty
$GPUReport | Add-Member -Name GuestDrivers${i} -Value ($VMProp."resource-property".property | Where-Object {$_.Name -like "vm_info|guest_driver_version"}).InnerText -MemberType NoteProperty

$GPUReport | Add-Member -Name Org${i} -Value $CloudDetails[1] -MemberType NoteProperty
$GPUReport | Add-Member -Name OrgVDC${i} -Value $CloudDetails[2] -MemberType NoteProperty
$GPUReport | Add-Member -Name vApp${i} -Value $CloudDetails[3] -MemberType NoteProperty
$GPUReport | Add-Member -Name HardwareVersion${i} -Value ($GPUVMParentsProperties."resource-property".property | Where-Object {$_.Name -like "config|version"}).InnerText  -MemberType NoteProperty
$GPUReport | Add-Member -Name Datastore${i} -Value ($GPUVMParentsProperties."resource-property".property | Where-Object {$_.Name -like "summary|datastore"}).InnerText  -MemberType NoteProperty
$GPUReport | Add-Member -Name VMToolsStatus${i} -Value ($GPUVMParentsProperties."resource-property".property | Where-Object {$_.Name -like "summary|guest|toolsRunningStatus"}).InnerText  -MemberType NoteProperty
$GPUReport | Add-Member -Name VMToolsVersion${i} -Value ($GPUVMParentsProperties."resource-property".property | Where-Object {$_.Name -like "summary|guest|toolsVersion"}).InnerText  -MemberType NoteProperty
$GPUReport | Add-Member -Name PowerState${i} -Value ($GPUVMParentsProperties."resource-property".property | Where-Object {$_.Name -like "summary|runtime|powerState"}).InnerText  -MemberType NoteProperty
$GPUReport | Add-Member -Name OS${i} -Value ($GPUVMParentsProperties."resource-property".property | Where-Object {$_.Name -like "summary|guest|fullName"}).InnerText  -MemberType NoteProperty
$i++
}

$GReport += $GPUReport 
}

#### Export the report

$SortedR = $GReport | sort -Property VMCount -Descending #| Sort-Object -Property VMCount,VC,Cluster,HostName,GPUType,ProfileActive,MemoryGB,GPUCreateableProfiles -Descending #| Export-Csv -Path $ExportCSV -NoTypeInformation -Append -Force
$global:SumTotalVMs = [math]::Round(($VMsCount  | Measure-Object -Sum).sum,2)

$FullArrayReport += $SortedR | sort -Property VMCount,VC -Descending #| Sort-Object -Property VMCount,VC,Cluster,HostName,GPUType,ProfileActive,MemoryGB,GPUCreateableProfiles -Descending
################################ End of Report
}

$report = @()
$report += $FullArrayReport 

 $report
 $HeadTest = @"
<style>
body
{
font-family: 'Open Sans';
line-height:20px;
color:#777777;
}
h1
{
margin-top:15px;
font-size:22px;
text-align:center;
padding-top:10px;
padding-bottom:10px;
background-color:#9acd32;
color:white;
padding-left:5px;
font-weight:normal;
#text-transform:uppercase;
}
h2
{
font-size:18px;
text-align:left;
padding-top:5px;
padding-bottom:4px;
padding-left:5px;
color:#777777;
font-weight:normal;
#text-transform:uppercase;
}
a
{
    text-decoration: none !important;
}
table
{
font-family:'Open Sans';
width:100%;
border-collapse:collapse;
}
table td, th 
{
font-size:16px;
font-weight:normal;
border:1px solid #dddddd;
padding:5px;
line-height:20px;
}
table th 
{
#text-transform:uppercase;
font-weight:normal;
text-align:left;
padding-top:5px;
padding-bottom:4px;
background-color:#2589CD;
color:#fff;
}
table tr.odd td 
{
color:#000;
background-color:#909DE5;
}
.tdprojectname
{
width:500px;
}
.thname
{
width:780px;
}
.spacer
{
background-color:green;
width:20px;
height:20px;
float:left;
}
.summarytable td
{
vertical-align:top;
border:none;
}
.summarytable td table td
{
border: 1px solid #dddddd;
vertical-align:middle;
}
.redcell
{
background-color:#fd570a;
}

header table td
{
	line-height:40px;
	font-size:30px;
}
</style>
"@
 $DateSub = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
 $OutputFile="C:\inetpub\wwwroot\GPUvROpsInventory.html" 
 $OutputFileCSV = "C:\inetpub\wwwroot\GPUvROpsInventory.csv"
 $OS = $report | sort -Property VC  | sort -property VMCount -Descending  | ConvertTo-Html -Title "Test Title" -Head $HeadTest -Body "<div id='title'><center><h1>GPU Enabled Hosts Inventory from vROps</h1></div><a href=GPUvROpsInventory.csv title=DownloadCSV>Download Data</a><div id='subtitle'><center><h1>Report generated: $DateSub</h1></div><br></center><center><h2>Total Count of GPU Enabled VMs = $SumTotalVMs</h2></center><center><h2>Hosts per vROps</h2></center><br><center>"   #</div><div id='subtitle'>Report generated: $DateSub</div>"
 $OS = $OS.Replace("&lt;","<").Replace("&gt;",">").Replace("&#39;","'")
 $OS | Out-File -FilePath $OutputFile -Force
 $report | sort -Property VC  | sort -property VMCount -Descending  | Export-Csv -path $OutputFileCSV -Force -NoTypeInformation
 
#$HBody = "<table><div id='title'></div>"
#$HBody += "<tr><td><div>$OS$htmlheader</div></td></tr></table>"
#$OS
$HBody = @"
<head>
<style>
body
{
font-family: 'Open Sans';
line-height:20px;
color:#777777;
}
h1
{
margin-top:15px;
font-size:22px;
text-align:center;
padding-top:10px;
padding-bottom:10px;
background-color:#9acd32;
color:white;
padding-left:5px;
font-weight:normal;
#text-transform:uppercase;
}
h2
{
font-size:18px;
text-align:left;
padding-top:5px;
padding-bottom:4px;
padding-left:5px;
color:#777777;
font-weight:normal;
#text-transform:uppercase;
}
a
{
    text-decoration: none !important;
}
table
{
font-family:'Open Sans';
width:100%;
border-collapse:collapse;
}
table td, th 
{
font-size:16px;
font-weight:normal;
border:1px solid #dddddd;
padding:5px;
line-height:20px;
}
table th 
{
#text-transform:uppercase;
font-weight:normal;
text-align:left;
padding-top:5px;
padding-bottom:4px;
background-color:#2589CD;
color:#fff;
}
table tr.odd td 
{
color:#000;
background-color:#909DE5;
}
.tdprojectname
{
width:500px;
}
.thname
{
width:780px;
}
.spacer
{
background-color:green;
width:20px;
height:20px;
float:left;
}
.summarytable td
{
vertical-align:top;
border:none;
}
.summarytable td table td
{
border: 1px solid #dddddd;
vertical-align:middle;
}
.redcell
{
background-color:#fd570a;
}

header table td
{
	line-height:40px;
	font-size:30px;
}
</style>
</head>
$OS
"@


$gDate = get-date -Format dd-MM-yyyy
$UN = $env:USERNAME.trim("su")
If ($env:USERDOMAIN -like "*il2*")
{
Send-MailMessage -To "cblack@ukcloud.com" -From "GPUvROpsInventory@ukcloud.com" -Subject "GPU Enabled Hosts Inventory from vROps $gDate" -SmtpServer rly00001i2 -Body $HBody -BodyAsHtml  -Attachments $OutputFile,$OutputFileCSV #$outfile,$outfile1 
}
Else {
Send-MailMessage -To "cblack@ukcloud.com" -From "GPUvROpsInventory@ukcloud.com" -Subject "GPU Enabled Hosts Inventory from vROps $gDate" -SmtpServer 10.72.81.30 -Body $HBody -BodyAsHtml  -Attachments $OutputFile,$OutputFileCSV #-Attachments $outfile,$outfile1
}
