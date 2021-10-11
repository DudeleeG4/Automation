########## Get Snapshots from Management VCs ############
########## Created by Chris Black 27/02/2017 
##########


############ Import VMware Snapins ############

Add-PSSnapin vmware*

############ Invoke Visual Basic #############

 [void][System.Reflection.Assembly]::LoadWithPartialName(‘Microsoft.VisualBasic’)

########### Get List of Management VCs from SINT ###############
If ($env:USERDOMAIN -like "*il3*")

{

$sintUrlRoot="https://" + "sint.il3management.local"
$SINTheader=@{"AUTHORIZATION"="1aa9654a5176c3ab3e4969cfeec44a88ab0ca7f5"; "Accept"="application/vnd+skyscapecloud-v1,application/json"}
$FullNameArray = @()
$CurrentCI = Invoke-RestMethod -Method Get -Uri "$sintUrlRoot/api/ci/ci" -Headers $SINTHeader
$esxis = $CurrentCI   | Where-Object {$_.label -like "*vcw*" -or $_.label -like "*vcv*"} | Where-Object { $_.Description -like "*Management*" -or $_.Description -like "*Mgt*"}  # | Where-Object {$_.label -like "$vmhost*"}
foreach ($esxi in $esxis) {
$CIID = $esxi.id
#$CIID
$CurrentCI = Invoke-RestMethod -Method Get -Uri "$sintUrlRoot/api/ci/ci/$CIID" -Headers $SINTHeader
#$CurrentCI  
######## Filter For Production VC only #############
  $LC = $CurrentCI.additional_info | Where-object {$_.field_name -like "lifecycle"}
	If ($LC.field_value -like "Production" -and $CurrentCI.label -like "vcv*")
 	{
 
	$PODID = $CurrentCI.parent_id
	$POD = Invoke-RestMethod -Method Get -Uri "$sintUrlRoot/api/ci/ci/$PODID" -Headers $SINTHeader
	$SYSID = $POD.parent_id
	$SYS = Invoke-RestMethod -Method Get -Uri "$sintUrlRoot/api/ci/ci/$SYSID" -Headers $SINTHeader

	$FullName = $esxi.label + "." + $POD.label + "." + $SYS.label + "." + $Env:userdnsdomain.tolower()

	$FullNameArray += $FullName 
	}
	Elseif($LC.field_value -like "Production" -and $CurrentCI.label -like "vcw*")
	{
	$FullName = $esxi.label + "." + $Env:userdnsdomain.tolower()
	
	$FullNameArray += $FullName 
	}
}
##### Export List of Names ######
$FullNameArray 

}

Else{

$sintUrlRoot="https://" + "sint.il2management.local"
$SINTheader=@{"AUTHORIZATION"="9aa461637a7565c1f0cf29a99008e561eacb465c"; "Accept"="application/vnd+skyscapecloud-v1,application/json"}
$FullNameArray = @()
$CurrentCI = Invoke-RestMethod -Method Get -Uri "$sintUrlRoot/api/ci/ci" -Headers $SINTHeader
$esxis = $CurrentCI   | Where-Object {$_.label -like "*vcw*" -or $_.label -like "*vcv*"} | Where-Object { $_.Description -like "*Management*" -or $_.Description -like "*Mgt*"}  # | Where-Object {$_.label -like "$vmhost*"}
foreach ($esxi in $esxis) {
$CIID = $esxi.id
#$CIID
$CurrentCI = Invoke-RestMethod -Method Get -Uri "$sintUrlRoot/api/ci/ci/$CIID" -Headers $SINTHeader
#$CurrentCI  
######## Filter For Production VC only #############
  $LC = $CurrentCI.additional_info | Where-object {$_.field_name -like "lifecycle"}
	If ($LC.field_value -like "Production" -and $CurrentCI.label -like "vcv*")
 	{
 
	$PODID = $CurrentCI.parent_id
	$POD = Invoke-RestMethod -Method Get -Uri "$sintUrlRoot/api/ci/ci/$PODID" -Headers $SINTHeader
	$SYSID = $POD.parent_id
	$SYS = Invoke-RestMethod -Method Get -Uri "$sintUrlRoot/api/ci/ci/$SYSID" -Headers $SINTHeader

	$FullName = $esxi.label + "." + $POD.label + "." + $SYS.label + "." + $Env:userdnsdomain.tolower()

	$FullNameArray += $FullName 
	}
	Elseif($LC.field_value -like "Production" -and $CurrentCI.label -like "vcw*")
	{
	$FullName = $esxi.label + "." + $Env:userdnsdomain.tolower()
	
	$FullNameArray += $FullName 
	}
}
##### Export List of Names ######
$FullNameArray 
}

################################################################################################################################################

##### Connect to VC ######

#$vc = "vcw00003i3.il3management.local"
#Connect-VIServer $vc
#################################

$UN = $env:USERNAME.trim("su")
If ($env:USERDOMAIN -like "*il2*")
{
#$vCenterServers = @("vcv00004i2.pod00001.sys00001.il2management.local","vcv00005i2.pod00002.sys00002.il2management.local","vcw00001i2.il2management.local","vcw00002i2.il2management.local","vcw00003i2.il2management.local","vcw00004i2.il2management.local","vcw00005i2.il2management.local","vcw00007i2.il2management.local","vcw00008i2.il2management.local","vcw00009i2.il2management.local","vcw0000ai2.il2management.local")
#$vCenterServers = @("vcw00001i2.il2management.local","vcw00004i2.il2management.local")
#$vCenterServers = @("vcw00002i2.il2management.local")

#$vCenterServers = @([Microsoft.VisualBasic.Interaction]::InputBox("Which Virtual Center do you want to Check?","Example: vcw0000xix - Domain Suffix is already there", "vcw0000") + ".il2management.local")

$vCenterServers = @($FullNameArray)
$gDate = Get-Date -Format "dd-MM-yyyy"
#$cred = Get-Credential
$unameS = "il2management\sciencelogicvcw"
$credsS = "As5^l2%j9^j1*u7*s9!"
	$userPasswordS = ConvertTo-SecureString "$credsS" -AsPlainText -Force
	$credentialsS = new-object -typename System.Management.Automation.PSCredential -argumentlist $unameS,$userPasswordS


ForEach ($vCenterServer in $vCenterServers) {  
    Connect-VIServer -Server $vCenterServer -Credential $credentialsS #| Out-Null
     
}
}
Else {

#$vCenterServers = @("vcw00001i3.il3management.local","vcw00002i3.il3management.local","vcw00003i3.il3management.local","vcw00004i3.il3management.local","vcw00005i3.il3management.local","vcw00007i3.il3management.local","vcw00008i3.il3management.local")
#$vCenterServers = @("vcw00007i3.il3management.local")#,"vcw00001i3.il3management.local")
#$vCenterServers = @("vcw00007i3.il3management.local")
#$vCenterServers = @([Microsoft.VisualBasic.Interaction]::InputBox("Which Virtual Center do you want to Check?","Example: vcw0000xix - Domain Suffix is already there", "vcw0000") + ".il3management.local")
$vCenterServers = @($FullNameArray)

$gDate = Get-Date -Format "dd-MM-yyyy"
#$cred = Get-Credential

$unameS = "il3management\sciencelogicvcw"
$credsS = 'Sd4^l6$o9*z8^t7%r1!'
	$userPasswordS = ConvertTo-SecureString "$credsS" -AsPlainText -Force
	$credentialsS = new-object -typename System.Management.Automation.PSCredential -argumentlist $unameS,$userPasswordS

ForEach ($vCenterServer in $vCenterServers) {  
    Connect-VIServer -Server $vCenterServer -Credential $credentialsS #| Out-Null
     
}
}

############ Global Variables ############

$OutSnapCSV = "C:\inetpub\wwwroot\SnapshotInventory.csv"

############ Find Snapshots ###############

$snaplist = Get-View -ViewType VirtualMachine -Filter @{"snapshot"=""}

$SNames = $snaplist | Select-Object -ExpandProperty Name
$SNames
$ZArray = @()
$ZArraySnap = @()
$SizeGBArray = @()

ForEach ($N in $SNames)
{
$P = Get-VM -Name $N 
$snaps = $P | Get-Snapshot 
$Z = $snaps | Select-Object -Property VM,Created,Name,Description,@{L='SnapshotPowerState';E={($_.PowerState)}},ParentSnapshot,@{L='ChildrenName';E={($_.Children.Name)}},@{L='SizeMB';E={[math]::Round($_.SizeMB)}},IsCurrent,@{L='VMName';E={($P.Name)}},@{L='SizeGB';E={[math]::Round($_.SizeGB)}},@{L='ResourcePool';E={($P.ResourcePool)}},@{L='Folder';E={($P.Folder)}},@{L='VMPowerState';E={($P.PowerState)}},@{L='VC';E={($P.Client.ServerUri) -replace "443@"}},@{L='User';E={(Get-VIEvent -Entity $_.VM -Types Info -Finish $_.Created -MaxSamples 1 | Where-Object {$_.FullFormattedMessage -imatch 'Task: Create virtual machine snapshot'}).UserName}}

$Z
$SizeGB = $Z.SizeGB
$ZArray += $Z
$SizeGBArray += $SizeGB
}


$ZArray | Sort-Object -Property VC,VMName,SizeGB,Name

######### Export Snapshot List to CSV ############

$ZArray | Sort-Object -Property VC,VMName,SizeGB,Name |  Export-Csv -Path $OutSnapCSV -NoTypeInformation -Force


######### Calculate Total Size of the Snapshots #########

$SumTotalArraySizeGB = [math]::Round(($SizeGBArray  | Measure-Object -Sum).sum,2)
$SumTotalArraySizeGB 


######## Add Total Size of the Snapshots to the CSV ##############

$ImpCSV1 = Import-Csv $OutSnapCSV

"Total Size of Snapshots is $SumTotalArraySizeGB GB"
"Total Size of Snapshots is $SumTotalArraySizeGB GB" | Add-Content -Path $OutSnapCSV

############ Disconnect from VC ################
 Disconnect-VIServer * -Confirm:$false
 
 ################ Create The Report ###############
 $report = $ZArray | Sort-Object -Property VC,VMName,SizeGB,Name
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
 $OutputFile="C:\inetpub\wwwroot\SnapshotInventory.html" 
 $OutputFileCSV = "C:\inetpub\wwwroot\SnapshotInventory.csv"
 #$OutputFile="C:\temp\SnapshotInventory.html" 
 #$OutputFileCSV = "c:\Temp\SnapshotInventory.csv"
 #$OutputFileCSV = $OutSnapCSV
 $OS = $report | Sort-Object VC,VMName,SizeGB,Name | ConvertTo-Html -Title "Test Title" -Head $HeadTest -Body "<div id='title'><center><h1>Snapshot Inventory</h1></div><a href=SnapshotInventory.csv title=DownloadCSV>Download Data</a><div id='subtitle'><center><h1>Report generated: $DateSub</h1></div><br></center><center><h2>Total Size of Snapshots is $SumTotalArraySizeGB GB</h2></center><br><center><h2>Snapshots Per VC</h2></center>"   #</div><div id='subtitle'>Report generated: $DateSub</div>"
 $OS = $OS.Replace("&lt;","<").Replace("&gt;",">").Replace("&#39;","'")
 $OS | Out-File -FilePath $OutputFile -Force
 ##################$report | Sort-Object VC,VMName,SizeGB,Name | Export-Csv -path $OutputFileCSV -Force -NoTypeInformation
 
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
Send-MailMessage -To "noc@ukcloud.com" -From "SnapshotInventoryIL2@ukcloud.com" -Subject "Snapshot Inventory $gDate" -SmtpServer rly00001i2 -Body $HBody -BodyAsHtml  -Attachments $OutputFile,$OutputFileCSV #$outfile,$outfile1 
}
Else {
Send-MailMessage -To "noc@ukcloud.com" -From "SnapshotInventoryIL3@ukcloud.com" -Subject "Snapshot Inventory $gDate" -SmtpServer 10.72.81.30 -Body $HBody -BodyAsHtml  -Attachments $OutputFile,$OutputFileCSV #-Attachments $outfile,$outfile1
}

