clear
Add-PSSnapin vmware* -ErrorAction 'silentlycontinue'
Import-Module Microsoft.Powershell.Utility -ErrorAction 'silentlycontinue' -WarningAction 'silentlycontinue'
$DesktopPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)

$unameS = "il3management\sciencelogicvcw"
$credsS = 'Sd4^l6$o9*z8^t7%r1!'
	$userPasswordS = ConvertTo-SecureString "$credsS" -AsPlainText -Force
	$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $unameS,$userPasswordS

$vCenterServers = @("vcw00002i3.il3management.local","vcw00003i3.il3management.local","vcw00005i3.il3management.local","vcw00007i3.il3management.local","vcw00008i3.il3management.local", "vcv00003i3.pod0000d.sys00005.il3management.local", "vcv00005i3.pod00012.sys00006.il3management.local")
write-host Connecting
$report = @()
Connect-VIServer -Server $vCenterServers -Credential $cred  -ErrorAction 'silentlycontinue'


$VMs = Get-View -ViewType VirtualMachine | Where-Object {$_.Config.ManagedBy.ExtensionKey -like ""} | where-object {$_.Name -notlike "vse*"} | Where-Object {$_.Name -notlike "avp*"} | Where-Object {$_.Name -notlike "svm*"}
foreach ($VM in $VMs){
		$VC = $VM.Client.ServiceUrl
		$VC = $VC -split "/" | Select -Index 2
		$info = "" | select vCenter, VM, "Managed By", "Power State"
		$info.vCenter = $VC
		$info.VM = $VM.Name
		$ManagedBy = $VM.Config.ManagedBy.ExtensionKey
		if (!$ManagedBy) {$info."Managed By" = "Nothing"}
		else {$info."Managed By" = $VM.Config.ManagedBy.ExtensionKey}
		$info."Power State" = $VM.Runtime.PowerState
		
		$report += $info
		}


$final = $report


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
 $OutputFile="C:\inetpub\wwwroot\VMsNotManagedByvCloud.html"
 $OutputFileCSV = "C:\inetpub\wwwroot\VMsNotManagedByvCloud.csv"
 $OS = $Final | Sort vCenter | ConvertTo-Html -Title "Test Title" -Head $HeadTest -Body "<div id='title'><center><h1>VMs not managed by vCloud IL3</h1></div><a href=VMsNotManagedByvCloud.csv title=DownloadCSV>Download Data</a><div id='subtitle'><center><h1>Report generated: $DateSub</h1></div><br></center><left><p>The below table is a list of VMs not managed by vCloud. <br/> <br/> This report runs every Sunday at 22:00 </p></left>" 
 $OS  | Out-File -FilePath $OutputFile -Force
 $Final | Sort vCenter | Export-Csv -path $OutputFileCSV -Force -NoTypeInformation


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
Send-MailMessage -To "molejar@skyscapecloud.com" -From "VMsNotManagedByvCloudIL3@ukcloud.com" -Cc "noc@ukcloud.com" -Bcc "molejar@ukcloud.com" -Subject "VMs not managed by vCloud IL3 $gDate" -SmtpServer rly00001i2 -Body $HBody -BodyAsHtml  -Attachments $OutputFile,$OutputFileCSV #$outfile,$outfile1 
}
Else {
Send-MailMessage -To "molejar@skyscapecloud.com" -From "VMsNotManagedByvCloudIL3@ukcloud.com" -Cc "noc@ukcloud.com" -Bcc "molejar@ukcloud.com"  -Subject "VMs not managed by vCloud IL3 $gDate" -SmtpServer 10.72.81.30 -Body $HBody -BodyAsHtml  -Attachments $OutputFile,$OutputFileCSV #-Attachments $outfile,$outfile1
}


Disconnect-VIServer * -Confirm:$false -ErrorAction 'SilentlyContinue'



