Add-PSSnapin vmware*
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

$GClust = Get-View -viewtype ComputeResource 
$array = @()
#$GC123 = Get-Cluster

#$GDR = $GC123 | Get-DrsRecommendation

ForEach ($Clust in $GClust)

{


$ClustStat = $Clust | select-object -Property @{N="ClusterName";E={($_.Name)}},@{N="VC";E={($_.Client.ServiceURL.trim("https://").Split(".")[0].trim("/sdk"))}},@{N="TargetBalance";E={($_.Summary.TargetBalance)}},@{N="CurrentBalance";E={($_.Summary.CurrentBalance)}},@{N="DRSMode";E={($_.Configuration.DrsConfig.DefaultVmBehavior)}},@{N="DRSLevel";E={($_.Configuration.DrsConfig.VmotionRate)}},@{N="DRSEnabled";E={($_.Configuration.DrsConfig.Enabled)}}

If ($ClustStat.CurrentBalance -gt $ClustStat.TargetBalance)
{

#Write-Host $ClustStat.ClusterName
#Write-Host $ClustStat.VC

$Balance = "Imbalanced"


#Write-Host "BROKEN"

}
Else{

$Balance = "Balanced"
#Write-Host $ClustStat.ClusterName
}


 $out = New-Object psobject
 $out | Add-Member noteproperty VC $ClustStat.VC
 $out | Add-Member noteproperty ClusterName $ClustStat.ClusterName
 $out | Add-Member noteproperty DRSEnabled $ClustStat.DRSEnabled
 $out | Add-Member noteproperty DRSLevel $ClustStat.DRSLevel
 $out | Add-Member noteproperty DRSMode $ClustStat.DRSMode
 $out | Add-Member noteproperty CurrentBalance $ClustStat.CurrentBalance
 $out | Add-Member noteproperty TargetBalance $ClustStat.TargetBalance
 $out | Add-Member noteproperty BalanceState $Balance
 
 


 $array += $out

}

$report = $array | Sort-Object -Property VC,ClusterName,BalanceState


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
 $OutputFile="C:\inetpub\wwwroot\DRSStatus.html" 
 $OutputFileCSV = "C:\inetpub\wwwroot\DRSStatus.csv"
 $OS = $report | ConvertTo-Html -Title "Test Title" -Head $HeadTest -Body "<div id='title'><center><h1>DRS Status</h1></div><a href=DRSStatus.csv title=DownloadCSV>Download Data</a><div id='subtitle'><center><h1>Report generated: $DateSub</h1></div><br></center><center><h2>DRS settings per Cluster</h2></center>"   #</div><div id='subtitle'>Report generated: $DateSub</div>"
 $OS  | Out-File -FilePath $OutputFile -Force
 $report | Export-Csv -path $OutputFileCSV -Force -NoTypeInformation


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
Send-MailMessage -To "noc@skyscapecloud.com" -From "DRSSettingsIL2@skyscapecloud.com" -Subject "DRS Settings $gDate" -SmtpServer rly00001i2 -Body $HBody -BodyAsHtml  -Attachments $OutputFile,$OutputFileCSV #$outfile,$outfile1 
}
Else {
Send-MailMessage -To "noc@skyscapecloud.com" -From "DRSSettingsIL3@skyscapecloud.com" -Subject "DRS Settings $gDate" -SmtpServer 10.72.81.30 -Body $HBody -BodyAsHtml  -Attachments $OutputFile,$OutputFileCSV #-Attachments $outfile,$outfile1
}


Disconnect-VIServer * -Confirm:$false