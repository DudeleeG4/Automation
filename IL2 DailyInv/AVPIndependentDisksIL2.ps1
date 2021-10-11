Add-PSSnapin vmware* -ErrorAction 'silentlycontinue'
$vCenterServers = @("vcw00001i2.il2management.local", "vcw00002i2.il2management.local", "vcw00003i2.il2management.local", "vcw00004i2.il2management.local", "vcw00005i2.il2management.local", "vcw00007i2.il2management.local", "vcw00008i2.il2management.local", "vcw00009i2.il2management.local", "vcw0000ai2.il2management.local", "vcv00004i2.pod00001.sys00001.il2management.local", "vcv00005i2.pod00002.sys00002.il2management.local", "vcv00006i2.pod00003.sys00004.il2management.local", "vcv00007i2.pod00003.sys00004.il2management.local", "vcv0000bi2.pod0000b.sys00005.il2management.local", "vcv0000ci2.pod0000b.sys00005.il2management.local", "vcv0000di2.pod0000f.sys00006.il2management.local", "vcv0000ei2.pod0000f.sys00006.il2management.local")
$unameS = "il2management\sciencelogicvcw"
$credsS = "As5^l2%j9^j1*u7*s9!"
	$userPasswordS = ConvertTo-SecureString "$credsS" -AsPlainText -Force
	$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $unameS,$userPasswordS
Connect-VIServer -Server $vCenterServers -Credential $cred  -ErrorAction 'silentlycontinue'
$Filter = @{"Name" = "avp0*"}
$VMList = Get-View -ViewType VirtualMachine -Filter $Filter | Select Name 
$Final = @()
ForEach ($VM in $VMList) {$VirtualMachine = $VMList.Name}
$SubFinal = Get-Harddisk -VM $VirtualMachine | select * | Where-Object {$_.Persistence -like "IndependentNonPersistent"}


foreach ($disk in $SubFinal)
{
	$info = "" | select VM, Filename, Name, <#"CPU Usage",#> vCenter
	$info.VM = $disk.Parent
	$info.Filename = $disk.Filename
	$info.Name = $disk.Name
	$info.vCenter = $disk.Parent.ExtensionData.Client.ServiceUrl -split "\/" | Select -Index 2
	#$info."CPU Usage" = get-stat -Entity $disk.Parent -Realtime -Stat "cpu.usage.average" -MaxSamples 1
	$Final += $info
}

#$Final | Sort "vCenter", "VM", "Name" | select vCenter, VM, Name, FileName <#, "CPU Usage"#> | Out-GridView
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
p
{
	text-decoration: none !important;
    text-align:left;
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
 #$DesktopPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
 $OutputFile= <#"$DesktopPath\Test.html" #>"C:\inetpub\wwwroot\AVPsWithStuckDisks.html"
 $OutputFileCSV = <#"$DesktopPath\Test.CSV" #>"C:\inetpub\wwwroot\AVPsWithStuckDisks.csv"
 $OS = $Final | Sort "vCenter", "VM", "Name" | select vCenter, VM, Name, FileName <#, "CPU Usage"#> | ConvertTo-Html -Title "Test Title" -Head $HeadTest -Body "<div id='title'><center><h1>VMDKs attatched to Avamar Proxies on IL2</h1></div><a href=AVPsWithStuckDisks.csv title=DownloadCSV>Download Data</a><div id='subtitle'><center><h1>Report generated: $DateSub</h1></div><br></center><left><p>The below table is a list of VMDK&#39;s attached to Avamar Proxies. This table of VMDK&#39;s will need to be checked against running backups. Any VMDK&#39;s attached to proxies where there is no running backup for the owning VM will be removed. <br/> <br/> The documentation for this is located at https://confluence.il2management.local/display/MONITORING/Detach+VMDKs+from+Avamar+Proxy under the heading &#39;VMDK Does not detach from Avamar Proxy&#39;.</p></left>"   #</div><div id='subtitle'>Report generated: $DateSub</div>"
 $OS  | Out-File -FilePath $OutputFile -Force
 $Final | Sort "vCenter", "VM", "Name" | select vCenter, VM, Name, FileName <#, "CPU Usage"#> | Export-Csv -path $OutputFileCSV -Force -NoTypeInformation


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
Send-MailMessage -To "noc@ukcloud.com" -From "AVPIndependentDisksIL2@skyscapecloud.com" -Bcc "mharris@skyscapecloud.com" -Subject "VMDKs stuck to AVPs $gDate" -SmtpServer rly00001i2 -Body $HBody -BodyAsHtml  -Attachments $OutputFile,$OutputFileCSV #$outfile,$outfile1 
}
Else {
Send-MailMessage -To "noc@ukcloud.com" -From "AVPIndependentDisksIL2@skyscapecloud.com" -Bcc "mharris@skyscapecloud.com" -Subject "VMDKs stuck to AVPs $gDate" -SmtpServer 10.72.81.30 -Body $HBody -BodyAsHtml  -Attachments $OutputFile,$OutputFileCSV #-Attachments $outfile,$outfile1
}


Disconnect-VIServer * -Confirm:$false -ErrorAction 'SilentlyContinue'



