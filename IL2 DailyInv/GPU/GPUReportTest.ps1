#### Add Modules

Add-PSSnapin vmware*

#Get-Module -ListAvailable | Where-Object {$_.Name -like "CiscoUcsPS"} | ForEach-Object {import-module -name $_}
Get-Module -ListAvailable | Where-Object {$_.Name -like "VMware*"}  | ForEach-Object {import-module -name $_}

#### Declare Function ###

### From https://github.com/rgel/PowerCLi/blob/master/Vi-Module/Vi-Module.psm1
###
###

Function Get-VMHostGPU
{
	
<#
.SYNOPSIS
	Get ESXi hosts' GPU info.
.DESCRIPTION
	The Get-VMHostGPU cmdlet gets GPU info for ESXi host(s).
.PARAMETER VMHost
	VMHost object(s), returnd by Get-VMHost cmdlet.
.EXAMPLE
	PowerCLI C:\> Get-VMHost $VMHostName |Get-VMHostGPU
.EXAMPLE
	PowerCLI C:\> Get-Cluster $vCluster |Get-VMHost |Get-VMHostGPU |ft -au
.NOTES
	Author      :: Roman Gelman @rgelman75
	Shell       :: Tested on PowerShell 5.0|PowerCLi 6.5
	Platform    :: Tested on vSphere 5.5/6.5|vCenter 5.5U2/VCSA 6.5a|NVIDIAGRID K2
	Requirement :: PowerShell 3.0+
	Version 1.0 :: 23-Apr-2017 :: [Release]
.LINK
	https://ps1code.com/2017/04/23/esxi-vgpu-powercli
#>
	
	[Alias("Get-ViMVMHostGPU", "esxgpu")]
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	Param (
		[Parameter(Mandatory, ValueFromPipeline)]
		#[VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]$VMHost
		$VMHost
	)
	
	Begin
	{
		$ErrorActionPreference = 'Stop'
		$WarningPreference = 'SilentlyContinue'
		$rgxSuffix = '^grid_'
		$VMsCount = @()
	} #EndBegin
	
	
	Process
	{
		
		$VMHostView = Get-View -Id $VMHost.MoRef -Verbose:$false
		#$VMHostView | %{$_.UpdateViewData("Parent.Name","Vm.Name","Vm.Config.Hardware.Device")}
		$VMHostView | %{$_.UpdateViewData("Parent.Name","Vm.Name","Vm.Config.Hardware.Device","Vm.Runtime.PowerState","Vm.Parent.Name","Vm.Parent.Parent.Name","Vm.Parent.Parent.Parent.Name")}
		
		$Profiles = $VMHostView.Config.SharedPassthruGpuTypes
		
		
		foreach ($GraphicInfo in $VMHostView.Config.GraphicsInfo)
		{
			$VMs = @()
			$VMs += foreach ($vGpuVm in $GraphicInfo.Vm) { $vGpuVm } #| Convert-MoRef2Name}


			if ($VMs)
			{


				$VMNames = @() 
				foreach ($VM in (Get-View -Id $VMs  | ? { $_.Runtime.PowerState -eq 'PoweredOn' }  ))
				
			
				{
				$VMNames += $VM.Name
					#$ProfileActive = ($VM.ExtensionData.Config.Hardware.Device | ? { $_.Backing.Vgpu } |
					$ProfileActive = ($VM.Config.Hardware.Device | ? { $_.Backing.Vgpu } |
						select @{ N = 'Profile'; E = { $_.Backing.Vgpu -replace $rgxSuffix, '' } } | select -First 1).Profile
																	
				}
			
			}
			else
			{
				$VMNames = "No VMs Found"
				$ProfileActive = 'N/A'
			}
			$VMsCount += $VMs.count
			$returnGraphInfo = [pscustomobject]@{
				VMHost = [regex]::Match($VMHost.Name, '^(.+?)(\.|$)').Groups[1].Value
				Cluster = $VMHostView.LinkedView.Parent.Name
				VideoCard = $GraphicInfo.DeviceName
				Vendor = $GraphicInfo.VendorName
				Mode = $GraphicInfo.GraphicsType
				MemoryGB = [System.Math]::Round($GraphicInfo.MemorySizeInKB/1MB, 0)
				ProfileSupported = ($Profiles -replace $rgxSuffix, '') -join ','
				ProfileActive = $ProfileActive
				VMsMoRefs = $VMs -join ','
				VMCount = $VMs.count
				VMs = $VMNames -join ','
				VC = $VMHostView.Client.ServiceUrl -replace "https://","" -replace "/sdk",""
			}
			$returnGraphInfo | Sort-Object -Property VC,Cluster,VMHost,ProfileActive,MemoryGB,VideoCard,VMCount
		}
					
	} #EndProcess
	
	End { 	$global:SumTotalVMs = [math]::Round(($VMsCount  | Measure-Object -Sum).sum,2)
			#Write-host "Total Number of GPU Enabled VMs is $SumTotalVMs"
		}
	
} #EndFunction Get-VMHostGPU



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


#$GH = Get-View -ViewType HostSystem | Get-VMHostGPU | where {$_.VideoCard -like "NVIDIA*"}
#$GH = Get-View -ViewType HostSystem -Property Name,Config | Where-Object {$_.Config.GraphicsInfo.DeviceName -like "*NVIDIA*"} | Get-VMHostGPU 
$GH = Get-View -ViewType HostSystem -Property Name,Config | Where-Object {$_.Config.GraphicsInfo.DeviceName -like "*NVIDIA*"} | Get-VMHostGPU | where {$_.VideoCard -like "NVIDIA*"}
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
 $OutputFile="C:\inetpub\wwwroot\GPUHostsInventory.html" 
 $OutputFileCSV = "C:\inetpub\wwwroot\GPUHostsInventory.csv"
 $OS = $report | Sort-Object -Property VC,Cluster,VMHost,ProfileActive,MemoryGB,VideoCard,VMCount | ConvertTo-Html -Title "Test Title" -Head $HeadTest -Body "<div id='title'><center><h1>GPU Enabled Hosts Inventory</h1></div><a href=GPUHostsInventory.csv title=DownloadCSV>Download Data</a><div id='subtitle'><center><h1>Report generated: $DateSub</h1></div><br></center><center><h2>Total Count of GPU Enabled VMs = $SumTotalVMs</h2></center><center><h2>Hosts per VC</h2></center><br><center>"   #</div><div id='subtitle'>Report generated: $DateSub</div>"
 $OS = $OS.Replace("&lt;","<").Replace("&gt;",">").Replace("&#39;","'")
 $OS | Out-File -FilePath $OutputFile -Force
 $report | Sort-Object -Property VC,Cluster,VMHost,ProfileActive,MemoryGB,VideoCard,VMCount | Export-Csv -path $OutputFileCSV -Force -NoTypeInformation
 
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
Send-MailMessage -To "cblack@ukcloud.com" -From "GPUHostInventory@ukcloud.com" -Subject "GPU Enabled Hosts Inventory $gDate" -SmtpServer rly00001i2 -Body $HBody -BodyAsHtml  -Attachments $OutputFile,$OutputFileCSV #$outfile,$outfile1 
}
Else {
Send-MailMessage -To "cblack@ukcloud.com" -From "GPUHostInventoryIL3@ukcloud.com" -Subject "GPU Enabled Hosts Inventory $gDate" -SmtpServer 10.72.81.30 -Body $HBody -BodyAsHtml  -Attachments $OutputFile,$OutputFileCSV #-Attachments $outfile,$outfile1
}

#### Disconnect VCs ###

 
Disconnect-VIServer * -Confirm:$false
 
