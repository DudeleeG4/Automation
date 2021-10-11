#### Add Modules

Add-PSSnapin vmware*

Get-Module -ListAvailable | Where-Object {$_.Name -like "VMware*"}  | ForEach-Object {import-module -name $_}

#### Declare Function ###

Function GetGPUAttachedVMs 
{

		$AA = Get-View -ViewType HostSystem -Property Name,Config | Where-Object {$_.Config.GraphicsInfo.DeviceName -like "*NVIDIA*"}
		$AA | %{$_.UpdateViewData("Parent.Name","Vm.Name","Vm.Config.Hardware.Device","Vm.Runtime.PowerState","Vm.Parent.Name","Vm.Parent.Parent.Name","Vm.Parent.Parent.Parent.Name","Vm.Runtime.Host.Name","Vm.Runtime.Host.Parent.Name","Vm.Runtime.Host","Vm.Guest","Vm.Summary","Vm.Config.Version")}
		
		
		$BB = $AA.LinkedView.VM | ? {$_.config.hardware.device.backing.Vgpu -ne $null}
		
		$VMInfo = @()
		ForEach ($B in $BB)
		{
		
			$ReturnVMInfo = [pscustomobject]@{
			
			
			VMName = $B.Name
			MoRef = $B.MoRef.Value
			PowerState = $B.Runtime.PowerState
			GuestFullName = $B.Guest.GuestFullName
			HardwareVersion = $B.Config.Version
			ToolsStatus = $B.Guest.ToolsStatus
			ToolsVersion = $B.Guest.ToolsVersion
			ToolsRunningStatus = $B.Guest.ToolsRunningStatus
			vApp = $B.LinkedView.Parent.Name
			OrgVDC = $B.LinkedView.Parent.LinkedView.Parent.Name
			Org = $B.LinkedView.Parent.LinkedView.Parent.LinkedView.Parent.Name
			VideoCard  = $B.runtime.LinkedView.Host.Config.GraphicsInfo[1].DeviceName
			Vendor = $B.runtime.LinkedView.Host.Config.GraphicsInfo[1].VendorName
			Mode  = $B.runtime.LinkedView.Host.Config.GraphicsInfo[1].GraphicsType
			MemoryGB = [System.Math]::Round($B.runtime.LinkedView.Host.Config.GraphicsInfo[1].MemorySizeInKB/1MB, 0)
			ProfileActive =  ($B.Config.Hardware.Device | ? { $_.Backing.Vgpu } | 	select @{ N = 'Profile'; E = { $_.Backing.Vgpu -replace $rgxSuffix, '' } } | select -First 1).Profile
			HostName = $B.Runtime.LinkedView.Host.Name
			Cluster = $B.Runtime.LinkedView.Host.LinkedView.Parent.Name
			VC = $B.Client.ServiceUrl -replace "https://","" -replace "/sdk",""

			}
				$VMInfo += $ReturnVMInfo | Sort-Object -Property VC,Cluster,HostName,VideoCard,ProfileActive,MemoryGB
		}
		
$VMInfo
} #EndFunction GetGPUAttachedVMs



#### Connect to VCs ###


$UN = $env:USERNAME.trim("su")
If ($env:USERDOMAIN -like "*il2*")
{
#$vCenterServers = @("vcv00004i2.pod00001.sys00001.il2management.local","vcv00005i2.pod00002.sys00002.il2management.local","vcw00001i2.il2management.local","vcw00002i2.il2management.local","vcw00003i2.il2management.local","vcw00004i2.il2management.local","vcw00005i2.il2management.local","vcw00007i2.il2management.local","vcw00008i2.il2management.local","vcw00009i2.il2management.local","vcw0000ai2.il2management.local","vcv00006i2.pod00003.sys00004.il2management.local","vcv00007i2.pod00003.sys00004.il2management.local","vcv0000bi2.pod0000b.sys00005.il2management.local","vcv0000ci2.pod0000b.sys00005.il2management.local","vcv0000di2.pod0000f.sys00006.il2management.local","vcv0000ei2.pod0000f.sys00006.il2management.local")
#$vCenterServers = @("vcw00001i2.il2management.local") #,"vcw00004i2.il2management.local")
$vCenterServers = @("vcv00009i2.pod00008.sys00003.il2management.local","vcv0000ei2.pod0000f.sys00006.il2management.local","vcv00007i2.pod00003.sys00004.il2management.local")

$unameS = "il2management\sciencelogicvcw"
$credsS = "As5^l2%j9^j1*u7*s9!"
	$userPasswordS = ConvertTo-SecureString "$credsS" -AsPlainText -Force
	$credentialsS = new-object -typename System.Management.Automation.PSCredential -argumentlist $unameS,$userPasswordS

$gDate = Get-Date -Format "dd-MM-yyyy"
#$outPath = "c:\Temp\ESXInventoryCheckPV1.5_$gDate.csv"
#$cred = Get-Credential
ForEach ($vCenterServer in $vCenterServers) {  
    Connect-VIServer -Server $vCenterServer -Credential $credentialsS  | Out-Null
     
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


$GH = GetGPUAttachedVMs
$report = @()
$report += $GH

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
 $OutputFile="C:\inetpub\wwwroot\GPUVMsInventory.html" 
 $OutputFileCSV = "C:\inetpub\wwwroot\GPUVMsInventory.csv"
 $OS = $report  | Sort-Object -Property VC,Cluster,HostName,VideoCard,ProfileActive,MemoryGB | ConvertTo-Html -Title "Test Title" -Head $HeadTest -Body "<div id='title'><center><h1>GPU Enabled VMs Inventory</h1></div><a href=GPUVMsInventory.csv title=DownloadCSV>Download Data</a><div id='subtitle'><center><h1>Report generated: $DateSub</h1></div><br></center><center><h2>GPU Enabled VMs per VC</h2></center><br><center>"   #</div><div id='subtitle'>Report generated: $DateSub</div>"
 $OS = $OS.Replace("&lt;","<").Replace("&gt;",">").Replace("&#39;","'")
 $OS | Out-File -FilePath $OutputFile -Force
 $report  | Sort-Object -Property VC,Cluster,HostName,VideoCard,ProfileActive,MemoryGB | Export-Csv -path $OutputFileCSV -Force -NoTypeInformation
 
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
Send-MailMessage -To "cblack@ukcloud.com" -From "GPUVMInventory@ukcloud.com" -Subject "GPU Enabled VMs Inventory $gDate" -SmtpServer rly00001i2 -Body $HBody -BodyAsHtml  -Attachments $OutputFile,$OutputFileCSV #$outfile,$outfile1 
}
Else {
Send-MailMessage -To "cblack@ukcloud.com" -From "GPUVMInventoryIL3@ukcloud.com" -Subject "GPU Enabled VMs Inventory $gDate" -SmtpServer 10.72.81.30 -Body $HBody -BodyAsHtml  -Attachments $OutputFile,$OutputFileCSV #-Attachments $outfile,$outfile1
}

#### Disconnect VCs ###

 
Disconnect-VIServer * -Confirm:$false
 
