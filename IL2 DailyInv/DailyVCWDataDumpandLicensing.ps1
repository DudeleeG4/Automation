# List out all management servers

import-vim





Function Render-HostData($HostData)
{
	$HTML = @"
<HTML>
<HEAD>
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
text-align:left;
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

</HEAD>
<BODY>
<h1>Host Inventory - $((Get-Date).ToString("dd-MM-yyyy hh:mm:ss"))</h1>
<a href="hostinventory.csv" title="Download Today's CSV">Download Data</a>
"@
	$TableColumns = $HostData[0] | GM -MemberType NoteProperty | Select Name
	$Query = ""
	Foreach($C in $TableColumns)
	{
		if(@("ParentId","Parent","VCW","Name","MgmtIP","Version","Build","MgmtSubnetMask") -notcontains $C.name)
		{
			$Query += "$($C.Name),"
		}
	}
	$HostData = $HostData | Select *,@{name="IP";expression={"<a href='https://solarwinds.il2management.local/Orion/IPAM/search.aspx?q=$($_.MgmtIP)' target='blank'>$($_.MgmtIP)</a>"}},@{name="ESX";expression={"<a href='https://sciencelogic.il2management.local/em7/index.em7?exec=registry&act=registry_device_management#devmgt_search.device=$($_.Name)' target='blank'>$($_.Name)</a>"}}
	$Query = $Query.TrimEnd(",")
	$Command = '$Cluster.Group | Select ESX,IP,MgmtSubnetMask,Version,Build,' + $Query + ' | ConvertTo-HTML'
	$Grouped = $HostData | Group VCW
	ForEach($VCW in $Grouped)
	{
		$Clusters = $VCW.Group | Group Parent
		$HTML += "<h1>$($VCW.Name)</h1>"
		ForEach($Cluster in $Clusters)
		{
			$HTML += "<h2>$($Cluster.Name)</h2>"	
			$Table = Invoke-Expression $Command
			$Table = $Table.Replace("&lt;","<").Replace("&gt;",">").Replace("&#39;","'")
			$HTML += $Table
		}
	}
	$HTML += "</BODY>"
	Return $HTML
}

Function Process-VMData($VMs,$VCW)
{
	
	$VMTable = @()
	$VMCount = 1
	ForEach($VM in $VMs)
	{
		$VMPercent = ($VMCount/($VMS.count))*100
		$VMCount += 1
		Write-Progress -Id 1 -Status "$($VM.Name)" -Activity "Processing VM" -PercentComplete $VMPercent
		
		$AllIPAddresses = $null
		if($VM.ExtensionData.guest.net.ipaddress -ne $Null)
		{
			$AllIPAddresses = $VM.ExtensionData.guest.net | Select -ExpandProperty IPAddress | ?{$_ -notlike "*:*"}
		}
		$ConcatIPAddresses = ""
		ForEach($IP in $AllIPAddresses)
		{
			$ConcatIPAddresses += "$($IP),"
		}
		$ConcatIPAddresses = $ConcatIPAddresses.TrimEnd(",")

		$Holder = "" | Select VCW,Name,Version,PowerState,Description,MemoryGB,NumCPU,ResourcePool,ResourcePoolId,Folder,FolderId,ProvisionedSpaceGB,UsedSpaceGB,ToolsStatus,ToolsVersion,ToolsRunningStatus,GuestId,GuestFullName,IPAddress,AllIPAddresses,Template,Host,HostID
		
		$Holder.VCW = $VCW
		$Holder.Name = $VM.Name
		$Holder.Version = $VM.Version
		$Holder.PowerState = $VM.PowerState
		$Holder.Description = $VM.Description
		$Holder.MemoryGB = $VM.MemoryGB
		$Holder.NumCPU = $VM.NumCPU
		$Holder.ResourcePool = $VM.ResourcePool
		$Holder.ResourcePoolId = $VM.ResourcePoolId
		$Holder.Folder = $VM.Folder
		$Holder.FolderId = $VM.FolderId
		$Holder.ProvisionedSpaceGB = $VM.ProvisionedSpaceGB
		$holder.UsedSpaceGB = $VM.UsedSpaceGB
		$Holder.ToolsStatus = $VM.extensiondata.guest.ToolsStatus
		$Holder.ToolsVersion = $VM.extensiondata.guest.ToolsVersion
		$Holder.ToolsRunningStatus = $VM.extensiondata.guest.ToolsRunningStatus
		$Holder.GuestID = $VM.extensiondata.config.GuestID
		$Holder.GuestFullName = $VM.extensiondata.config.GuestFullName
		$Holder.IPAddress = $VM.extensiondata.guest.IpAddress
		$Holder.Host = $VM.host.name
		$Holder.HostID = $VM.host.id
		$Holder.AllIPAddresses = $ConcatIPAddresses 
		$Holder.Template = $VM.extensiondata.config.template
		$VMTable += $Holder
	}
	Return $VMTable
}

Function Process-HostData($Hosts,$VCW)
{
	
	$HostTable = @()
	$HostCount = 1
	ForEach($ESXHost in $Hosts)
	{
		$HostPercent = ($HostCount/($Hosts.count))*100
		$HostCount += 1
		Write-Progress -Id 1 -Status "$($Host.Name)" -Activity "Processing Host" -PercentComplete $HostPercent
		
		$Holder = "" | Select VCW,Name,State,ParentId,Manufacturer,Model,NumCPU,CpuTotalMhz,CPUUsageMhz,MemoryTotalMB,MemoryUsageMB,ProcessorType,HyperThreadingActive,TimeZone,Version,Build,Parent,MgmtIP,MgmtSubnetMask,MgmtMAC
		
		$Holder.VCW = $VCW
		$Holder.Name = $ESXHost.Name
		$Holder.State = $ESXHost.State
		$Holder.ParentId = $ESXHost.ParentID
		$Holder.Manufacturer = $ESXHost.Manufacturer
		$Holder.Model = $ESXHost.Model
		$Holder.NumCPU = $ESXHost.NumCPU
		$Holder.CPUTotalMhz = $ESXHost.CPUTotalMhz
		$Holder.CPUUsageMhz = $ESXHost.CPUUsageMhz
		$Holder.MemoryTotalMB = $ESXHost.MemoryTotalMB
		$Holder.MemoryUsageMB = $ESXHost.MemoryUsageMB
		$Holder.ProcessorType = $ESXHost.ProcessorType
		$Holder.HyperThreadingActive = $ESXHost.HyperThreadingActive
		$Holder.TimeZone = $ESXHost.TimeZone
		$Holder.Version = $ESXHost.Version
		$Holder.Build = $ESXHost.Build
		$Holder.Parent = $ESXHost.Parent
	
		$MgmtIP = $ESXHost| Get-VMHostNetworkAdapter | ?{$_.IP -like "10.*"} | Select -First 1
		
		$Holder.MgmtIP = $MgmtIP.IP
		$Holder.MgmtSubnetmask = $MgmtIP.SubnetMask
		$Holder.MgmtMAC = $MgmtIP.Mac
			
		
		$HostTable += $Holder
	}
	Return $HostTable
}



Function Process-DSData($Datastores,$VCW)
{
	$DSTable = @()
	$DSCount = 1
	ForEach($DS in $Datastores)
	{
		$DSPercent = ($DSCount/($Datastores.count))*100
		$DSCount += 1
		Write-Progress -Id 1 -Status "$($DS.Name)" -Activity "Processing Datastore" -PercentComplete $DSPercent
		$Holder = "" | Select VCW,Name,Datacenter,DatacenterID,FileSystemVersion,FreeSpaceMB,CapacityMB,Type,State
		$Holder.VCW = $VCW
		$Holder.Name = $DS.Name
		$Holder.Datacenter = $DS.Datacenter
		$Holder.DatacenterId = $DS.DatacenterId
		$Holder.FileSystemVersion = $DS.FileSystemVersion
		$Holder.FreeSpaceMB = $DS.FreeSpaceMB
		$Holder.CapacityMB = $DS.CapacityMB
		$Holder.Type = $DS.Type
		$Holder.State = $DS.State
		$DSTable += $Holder

	}
	Return $DSTable
}


$Domain = "il2management"
$Username = "suprossi"
$Password = 'Password123#!'

connect-viserver -Server vcw00001i2.il2management.local -User "$Username" -Password $Password
connect-viserver -Server vcw00002i2.il2management.local -User "$Domain\$Username" -Password $Password
connect-viserver -Server vcw00003i2.il2management.local -User "$Domain\$Username" -Password $Password
connect-viserver -Server vcw00004i2.il2management.local -User "$Username" -Password $Password
connect-viserver -Server vcw00005i2.il2management.local -User "$Username" -Password $Password
connect-viserver -Server vcw00007i2.il2management.local -User "$Username" -Password $Password
connect-viserver -Server vcw00009i2.il2management.local -User "$Username" -Password $Password
connect-viserver -Server vcv00006i2.pod00003.sys00004.il2management.local -User "$Username" -Password $Password
connect-viserver -Server vcv00007i2.pod00003.sys00004.il2management.local -User "$Username" -Password $Password
connect-viserver -Server vcv0000bi2.pod0000b.sys00005.il2management.local -User "$Username" -Password $Password
connect-viserver -Server vcv0000ci2.pod0000b.sys00005.il2management.local -User "$Username" -Password $Password
connect-viserver -Server vcv0000di2.pod0000f.sys00006.il2management.local -User "$Username" -Password $Password
connect-viserver -Server vcv0000ei2.pod0000f.sys00006.il2management.local -User "$Username" -Password $Password


$VCCs = @("vcw00001i2.il2management.local","vcw00002i2.il2management.local","vcw00003i2.il2management.local","vcw00004i2.il2management.local","vcw00005i2.il2management.local", "vcw00007i2.il2management.local", "vcw00009i2.il2management.local","vcv00006i2.pod00003.sys00004.il2management.local","vcv00007i2.pod00003.sys00004.il2management.local","vcv0000bi2.pod0000b.sys00005.il2management.local","vcv0000ci2.pod0000b.sys00005.il2management.local","vcv0000di2.pod0000f.sys00006.il2management.local","vcv0000ei2.pod0000f.sys00006.il2management.local")

import-vim
$DSTable = @()
$VMTable = @()
$HostTable = @()
$VCCCount = 1
$ClusterTable = @()
ForEach($VCW in $VCCs)
{
	$VCCPercent = ($VCCCount/($VCCs.count))*100
	$VCCCount += 1
	Write-Progress -Id 0 -Status $VCW -Activity "Processing Virtual Center" -PercentComplete $VCCPercent
	$VMs = Get-VM -Name * -Server $VCW
	$Datastores = Get-Datastore -Name * -Server $VCW
	$Hosts = Get-VMHost -Server $VCW -Name *
	$VMTable += Process-VMData -VMs $VMs -VCW "$VCW"
	$DSTable += Process-DSData -Datastores $Datastores -VCW "$VCW"
	$HostTable += Process-HostData -Hosts $Hosts -VCW "$VCW"
	$Clusters = Get-Cluster -name * -server $VCW
	write-host "Processing Clusters"
	ForEach($Cluster in $Clusters)
	{
		$ESXHosts = $Cluster | Get-VMHost
		ForEach($H in $ESXHosts)
		{
			$Holder = "" | Select VCW,Cluster,ESXHost,NumCPU
			$Holder.VCW = $VCW
			$Holder.Cluster = $Cluster.Name
			$Holder.ESXHost = $H.Name
			$Holder.NumCPU = $H.config.hardware.NumCPU
			$ClusterTable += $Holder
		}
	}
}

$ClusterTablePath = "c:\scheduledscripts\VCWReports\Clusters-$((Get-Date).ToString('dd-MM-yyyy')).csv"
$ClusterTable | Export-CSV -path $ClusterTablePath -NoTypeInformation

$VMTablePath = "c:\scheduledscripts\VCWReports\VMS-$((Get-Date).ToString('dd-MM-yyyy')).csv"
$VMTable | Export-Csv -Path $VMTablePath -NoTypeInformation

$DSTablePath = "c:\scheduledscripts\VCWReports\Datastores-$((Get-Date).ToString('dd-MM-yyyy')).csv"
$DSTable | Export-Csv -Path $DSTablePath -NoTypeInformation

$HostTablePath = "c:\scheduledscripts\VCWReports\Hosts-$((Get-Date).ToString('dd-MM-yyyy')).csv"
$HostTable | Export-Csv -Path $HostTablePath -NoTypeInformation

$HostHTML = Render-HostData $HostTable
$HostHTML | Set-Content -Path c:\inetpub\wwwroot\hostinventory.html
$HostTable | Export-Csv -Path c:\inetpub\wwwroot\hostinventory.csv -NoTypeInformation


#------------------------------------------
#---- VCLOUD LOGINS -----------------------
#------------------------------------------

$Username = "administrator"
$Password = 'Tw9$c7!a8*q0$l3%t6!'

Connect-ciserver -server vcd00002i2 -user $Username -password $Password

# Licensing Information

$GroupedData = $VMTable | Group -Property ResourcePool

$VDCs = Get-OrgVDC *
$NewTable = @()
$VDCCount = 1
$Log = ""
ForEach($VDC in $VDCs)
{
	$VDCPercent = ($VDCCount/($VDCs.count))*100
	$VDCCount += 1
	Write-Progress -Id 0 -Status "$($VDC.Name)" -Activity "Processing" -PercentComplete $VDCPercent
	$OrgID = $VDC.org.id.split(":")[3]
	$VDCId =$VDC.id.split(":")[3]
	#Write-Host $OrgID
	$TheseVMs = $GroupedData | ?{$_.name -like "*$VDCID*"}
	$VMCount = 1
	if(($TheseVMs | Measure-Object).count -gt 0)
	{
		ForEach($VM in $TheseVMs.Group)
		{
			$VMPercent = ($VMCount/($TheseVMS.count))*100
			$VMCount += 1
			$Holder = $VM
			Write-Progress -Id 1 -Status "$($VM.Name)" -Activity "Processing..." -PercentComplete $VMPercent
			$Holder | add-member -MemberType NoteProperty -Name OrgID -Value $OrgID -Force
			$Holder | add-member -MemberType NoteProperty -Name OrgName -Value $VDC.org.Name -Force
			$Holder | add-member -MemberType NoteProperty -Name OrgDescription -Value $VDC.org.Description -Force
			$Holder | add-member -MemberType NoteProperty -Name VDCName -Value $VDC.name -Force
			$Holder | add-member -MemberType NoteProperty -Name VDCId -Value $VDC.id -Force
			$Holder | add-member -MemberType NoteProperty -Name VDCDescription -Value $VDC.description -Force
			$NewTable += $Holder
			$Holder = $null
		}
	}
	else
	{
		$Log += "Couldn't find any VM's for $VDCid - $($VDC.name) - $($VDC.description)`r`n"
	}
}

$LicensingPath = "C:\scheduledscripts\VCWReports\Licensing-$((Get-Date).ToString('dd-MM-yyyy')).csv"
$NewTable | Export-Csv -NoTypeInformation -Path $LicensingPath

$LogPath = "C:\scheduledscripts\VCWReports\Licensing-$((Get-Date).ToString('dd-MM-yyyy')).log"
$Log | Set-Content $LogPath

# Get License Report Per Org
# Microsoft and RHEL

$LicData = Import-Csv $LicensingPath
$Orgs = $LicData | Group OrgName
$LicSummary = @()
ForEach($Org in $Orgs)
{
	$VDCs = $Org.group | Select VDCName -Unique
	ForEach($VDC in $VDCs)
	{
		$Holder = "" | Select OrgID,OrgName,OrgDescription,VDCName,VDCId,VDCDescription,Microsoft,RedHat,Ubuntu,CentOS,SUSE,Debian,FreeBSD,VMWareESX,Solaris,Other
		$Holder.OrgID = $Org.group[0].OrgId
		$Holder.OrgName = $Org.group[0].OrgName
		$Holder.OrgDescription = $Org.group[0].OrgDescription
		$VDCId = ($Org.group | ?{$_.VDCName -eq $VDC.VDCName} | Select -property VDCId -First 1).VDCId
		$VDCDescription = ($Org.group | ?{$_.VDCName -eq $VDC.VDCName} | Select -property VDCDescription -First 1).VDCDescription
		$Holder.VDCName = $VDC.VDCName
		$Holder.VDCId = $VDCId
		$Holder.VDCDescription = $VDCDescription
		$Holder.Microsoft = ($Org.Group | ?{$_.VDCName -eq $VDC.VDCName} | ?{$_.GuestFullName -like "Microsoft*"} | Measure-Object).count
		$Holder.RedHat = ($Org.Group | ?{$_.VDCName -eq $VDC.VDCName} | ?{$_.GuestFullName -like "Red Hat*"} | Measure-Object).count
		$Holder.Ubuntu = ($Org.Group | ?{$_.VDCName -eq $VDC.VDCName} | ?{$_.GuestFullName -like "Ubuntu*"} | Measure-Object).count
		$Holder.CentOS = ($Org.Group | ?{$_.VDCName -eq $VDC.VDCName} | ?{$_.GuestFullName -like "CentOS*"} | Measure-Object).count
		$Holder.SUSE = ($Org.Group | ?{$_.VDCName -eq $VDC.VDCName} | ?{$_.GuestFullName -like "SUSE*"} | Measure-Object).count
		$Holder.Debian =($Org.Group | ?{$_.VDCName -eq $VDC.VDCName} | ?{$_.GuestFullName -like "Debian*"} | Measure-Object).count
		$Holder.FreeBSD = ($Org.Group | ?{$_.VDCName -eq $VDC.VDCName} | ?{$_.GuestFullName -like "FreeBSD*"} | Measure-Object).count
		$Holder.VMwareESX= ($Org.Group | ?{$_.VDCName -eq $VDC.VDCName} | ?{$_.GuestFullName -like "VMware*"} | Measure-Object).count
		$Holder.Solaris = ($Org.Group | ?{$_.VDCName -eq $VDC.VDCName} | ?{$_.GuestFullName -like "*Solaris*"} | Measure-Object).count
		$Holder.Other = ($Org.Group | ?{$_.VDCName -eq $VDC.VDCName} | ?{$_.GuestFullName -like "Other*"} | Measure-Object).count
		$LicSummary += $Holder
	}
}

$LicensingSummaryPath = "C:\scheduledscripts\VCWReports\ClientLicensingSummary-$((Get-Date).ToString('dd-MM-yyyy')).csv"
$LicSummary | Sort Orgname,VDCName  | Export-Csv -NoTypeInformation -Path $LicensingSummaryPath

$SkyscapeVMs = $VMTable | ?{$_.ResourcePool -notlike "*(*-*-*-*)*"}
$VCWS = $SkyscapeVMs | Group -Property VCW
$SkyscapeLicSummaryTable = @()
Foreach($VCW in $VCWs)
{

		$Holder = "" | Select OrgName,VCW,Microsoft,RedHat,Ubuntu,CentOS,SUSE,Debian,FreeBSD,VMWareESX,Solaris,Other
		
		$Holder.OrgName = "Skyscape"
		$Holder.VCW = $VCW.Name
		
		$Holder.Microsoft = ($SkyscapeVMs | ?{$_.VCW -eq $VCW.Name} | ?{$_.GuestFullName -like "Microsoft*"} | Measure-Object).count
		$Holder.RedHat = ($SkyscapeVMs | ?{$_.VCW -eq $VCW.Name} | ?{$_.GuestFullName -like "Red Hat*"} | Measure-Object).count
		$Holder.Ubuntu = ($SkyscapeVMs | ?{$_.VCW -eq $VCW.Name} | ?{$_.GuestFullName -like "Ubuntu*"} | Measure-Object).count
		$Holder.CentOS = ($SkyscapeVMs | ?{$_.VCW -eq $VCW.Name} | ?{$_.GuestFullName -like "CentOS*"} | Measure-Object).count
		$Holder.SUSE = ($SkyscapeVMs | ?{$_.VCW -eq $VCW.Name} | ?{$_.GuestFullName -like "SUSE*"} | Measure-Object).count
		$Holder.Debian =($SkyscapeVMs | ?{$_.VCW -eq $VCW.Name} | ?{$_.GuestFullName -like "Debian*"} | Measure-Object).count
		$Holder.FreeBSD = ($SkyscapeVMs | ?{$_.VCW -eq $VCW.Name} | ?{$_.GuestFullName -like "FreeBSD*"} | Measure-Object).count
		$Holder.VMwareESX= ($SkyscapeVMs | ?{$_.VCW -eq $VCW.Name} | ?{$_.GuestFullName -like "VMware*"} | Measure-Object).count
		$Holder.Solaris = ($SkyscapeVMs | ?{$_.VCW -eq $VCW.Name} | ?{$_.GuestFullName -like "*Solaris*"} | Measure-Object).count
		$Holder.Other = ($SkyscapeVMs | ?{$_.VCW -eq $VCW.Name} | ?{$_.GuestFullName -like "Other*"} | Measure-Object).count
		$SkyscapeLicSummaryTable += $Holder
}

$SkyscapeLicensingSummaryPath = "C:\scheduledscripts\VCWReports\SkyscapeLicensingSummary-$((Get-Date).ToString('dd-MM-yyyy')).csv"
$SkyscapeLicSummaryTable | Sort Orgname,VDCName  | Export-Csv -NoTypeInformation -Path $SkyscapeLicensingSummaryPath



# Create Different Cuts Of Data For Steve
$VMTablePath = "c:\scheduledscripts\VCWReports\VMS-$((Get-Date).ToString('dd-MM-yyyy')).csv"

$ALLVMSCSV = "c:\scheduledscripts\VCWReports\VMS-ALL-$((Get-Date).ToString('dd-MM-yyyy')).csv"
$SkyscapeVMSCSV = "c:\scheduledscripts\VCWReports\VMS-Skyscape-$((Get-Date).ToString('dd-MM-yyyy')).csv"
$ClientVMSCSV = "c:\scheduledscripts\VCWReports\VMS-Client-$((Get-Date).ToString('dd-MM-yyyy')).csv"
$SkyscapeLinuxVMSCSV = "c:\scheduledscripts\VCWReports\VMS-Linux-Skyscape-$((Get-Date).ToString('dd-MM-yyyy')).csv"

$AllVMSXML = "c:\scheduledscripts\VCWReports\VMS-ALL-$((Get-Date).ToString('dd-MM-yyyy')).xml"
$SkyscapeVMSXML = "c:\scheduledscripts\VCWReports\VMS-Skyscape-$((Get-Date).ToString('dd-MM-yyyy')).xml"
$ClientVMSXML = "c:\scheduledscripts\VCWReports\VMS-Client-$((Get-Date).ToString('dd-MM-yyyy')).xml"
$SkyscapeLinuxVMSXML = "c:\scheduledscripts\VCWReports\VMS-Linux-Skyscape-$((Get-Date).ToString('dd-MM-yyyy')).xml"

$VMData = Import-Csv $VMTablePath
$VMData | Export-Csv $ALLVMSCSV -NoTypeInformation
$VMData | ?{$_.ResourcePool -notlike "*(*-*-*-*)*"} | Export-Csv $SkyscapeVMSCSV -NoTypeInformation 
$VMData | ?{$_.ResourcePool -like "*(*-*-*-*)*"} | Export-Csv $ClientVMSCSV -NoTypeInformation 
$VMData | ?{$_.ResourcePool -notlike "*(*-*-*-*)*"} | ?{$_.GuestFullName -notlike "*microsoft*"} | Export-Csv $SkyscapeLinuxVMSCSV -NoTypeInformation
Remove-Item -Path $VMTablePath -Force

($VMData | ConvertTo-Xml).Save($AllVMSXML)
($VMData | ?{$_.ResourcePool -notlike "*(*-*-*-*)*"} | ConvertTo-Xml).Save($SkyscapeVMSXML)
($VMData | ?{$_.ResourcePool -like "*(*-*-*-*)*"} | ConvertTo-Xml).Save($ClientVMSXML)
($VMData | ?{$_.ResourcePool -notlike "*(*-*-*-*)*"} | ?{$_.GuestFullName -notlike "*microsoft*"} | ConvertTo-XML).Save($SkyscapeLinuxVMSXML)






Function New-SINTQuery($Query)
{
	
	$username = 'svc_automation'
	$password = 'Password123#'
	$MySqlDatabase = 'sint_il2'
	$MySqlHost = '10.8.200.11'
	$ConnectionString = "server=" + $MySQLHost + ";port=3306;uid=" + $username + ";pwd=" + $password + ";database="+ $MySQLDatabase
	Try 
	{
		[void][System.Reflection.Assembly]::LoadFrom("C:\Program Files (x86)\MySQL\MySQL Connector Net 6.7.4\Assemblies\v2.0\MySql.Data.dll")
		$Connection = New-Object MySql.Data.MySqlClient.MySqlConnection
  		$Connection.ConnectionString = $ConnectionString
 		$Connection.Open()
		$Command = New-Object MySql.Data.MySqlClient.MySqlCommand($Query, $Connection)
  		$DataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($Command)
  		$DataSet = New-Object System.Data.DataSet
		$RecordCount = $dataAdapter.Fill($dataSet, "data") | Out-Null

	}
	Catch 
	{
 		Write-Host "ERROR : Unable to run query : $query `n$Error[0]"
	}

	Finally
	{
  		$Connection.Close()
  	}
	return $DataSet.Tables[0]
}

$MP = New-SINTQuery "select c.*,v.* from cis c inner join ci_field_values v on v.ci_id = c.id inner join ci_fields f on f.id = v.ci_field_id where f.field_name = 'Managed by Puppet';"

$FinalMPTable = @()
ForEach($M in $MP)
{
	$Holder = "" | Select Name,Description,Managed
	if($M.is_il -eq $true)
	{
		$Holder.Name = $M.label + "i2"
		$Holder.Description = $M.Description
		$Holder.Managed = $M.field_value
	}
	Else
	{
		$Holder.Name = $M.label
		$Holder.Description = $M.Description
		$Holder.Managed = $M.field_value
	}
	$FinalMPTable += $Holder
}

[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
$WS = New-Object System.Net.Webclient
$WS.Headers.Add("Authorization","Basic YWRtaW46RnUwQGM1JGMwXmIxQGQwJGEyXg==")
$WS.Headers.Add("Accept","application/json,version=2")
$URL = "https://10.8.224.10/api/hosts?per_page=1000"
$Response = $WS.Downloadstring($URL)
[System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$obj = $ser.DeserializeObject($Response)

$file = gci C:\ScheduledScripts\VCWReports\VMS-Linux-Skyscape*.csv | sort LastWriteTime | select -last 1
$importedCSV = Import-Csv $file 

$MissingFromForeman = @()

$ImportedCSV = $importedCSV | ?{$_.Name.Trim() -notlike "vsm*"} | ?{$_.Name.Trim() -notlike "vse*"}
ForEach($Line in $ImportedCSV)
{
	
	$Thisname = $Line.Name.Trim()
	$Found = ($Obj | ?{$_.host.name.split(".")[0].trim() -eq $Thisname} | Measure-Object).Count
	if($Found -gt 0)
	{
		Write-Host "Found it"	
	}
	Else
	{
		$CheckSINT = ($FinalMPTable | ?{$_.Managed -eq "No"} | ?{$_.Name -eq $ThisName} | Measure-Object).Count
		if($CheckSINT -eq 0)
		{
			$MissingFromForeman += $Line
		}
		Else
		{
			Write-Host "Not managed according to SINT"
		}
	}
}

$MissingXML = "c:\scheduledscripts\VCWReports\MissingInForeman-$((Get-Date).ToString('dd-MM-yyyy')).xml"
$MissingCSV = "c:\scheduledscripts\VCWReports\MissingInForeman-$((Get-Date).ToString('dd-MM-yyyy')).csv"
$MissingFromForeman | Export-Csv -Path $MissingCSV -NoTypeInformation
($MissingFromForeman | ConvertTo-Xml).Save($MissingXML)



$HTML = @"
<HTML>
<HEAD>
<style>


h1
{
font-size:1.8em;
text-align:left;
padding-top:5px;
padding-bottom:4px;
background-color:grey;
color:black;
}

a
{
    text-decoration: none !important;
}

table
{
font-family:"Trebuchet MS", Arial, Helvetica, sans-serif;
width:100%;
border-collapse:collapse;
}
table td, th 
{
font-size:0.8em;
border:1px solid #98bf21;
padding:3px 7px 2px 7px;
}
table th 
{
font-size:1em;
text-align:left;
padding-top:5px;
padding-bottom:4px;
background-color:#3B405E;
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
</style>

</HEAD>
<BODY>
<h1>Missing from Foreman i.e Puppet $((Get-Date).ToString('dd-MM-yyyy')) - ($(($MissingFromForeman | Measure-Object).Count))</h1>
"@

$HTML += "<table><tr><th>Name</th><th>VCW</th><th>GuestFullName</th><th>IPAddress</th><th>Description</th><th>Folder</th><th>PowerState</th></tr>"
ForEach($Line in $MissingFromForeman)
{
	$HTML += "<tr>"
	$HTML += "<td>$($Line.Name)</td>"
	$HTML += "<td>$($Line.VCW)</td>"
	$HTML += "<td>$($Line.GuestFullName)</td>"
	$HTML += "<td>$($Line.IPAddress)</td>"
	$HTML += "<td>$($Line.Description)</td>"
	$HTML += "<td>$($Line.Folder)</td>"
	$HTML += "<td>$($Line.PowerState)</td>"
	$HTML += "</tr>"

}

$HTML += "</table></body></html>"


#$ToList = @("prossi@skyscapecloud.com","srelf@skyscapecloud.com","EngineeringSupportTest@skyscapecloud.com")
$ToList = @("cblack@ukcloud.com") ##,"@skyscapecloud.com","EngineeringSupportTest@skyscapecloud.com")
$Subject = "Missing from Foreman i.e Puppet ($(($MissingFromForeman | Measure-Object).Count))"
$Body = $HTML
Send-MailMessage -SmtpServer smtp1.il2management.local -From "foremanreport@skyscapecloud.com" -To $ToList -Attachments $MissingCSV -BodyAsHtml -Body $Body -Subject $Subject





