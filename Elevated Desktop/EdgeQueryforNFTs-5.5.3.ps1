#### Import Modules
Import-Module C:\users\suvnayak\Documents\WindowsPowerShell\powernsx-master\module\PowerNSX.psm1
Get-Module -ListAvailable | Where-Object {$_.name -like "VMware*"}  | ForEach-Object {import-module -name $_}
Add-PSSnapin vmware*

#### Export Variables ####

$gDate = get-date -Format "dd-MM-yyyy"
$gDateFull = get-date
$DomainName = $env:userdomain.tolower()

$ExportCSV = "C:\temp\NSXOutput-New1-$gDate-$DomainName.csv"
$ExportTXT = "C:\temp\NSXOutput-New1-$gDate-$DomainName.txt"
$ExportError = "C:\temp\NSXOutput-New1-ErrorLog-$gDate-$DomainName.txt"


$ExportEdgeGateway = "C:\temp\NSXOutput-New1-EdgeGatewaySearchCloud-$gDate-$DomainName.csv"
$ExportEdgeGatewayOutput = "C:\temp\NSXOutput-New1-EdgeGatewayOutputArray-$gDate-$DomainName.csv"
#### Helper Function LOL kind of important...
#### VCD Database


#### Create TXT File with Start Date

"Script Started at $gDateFull" | out-file $ExportTXT -force
$vclouddetails = @()
$Username = "scheduledtaskuser"
$Password = 'Zj6@i4&l5&a4%i1&v7*'
$secpasswd = ConvertTo-SecureString $Password -AsPlainText -Force
$mycreds = New-Object System.Management.Automation.PSCredential ($Username, $secpasswd)
$vcloudOutput = @()
$allvcs = @()

Function Get-VCDQuery($server,$Query,$uid,$pwd) {
$sqlDBName = "vcloud"
$connection = New-Object system.Data.SqlClient.SqlConnection
$connection.ConnectionString = "Server = $server; Database = $SQLDBName; Integrated Security = True; User ID = $uid; Password = $pwd;"
$sqlcmd = New-Object system.Data.SqlClient.SqlCommand
$sqlcmd.CommandText = $Query
$sqlcmd.Connection = $connection
$sqladapter = New-Object system.Data.SqlClient.SqlDataAdapter
$sqladapter.SelectCommand = $sqlcmd
$dataset = New-Object system.Data.DataSet
$sqladapter.Fill($dataset)
$Connection.Close() #| Out-Null
$sqladapter.Dispose()# | Out-Null
$Connection.Dispose() #| Out-Null

Return $dataset.Tables[0]
}

$dbservers = @("dbs00019i2","dbs0000ci2","dbs0000di2","dbs0000ei2","dbs00022i2","dbs00027i2")
$vclouddbquery = @"
select value as vcloud_name from vcloud.dbo.config where name like 'restapi.baseUri'
"@


foreach($db in $dbservers) {

$dboutput = Get-VCDQuery -server $db -Query $vclouddbquery -uid $Username -pwd $Password
$myobject = New-Object System.Object
$myobject | Add-Member -MemberType NoteProperty -Name database -Value $db
$myobject | Add-Member -MemberType NoteProperty -Name vcloud_name -Value $dboutput.vcloud_name
$vclouddetails += $myobject
}


foreach($vcloud in $vclouddetails) {


$name = ($vcloud.vcloud_name.Split("/"))[2]
Disconnect-CIServer * -Confirm:$false
Connect-ciserver -server $name -user $Username -password $Password
$edgegateways = Search-Cloud -QueryType EdgeGateway # | where {$_.Name -like "*nft0006di2*"} # | where {$_.Name -like "*nft0006di2*"} #| select -First 10
$vcs = Search-Cloud -QueryType VirtualCenter
$allvcs +=$vcs
#$edgegateways | Export-Csv $ExportEdgeGateway -NoTypeInformation -Force 
$starttime = Get-Date


$num=0
Foreach ($Edge in $edgegateways) {

#Foreach ($Edge in $edgegateway) {

$num+=1
$howmanyleft= $edgegateways.count - $num 
Write-Host "I am currently exporting details for" $Edge.Name "with ID:" $Edge.Id
Write-Host "This is Edge number" $num "of" $edgegateways.count
Write-Host "This means we have" $howmanyleft "Edge(s) to go"


"I am currently exporting details for $($Edge.Name) with ID: $($Edge.Id)" | out-file $ExportTXT -Append
"This is Edge number $num of $($edgegateways.count)" | out-file $ExportTXT -Append
"This means we have $howmanyleft Edge(s) to go" | out-file $ExportTXT -Append


$Edgeview = $Edge | get-ciview
$Vdc = get-OrgVdc -Id ($Edge.PropertyList.Vdc) -ErrorAction SilentlyContinue

IF([string]::IsNullOrWhitespace($Vdc)){
$VDCNameExtract = (Search-Cloud -QueryType AdminOrgVdc -Filter "id==$($Edge.PropertyList.Vdc)" | Select-Object -ExpandProperty Name).replace("&","``&")
$Vdc = get-orgvdc -Name $VDCNameExtract
}
#else {'not empty'}

$webclient = New-Object system.net.webclient
$webclient.Headers.Add("x-vcloud-authorization",$Edgeview.Client.SessionKey)
$webclient.Headers.Add("accept",$EdgeView.Type + ";version=9.0")
[xml]$EGWConfXML = $webclient.DownloadString($EdgeView.href)

$vcenterid = "urn:vcloud:vimserver:"+$EGWConfXML.EdgeGateway.GatewayBackingRef.VCref.id
$vcenter = $vcs | where {$_.Id -like $vcenterid}

Foreach ($Interface in $EGWConfXML.EdgeGateway.Configuration.GatewayInterfaces.GatewayInterface) {
if ($Interface.UseForDefaultRoute -eq 'true') {$DefaultGateway = $Interface.SubnetParticipation.Gateway
}
}
 $n = [pscustomobject]@{
Name =  $Edge.Name
Description = $EGWConfXML.EdgeGateway.Description
EdgeBacking = $EGWConfXML.EdgeGateway.GatewayBackingRef.gatewayId
Interfaces = $EGWConfXML.EdgeGateway.Configuration.GatewayInterfaces.GatewayInterface
Firewall = $EGWConfXML.EdgeGateway.Configuration.EdgegatewayServiceConfiguration.FirewallService.IsEnabled
NAT = $EGWConfXML.EdgeGateway.Configuration.EdgegatewayServiceConfiguration.NatService.IsEnabled
LoadBalancer = $EGWConfXML.EdgeGateway.Configuration.EdgegatewayServiceConfiguration.LoadBalancerService.IsEnabled
DHCP = $EGWConfXML.EdgeGateway.Configuration.EdgegatewayServiceConfiguration.GatewayDHCPService.IsEnabled
VPN = $EGWConfXML.EdgeGateway.Configuration.EdgegatewayServiceConfiguration.GatewayIpsecVpnService.IsEnabled
Routing = $EGWConfXML.EdgeGateway.Configuration.EdgeGatewayServiceConfiguration.StaticRoutingService.IsEnabled
Syslog = $EGWConfXML.EdgeGateway.Configuration.SyslogServerSettings.TenantSyslogServerSettings.IsEnabled
Size = $EGWConfXML.EdgeGateway.Configuration.GatewayBackingConfig
HA = $EGWConfXML.EdgeGateway.Configuration.HaEnabled
DNSRelay = $EGWConfXML.EdgeGateway.Configuration.UseDefaultRouteForDnsRelay
AdvancedNetworking = $EGWConfXML.EdgeGateway.Configuration.AdvancedNetworkingEnabled
HAEnabled = $EGWConfXML.EdgeGateway.Configuration.HaEnabled
Org = $Vdc.Org.Name
TenantId = $Vdc.Org.Id.Split(':')[3]
OrgVDC = $Vdc.Name
OrgVDCId = $Vdc.Id.Split(':')[3]
ProviderVDC = $Vdc.ProviderVDC.Name
ProviderVDCId = $Vdc.ProviderVDC.Id.Split(':')[3]
#vcenter1 = ($vcenter.Url.Split("/"":"))[3]
vcenter = $vcenter.Name
vcloud = $name
database = $vcloud.database
DefaultGateway = $DefaultGateway


}
$vcloudOutput += $n
}
Disconnect-Ciserver $name -Confirm:$false
}
$vcloudOutput | Export-Csv C:\Scripts\vnayak\vcloudoutput.csv -NoTypeInformation -Force 
$endtime = Get-Date

########### Measure how long it took ############

$RWEQ = $endtime - $starttime
$MinutesT = $RWEQ | Select-Object -ExpandProperty TotalMinutes
$HoursH = $RWEQ | Select-Object -ExpandProperty TotalHours
$MT = [System.Math]::Round($MinutesT,2) 
$HT = [System.Math]::Round($HoursH,2)  


"Script started: $starttime"
"Script finished: $endtime"
"It took $MT Minutes and $HT Hours" 
##########
$vcnum=0
$nsxoutput = @()

#### Filter VC to only the ones we need  ####

$OnlyValidVCs = $vcloudOutput | Select-Object -ExpandProperty vcenter -Unique

$Filteredvcs = @()
ForEach ($vcname in $OnlyValidVCs)
{

$Filteredvcs += $allvcs |  Where-Object {$_.Name -match $vcname}
#$Filteredvcs
}



foreach($vc in $Filteredvcs){

if ($vc.Url -like '*pod*') {
$vcentername = ($vc.Url.Split("/"":"))[3]
}
else {
$vcentername = $vc.Name
}
$vcentername
#Connect-VIServer $vc.Name
#Connect-NsxServer -NsxServer $vc.VsmIP -Credential $pscred -DisableVIAutoConnect:$true
Connect-VIServer $vcentername -user $Username -password $Password
Connect-NsxServer -NsxServer  $vc.VsmIP -Credential $mycreds  -DisableVIAutoConnect:$true #-Username $Username -password $Password

$nsxedges = $vcloudOutput | Where-Object {$_.vcenter -like $vc.Name}
$vcnum+=1
$num=0
foreach($i in $nsxedges)
{
$num+=1
$howmanyleft= $nsxedges.count - $num
$homanyVCleft = $Filteredvcs.count - $vcnum
Write-Host "BTW I am doing VC:" $vc.Name
Write-Host "I am currently doing VC" $vcnum "out of:" $Filteredvcs.count
Write-Host "This means I have" $homanyVCleft "left to do"
Write-Host "I am currently exporting details for" $i.Name "with ID:" $i.EdgeBacking
Write-Host "This is Edge number" $num "of" $nsxedges.count
Write-Host "This means we have" $howmanyleft "Edge(s) to go"

"BTW I am doing VC: $($vc.name)" | out-file $ExportTXT -Append
"I am currently doing VC $vcnum out of: $($Filteredvcs.count)" | out-file $ExportTXT -Append
"This means I have $homanyVCleft left to do" | out-file $ExportTXT -Append
"I am currently exporting details for $($i.Name) with ID: $($i.EdgeBacking)" | out-file $ExportTXT -Append
"This is Edge number $num of $($nsxedges.count)" | out-file $ExportTXT -Append
"This means we have $howmanyleft Edge(s) to go" | out-file $ExportTXT -Append


$edgeName = $i.Name

$QDatabase = "SELECT g.name,aia.address,aia.last_modified,isc.gateway,isc.netmask
FROM [vcloud].[dbo].[gateway] as g
left outer join vcloud.dbo.gateway_interface as gi on gi.gateway_id=g.id
left outer join vcloud.dbo.gateway_assigned_ip as ga on ga.gateway_interface_id=gi.id
left outer join vcloud.dbo.allocated_ip_address as aia on aia.id=ga.allocated_ip_address_id
left outer join vcloud.dbo.ip_scope as isc on isc.id=aia.scope_id
where g.name like '$edgeName' and gi.name like 'vnic0' and ga.network_resource_category = 4 
order by last_modified desc"
 
$EdgeDBQuery= Get-VCDQuery -Query $QDatabase -server $vcloud.database -uid $Username -pwd $Password 
$EdgeDBQuery.

$HowMAnyIPs = $EdgeDBQuery | select -ExpandProperty address 
If ($HowMAnyIPs.count -gt 1)
{
$RedeployIP= $EdgeDBQuery[0] | select -ExpandProperty address
}
Else{
$RedeployIP = "SingleIP"
}



$nsxedge = Get-NsxEdge -objectId $i.EdgeBacking

### Find Edge Version from VC ###


 $Pattern = $nsxedge.Name -replace "\(","\(" -replace "\)","\)"
$GetVersionEdge =   Get-View -ViewType virtualmachine -Property Name,Config -Filter @{'Config.VAppConfig.Product[0].Name'='vShield Edge';'Name'="$Pattern"} -Server $vcentername
$GetVersionEdge.Name
$nsxedge.Name
$nsxedge.ID
$VersionfromVC = $GetVersionEdge.config.vappconfig.product[0].version
$VersionfromVCTrimmed = $VersionfromVC -replace "-.*" 
If ($VersionfromVCTrimmed -ne $nsxedge.edgeSummary.appliancesSummary.vmVersion)
{
$VersionMismatch = "Mismatch"
$VersionMismatch
}
Else{
$VersionMismatch = "Good"
$VersionMismatch
}
###



 $m = [pscustomobject]@{
Name = $i.Name
Description = $i.Description
EdgeBacking = $i.EdgeBacking
Firewall = $i.Firewall
NAT = $i.NAT
LoadBalancer = $i.LoadBalancer
DHCP = $i.DHCP
VPN = $i.VPN
Routing = $i.Routing
Syslog = $i.Syslog
Size = $i.Size
HA = $i.HA
DNSRelay = $i.DNSRelay
AdvancedNetworking = $i.AdvancedNetworking
HAEnabled = $i.HAEnabled
Org = $i.Org
TenantId = $i.TenantId
OrgVDC = $i.OrgVDC
OrgVDCId = $i.OrgVDCId
ProviderVDC = $i.ProviderVDC
ProviderVDCId = $i.ProviderVDCId
vcenter = $i.vcenter
vcloud = $i.vcloud
applianceversion = $nsxedge.edgeSummary.appliancesSummary.vmVersion
VersionFromVC = $VersionfromVC
VersionMismatch = $VersionMismatch
applianceversionBuildInfo = $nsxedge.edgeSummary.appliancesSummary.vmBuildInfo
appliancesize = $nsxedge.edgeSummary.appliancesSummary.applianceSize
nsxFirewall = $nsxedge.features.firewall.enabled
nsxNAT = $nsxedge.features.nat.enabled
nsxLoadBalancer = $nsxedge.features.loadBalancer.enabled
nsxDHCP = $nsxedge.features.dhcp.enabled
nsxipsecVPN = $nsxedge.features.ipsec.enabled
nsxsslvpn = $nsxedge.features.sslvpnConfig.enabled
nsxRouting = $nsxedge.features.routing.enabled
nsxSyslog = $nsxedge.features.syslog.enabled
nsxHA = $nsxedge.features.highAvailability.enabled
nsxDNSRelay = $nsxedge.features.highAvailability.enabled
RedeployIP = $RedeployIP
}
$nsxoutput += $m
 
}
Disconnect-VIServer $vcentername -Confirm:$false
Disconnect-NsxServer
}




########### Export all the information to CSV ###########

$nsxoutput | Export-Csv  $ExportCSV -NoTypeInformation -Force
#$nsxoutput | export-csv C:\Scripts\vnayak\output.csv

########### Measure how long it took in total ############


$gDateFullEnd = get-date

$HowLongTotal = $gDateFullEnd - $gDateFull
$MinutesTotal = $HowLongTotal | Select-Object -ExpandProperty TotalMinutes
$HoursTotal = $HowLongTotal | Select-Object -ExpandProperty TotalHours
$MTotal = [System.Math]::Round($MinutesTotal,2) 
$HTotal = [System.Math]::Round($HoursTotal,2)  

"Script started: $gDateFull"
"Script finished: $gDateFullEnd"
"It took $MTotal Minutes and $HTotal Hours" 

"Script Started at $gDateFull" | out-file $ExportTXT -Append
"Script Ended at $gDateFullEnd" | out-file $ExportTXT -Append
"It took $MTotal Minutes and $HTotal Hours" | out-file $ExportTXT -Append

######### Export Errors ############

$error | Out-file -FilePath $ExportError -Force


$recs = "cblack@ukcloud.com","vnayak@ukcloud.com","dbroderick@ukcloud.com","molejar@ukcloud.com","tlofthouse@ukcloud.com"
$gDate = get-date -Format dd-MM-yyyy
$UN = $env:USERNAME.trim("su")
If ($env:USERDOMAIN -like "*il2*")
{
Send-MailMessage -To $recs -From "EdgeNFTInventoryIL2@ukcloud.com" -Subject "Edge NFT Inventory IL2 $gDate" -SmtpServer rly00001i2 -Attachments $ExportCSV #$outfile,$outfile1 
}
Else {
Send-MailMessage -To "noc@ukcloud.com" -From "UCSInvnetoryIL3@ukcloud.com" -Subject "UCS Blades Inventory $gDate" -SmtpServer 10.72.81.30 -Body $HBody -BodyAsHtml  -Attachments $OutputFile,$OutputFileCSV #-Attachments $outfile,$outfile1
}
