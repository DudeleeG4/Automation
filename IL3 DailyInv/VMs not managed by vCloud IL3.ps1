clear

Get-Module -ListAvailable | Where-Object {$_.Name -like "VMware*"}  | ForEach-Object {import-module -name $_}

$DesktopPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
$unameS = "il3management\sciencelogicvcw"
$credsS = 'Sd4^l6$o9*z8^t7%r1!'
	$userPasswordS = ConvertTo-SecureString "$credsS" -AsPlainText -Force
	$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $unameS,$userPasswordS

$vCenterServers = @("vcw00002i3.il3management.local","vcw00003i3.il3management.local","vcw00005i3.il3management.local","vcw00007i3.il3management.local","vcw00008i3.il3management.local", "vcv00003i3.pod0000d.sys00005.il3management.local", "vcv00005i3.pod00012.sys00006.il3management.local")
write-host Connecting
$report = @()
Connect-VIServer -Server $vCenterServers -Credential $cred  -ErrorAction 'silentlycontinue'


$VMs = Get-VM | Where-Object {$_.ExtensionData.Config.ManagedBy.ExtensionKey -notmatch "vcloud"} | Where-Object {$_.Name -notlike "NSX_Controller*"} | Where-Object {$_.Name -notlike "Z-VRA*"} | where-object {$_.Name -notlike "vse*"} | Where-Object {$_.Name -notlike "avp*"} | Where-Object {$_.Name -notlike "svm*"}
foreach ($VM in $VMs){
		$VC = $VM.ExtensionData.Client.ServiceUrl
		$VC = $VC -split "/" | Select -Index 2
		$info = "" | select vCenter, VM, "Managed By", "Power State", "Folder 1", "Folder 2", "Folder 3", "Folder 4" 
		$info.vCenter = $VC
		$info.VM = $VM.Name
		$ManagedBy = $VM.ExtensionData.Config.ManagedBy.ExtensionKey
		if (!$ManagedBy) {$info."Managed By" = "Nothing"}
		else {$info."Managed By" = $VM.ExtensionData.Config.ManagedBy.ExtensionKey}
		$info."Power State" = $VM.PowerState
		$info."Folder 1" = $vm.Folder.Name
        $info."Folder 2" = $VM.Folder.Parent.Name
        $info."Folder 3" = $VM.Folder.Parent.Parent.Name
        $info."Folder 4" = $VM.Folder.Parent.Parent.Parent.Name
		$report += $info
		}


$final = $report

$OutputFileCSV = "C:\inetpub\wwwroot\VMsNotManagedByvCloud.csv"
$Final | Sort vCenter | Export-Csv -path $OutputFileCSV -Force -NoTypeInformation


$gDate = get-date -Format dd-MM-yyyy

$Hbody = "Find report on apw00029i3 at C:\inetpub\wwwroot\VMsNotManagedByvCloud.csv"


Send-MailMessage -To "support@ukcloud.com" -From "VMsNotManagedByvCloudIL3@ukcloud.com" -Cc "dandrews@ukcloud.com" -Bcc "molejar@ukcloud.com"  -Subject "VMs not managed by vCloud IL3 $gDate" -SmtpServer 10.72.81.30 -Body $HBody 

Disconnect-VIServer * -Confirm:$false -ErrorAction 'SilentlyContinue'



