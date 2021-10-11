#Add-PSSnapin vmware*

Get-Module -ListAvailable | Where-Object {$_.Name -like "CiscoUcsPS"} | ForEach-Object {import-module -name $_}
Get-Module -ListAvailable | Where-Object {$_.Name -like "VMware*"}  | ForEach-Object {import-module -name $_}

#Get-Module -ListAvailable | Where-Object {$_.Name -like "Cisco.UCS.Core" -or $_.Name -like "Cisco.UCSCentral" -or $_.Name -like "Cisco.UCSManager"} | ForEach-Object {import-module -name $_}

Set-UcsPowerToolConfiguration -SupportMultipleDefaultUcs $true
$UN = $env:USERNAME.trim("su")
If ($env:USERDOMAIN -like "*il2*")
{
$vCenterServers = @("vcv00004i2.pod00001.sys00001.il2management.local","vcv00005i2.pod00002.sys00002.il2management.local","vcw00001i2.il2management.local","vcw00002i2.il2management.local","vcw00003i2.il2management.local","vcw00004i2.il2management.local","vcw00005i2.il2management.local","vcw00007i2.il2management.local","vcw00008i2.il2management.local","vcw00009i2.il2management.local","vcw0000ai2.il2management.local")
#$vCenterServers = @("vcw00001i2.il2management.local") #,"vcw00004i2.il2management.local")

$unameS = "il2management\sciencelogicvcw"
$credsS = "As5^l2%j9^j1*u7*s9!"
	$userPasswordS = ConvertTo-SecureString "$credsS" -AsPlainText -Force
	$credentialsS = new-object -typename System.Management.Automation.PSCredential -argumentlist $unameS,$userPasswordS

$gDate = Get-Date -Format "dd-MM-yyyy"
#$outPath = "c:\Temp\ESXInventoryCheckPV1.5_$gDate.csv"
#$cred = Get-Credential
ForEach ($vCenterServer in $vCenterServers) {  
    Connect-VIServer -Server $vCenterServer -Credential $credentialsS | Out-Null
     
}
}
Else {

$vCenterServers = @("vcw00001i3.il3management.local","vcw00002i3.il3management.local","vcw00003i3.il3management.local","vcw00004i3.il3management.local","vcw00005i3.il3management.local","vcw00007i3.il3management.local","vcw00008i3.il3management.local")
#$vCenterServers = @("vcw00007i3.il3management.local")#,"vcw00001i3.il3management.local")
$gDate = Get-Date -Format "dd-MM-yyyy"
$unameS = "il3management\sciencelogicvcw"
$credsS = 'Sd4^l6$o9*z8^t7%r1!'
	$userPasswordS = ConvertTo-SecureString "$credsS" -AsPlainText -Force
	$credentialsS = new-object -typename System.Management.Automation.PSCredential -argumentlist $unameS,$userPasswordS
#$cred = Get-Credential
ForEach ($vCenterServer in $vCenterServers) {  
    Connect-VIServer -Server $vCenterServer -Credential $credentialsS #| Out-Null
     
}
}
$uname = "svc_sciencelogic"
$creds = "Yh6!o0r5u6x9w2"
	$userPassword = ConvertTo-SecureString "$creds" -AsPlainText -Force
	$credentials = new-object -typename System.Management.Automation.PSCredential -argumentlist $uname,$userPassword
$UN = $env:USERNAME.trim("su")
If ($env:USERDOMAIN -like "*il3*")
{
$ucsS = @("ucs00001i3","ucs00002i3")
}
Else{
$ucsS = @("ucs00001i2","ucs00002i2","ucs00003i2","ucs00004i2")
}
ForEach ($ucs in $ucsS) {  
    connect-ucs "$ucs" -Credential $credentials # | Out-Null
     
}

$GH = Get-View -ViewType HostSystem 
$report = @()
Foreach ($VMHost in $GH) {

		$VHost = $VMHost.Name.split(".")[0]
		$VHost
		$VC = $VMHost.Client.ServiceURL.trim("https://").Split(".")[0]

if ($VC -like "vcv*")

{$VCF = "$VC*"}

Else {
		$VCF = "$VC" + "." + $env:USERDNSDOMAIN
}
		$Cluster = Get-View -Id $VMHost.Parent -Server $VCF
	 #$sp1 = Get-UcsServiceProfile | Where-Object {$_.Name -like "$VHost*"} #| Get-UcsParent
	 $sp2 = Get-UcsServiceProfile  -Filter "Name -clike $VHost*"
	 
	  IF ([string]::IsNullOrWhitespace($sp2)){
	  Write-Host "Not UCS Blade"
	  	$server2 = "Not managed by UCS"
		$ucs2 = "N/A"
	  
	  }
	  Else{
	 #Get-UcsServiceProfile | Where-Object {$_.Name -like "esx000adi2*"}
	 #$VHost = "esx000adi2" #.il2management.local"
	 # Get-UcsServiceProfile -Filter "Name -clike $VHost*"
	 #Get-UcsServiceProfile -Filter "Name -clike esx000adi2*"
		#$sp1.name
		
		# Find the physical hardware the service profile is running on:
		#$server = $sp1.PnDn
		$server2 = $sp2.PnDn
		$ucs2 = $sp2.UCS
	}	
		$UDomain = $env:USERDNSDOMAIN
		#$UDomain
		$VU = $VMHost | Select-Object -Property @{name="ESX";expression={"<a href='https://sciencelogic.$UDomain/em7/index.em7?exec=registry&act=registry_device_management#devmgt_search.device=$($_.Name)' target='blank'>$($_.Name)</a>"}} #| ConvertTo-Html
		#$VU
		#$VUR = $VU.ESX
		#$VUR.Replace("&lt;","<").Replace("&gt;",">").Replace("&#39;","'")
		#$VU123 = $VU.Replace("&lt;","<").Replace("&gt;",">").Replace("&#39;","'")
			#$Table = Invoke-Expression $VU
			#$Table = $VU.Replace("&lt;","<").Replace("&gt;",">").Replace("&#39;","'")
		$obj = New-Object -typename System.Object
		$obj | Add-Member -MemberType noteProperty -Name ESXiHost -value $VU.ESX
		#$obj | Add-Member -MemberType noteProperty -name ESXiHost -value $VMHost.Name
		$obj | Add-Member -MemberType noteProperty -name Cluster -value $Cluster.Name
		$obj | Add-Member -MemberType noteProperty -name VC -value $VC
		#$obj | Add-Member -MemberType noteProperty -name Blade -value $server
		$obj | Add-Member -MemberType noteProperty -name Blade -value $server2
		#$obj | Add-Member -MemberType noteProperty -name UCS -value $sp1.Ucs
		$obj | Add-Member -MemberType noteProperty -name UCS -value $ucs2
		$obj | Add-Member -MemberType noteProperty -name Model -value $VMHost.Hardware.SystemInfo.Model
		$obj | Add-Member -MemberType noteProperty -name Vendor -value $VMHost.Hardware.SystemInfo.Vendor
		$report += $obj
 }
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
text-transform:uppercase;
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
text-transform:uppercase;
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
text-transform:uppercase;
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
 $OutputFile="C:\inetpub\wwwroot\BladeInventory.html" 
 $OutputFileCSV = "C:\inetpub\wwwroot\BladeInventory.csv"
 $OS = $report | sort VC,UCS,Blade,ESXIHOST  | ConvertTo-Html -Title "Test Title" -Head $HeadTest -Body "<div id='title'><center><h1>UCS Blades Inventory</h1></div><a href=BladeInventory.csv title=DownloadCSV>Download Data</a><div id='subtitle'><center><h1>Report generated: $DateSub</h1></div><br></center><center><h2>Blades per VC</h2></center>"   #</div><div id='subtitle'>Report generated: $DateSub</div>"
 $OS = $OS.Replace("&lt;","<").Replace("&gt;",">").Replace("&#39;","'")
 $OS | Out-File -FilePath $OutputFile -Force
 $report | sort VC,UCS,Blade,ESXIHOST | Export-Csv -path $OutputFileCSV -Force -NoTypeInformation
 
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
text-transform:uppercase;
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
text-transform:uppercase;
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
text-transform:uppercase;
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
Send-MailMessage -To "noc@ukcloud.com" -From "UCSInventoryIL2@ukcloud.com" -Subject "UCS Blades Inventory $gDate" -SmtpServer rly00001i2 -Body $HBody -BodyAsHtml  -Attachments $OutputFile,$OutputFileCSV #$outfile,$outfile1 
}
Else {
Send-MailMessage -To "noc@ukcloud.com" -From "UCSInventoryIL3@ukcloud.com" -Subject "UCS Blades Inventory $gDate" -SmtpServer 10.72.81.30 -Body $HBody -BodyAsHtml  -Attachments $OutputFile,$OutputFileCSV #-Attachments $outfile,$outfile1
}

 
 Disconnect-VIServer * -Confirm:$false
 
 Disconnect-Ucs