Get-Module -ListAvailable | Where {$_.Name -Like "VM*"} | Import-Module
$report = $null
$report = @()	
$Date = Get-Date -Format "dd-MM-yyyy"
$Outpath = "C:\ScheduledScripts\Consolidation Reports\Consolidation Report IL2 $Date.csv"
$vCenterServers = @("vcw00001i2.il2management.local", "vcw00002i2.il2management.local", "vcw00003i2.il2management.local", "vcw00004i2.il2management.local", "vcw00005i2.il2management.local", "vcw00007i2.il2management.local", "vcw00008i2.il2management.local", "vcw00009i2.il2management.local", "vcw0000ai2.il2management.local", "vcv00004i2.pod00001.sys00001.il2management.local", "vcv00005i2.pod00002.sys00002.il2management.local", "vcv00006i2.pod00003.sys00004.il2management.local", "vcv00007i2.pod00003.sys00004.il2management.local", "vcv0000bi2.pod0000b.sys00005.il2management.local", "vcv0000ci2.pod0000b.sys00005.il2management.local", "vcv0000di2.pod0000f.sys00006.il2management.local", "vcv0000ei2.pod0000f.sys00006.il2management.local")

$unameS = "il2management\sciencelogicvcw"
$credsS = "As5^l2%j9^j1*u7*s9!"
	$userPasswordS = ConvertTo-SecureString "$credsS" -AsPlainText -Force
	$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $unameS,$userPasswordS
$gDate = Get-Date -Format "dd-MM-yyyy"
Connect-ViServer $vCenterServers -Credential $cred
$Filter = @{"Runtime.consolidationNeeded" ="True"}
$VMConsolidate = Get-View -ViewType VirtualMachine -Filter $Filter | Select Name

foreach ($VM in $VMConsolidate) 
{	
	$VirtualMachine = Get-VM -Name $VM.Name
	#$Snapshot = ""
	$Snapshot = Get-Snapshot -VM $VirtualMachine
	if (!$Snapshot)
	{
		$SSName = "No Snapshots Present"
		$SSSize = "VM running on Delta file"
	}
	else
	{
		$SSName = $Snapshot.Name
		$SSSize = $Snapshot.SizeGB	
	}
	
	$info = "" | Select vCenter, VM, vOrg, "Snapshot Name", "Snapshot Size GB"
	$info.vCenter = $VirtualMachine.Client.ConnectivityService.ServerAddress
	$info.VM = $VM.Name
	$info.vOrg = $VirtualMachine.Folder.Parent.Parent
	$info."Snapshot Name" = $SSName
	$info."Snapshot Size GB" = $SSSize
	
	$report += $info
}

#Clear-Variable -Name @("vCenterServers")
Disconnect-VIServer * -Confirm:$false
$Report | Export-Csv -NoTypeInformation $Outpath

Send-MailMessage -SmtpServer rly00001i2 -From "consolidationreport@ukcloud.com" -To "jlynch@skyscapecloud.com" -Cc "dandrews@ukcloud.com" -Subject "Consolidation Report Assured" -Body "Consolidation report attached" -Attachments $Outpath