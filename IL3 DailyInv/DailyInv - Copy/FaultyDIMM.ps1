Add-PSSnapin vmware*

Get-Module -ListAvailable | Where-Object {$_.Name -like "CiscoUcsPS"} | ForEach-Object {import-module -name $_}
#Get-Module -ListAvailable | Where-Object {$_.Name -like "VMware*"}  | ForEach-Object {import-module -name $_}

#Get-Module -ListAvailable | Where-Object {$_.Name -like "Cisco.UCS.Core" -or $_.Name -like "Cisco.UCSCentral" -or $_.Name -like "Cisco.UCSManager"} | ForEach-Object {import-module -name $_}
Set-UcsPowerToolConfiguration -SupportMultipleDefaultUcs $true
$UN = $env:USERNAME.trim("su")
If ($env:USERDOMAIN -like "*il2*")
{
$vCenterServers = @("vcv00004i2.pod00001.sys00001.il2management.local","vcv00005i2.pod00002.sys00002.il2management.local","vcw00001i2.il2management.local","vcw00002i2.il2management.local","vcw00003i2.il2management.local","vcw00004i2.il2management.local","vcw00005i2.il2management.local","vcw00007i2.il2management.local","vcw00008i2.il2management.local","vcw00009i2.il2management.local","vcw0000ai2.il2management.local")
#$vCenterServers = @("vcw00001i2.il2management.local","vcw00004i2.il2management.local")

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
#	`$( "td:contains('inoperable')" ).text('Warning'); //Replace text 'yellow' with 'Warning'
#	`$( "td:contains('disabled')" ).text('Alert'); //Replace text 'red' with 'Alert'
$htmlheader = @"
<script src="http://ajax.googleapis.com/ajax/libs/jquery/1.8.2/jquery.min.js"></script>
<script type="text/javascript">
`$(document).ready(function(){
  `$( "td:contains('inoperable')" ).css('background-color', '#FDF099'); //If yellow alarm triggered set cell background color to yellow
	`$( "td:contains('disabled')" ).css('background-color', '#FCC' ); //If yellow alarm triggered set cell background color to red
});
</script>
		
"@
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

$DateSub = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
$OutputFile="C:\inetpub\wwwroot\DIMMReport.html" 
$OutputFileCSV = "C:\inetpub\wwwroot\DIMMReport.csv"
$ccc = Get-UcsFault | Where-Object {$_.Severity -like "critical" -or $_.Severity -like "major" -or $_.Severity -like "minor" -and $_.Descr -like "*DIMM*"} | Sort-Object UCS,Created,Severity,Descr | Select-Object -Property Ucs,Severity,Occur,DN,Descr,Created,LastTransition,Code,Cause
#$ccc.UCS
#$cH = $ccc | ConvertTo-Html -Title "Test Title" -Head "<div id='title'><center><b>UCS Health Check</b></div><div id='subtitle'><center>Report generated: $DateSub</div><br></center><div id='title'><center><b>Memory faults for UCS</b></center>$htmlheader"#</div><div id='subtitle'>Report generated: $DateSub</div>"
#$cH | Out-File -FilePath $OutputFile -Force

$report =@()
ForEach ($c in $ccc)

{
#$c.UCS
#$c.dn.split("/")
$BladeLoc = $c.dn.split("/")
$BladeN = $BladeLoc[0]  + "/" + $BladeLoc[1] + "/" + $BladeLoc[2]
$BladeN
$UCSN = $c.UCS
$UCSN
#$BladeObj = Get-UcsServiceProfile | Where-Object {$_.PnDn -like "$BladeN" -and $_.UCS -like $c.Ucs}
$BladeObj = Get-UcsServiceProfile -Ucs $UCSN -Filter "PnDn -clike $BladeN*" #| Where-Object {$_.PnDn -like "$BladeN" -and $_.UCS -like $UCSN}
$BladeObj | select ucs,name | FT
$BSearch = $BladeObj.Name
#$BSearch = "esx001b0i2"
#$BSearch = "esx001b0i2"
#$BSearch = "esx001bai2"
if ($BSearch -like $null)
{
Write-Host "Null"
$VC = "N/A"
$ClusterN = "N/A"
$VMHostN = "Does not have a Service Profile"
}
Else{
Write-Host "Full"

 $VMHost = Get-View -ViewType HostSystem -Filter @{"name"="$BSearch"}
 #$VMHost
 IF ([string]::IsNullOrWhitespace($VMHost))
{
Write-Host "No Host"

$VMHostN = "Host not in any VC"
$ClusterN = "N/A"
$VC = "N/A"
}
Else{
		
		$VHost = $VMHost.Name.split(".")[0]
		$VHost
		$VMHostN = $VMHost.Name
		$VC = $VMHost.Client.ServiceURL.trim("https://").Split(".")[0]
		$VCF = "$VC" + "." + $env:USERDNSDOMAIN
		$Cluster = Get-View -Id $VMHost.Parent -Server $VCF
		$ClusterN = $Cluster.Name
		}
}

	# $sp1 = Get-UcsServiceProfile | Where-Object {$_.Name -like "$VHost*"} #| Get-UcsParent
		#$sp1.name
		
		# Find the physical hardware the service profile is running on:
		#$server = $sp1.PnDn

#Ucs,Severity,Occur,DN,Descr,Created,LastTransition,Code,Cause

		$obj = New-Object -typename System.Object
		$obj | Add-Member -MemberType noteProperty -name ESXiHost -value $VMHostN
		$obj | Add-Member -MemberType noteProperty -name Cluster -value $ClusterN
		$obj | Add-Member -MemberType noteProperty -name VC -value $VC
		#$obj | Add-Member -MemberType noteProperty -name Blade -value $server
		#$obj | Add-Member -MemberType noteProperty -name UCS -value $sp1.Ucs
		$obj | Add-Member -MemberType noteProperty -name DN -value $c.DN
		$obj | Add-Member -MemberType noteProperty -name UCS -value $c.Ucs
		$obj | Add-Member -MemberType noteProperty -name Severity -value $c.Severity
		$obj | Add-Member -MemberType noteProperty -name Occur -value $c.Occur
		$obj | Add-Member -MemberType noteProperty -name Descr -value $c.Descr
		$obj | Add-Member -MemberType noteProperty -name Created -value $c.created
		$obj | Add-Member -MemberType noteProperty -name LastTransition -value $c.LastTransition
		$obj | Add-Member -MemberType noteProperty -name Code -value $c.Code
		$obj | Add-Member -MemberType noteProperty -name Cause -value $c.Cause
		
		#$obj | Add-Member -MemberType noteProperty -name VC -value $VC
		#$obj | Add-Member -MemberType noteProperty -name ESXiHost -value $VMHost.Name
		#$obj | Add-Member -MemberType noteProperty -name Cluster -value $Cluster.Name
		#$obj | Add-Member -MemberType noteProperty -name VC -value $VC
		#$obj | Add-Member -MemberType noteProperty -name Blade -value $server
		#$obj | Add-Member -MemberType noteProperty -name UCS -value $sp1.Ucs
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
		
$OS = $report | sort VC,Cluster,UCS,DN,ESXIHOST,Created | ConvertTo-Html -Title "Test Title" -Head $HeadTest -Body "<div id='title'><center><h1>UCS Health Check</h1></div><a href=DIMMReport.csv title=DownloadCSV>Download Data</a><div id='subtitle'><center><h1>Report generated: $DateSub</h1></div><br></center><center><h2>Memory faults for UCS</h2></center>"   #</div><div id='subtitle'>Report generated: $DateSub</div>"
#"<div id='title'><center><b>UCS Health Check</b></div><div id='subtitle'><center>Report generated: $DateSub</div><br></center><div id='title'><center><b>Memory faults for UCS</b></center>$htmlheader"#</div><div id='subtitle'>Report generated: $DateSub</div>"

$OS | Out-File -FilePath $OutputFile -Force
$report  | sort VC,Cluster,UCS,DN,ESXIHOST,Created | Export-Csv -path $OutputFileCSV -Force -NoTypeInformation

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
Send-MailMessage -To "noc@skyscapecloud.com" -From "UCSFaultsIL2@skyscapecloud.com" -Subject "UCS DIMM Faults $gDate" -SmtpServer rly00001i2 -Body $HBody -BodyAsHtml  -Attachments $OutputFile,$OutputFileCSV #$outfile,$outfile1 
}
Else {
Send-MailMessage -To "noc@skyscapecloud.com" -From "UCSFaultsIL3@skyscapecloud.com" -Subject "UCS DIMM Faults $gDate" -SmtpServer 10.72.81.30 -Body $HBody -BodyAsHtml  -Attachments $OutputFile,$OutputFileCSV #-Attachments $outfile,$outfile1
}


Disconnect-VIServer * -Confirm:$false
Disconnect-Ucs