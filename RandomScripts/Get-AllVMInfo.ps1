$OutPath = ([Environment]::GetFolderPath("Desktop")) + "\VMReport " + (Get-Date -Format dd-MM-yyyy) + ".csv"

$vCenters = @("vcw00002i2",
"vcw00003i2",
"vcw00005i2",
"vcw00007i2",
"vcw00008i2",
"vcw00009i2",
"vcw0000ai2",
"vcv00004i2.pod00001.sys00001.il2management.local",
"vcv00005i2.pod00002.sys00002.il2management.local",
"vcv00007i2.pod00003.sys00004.il2management.local",
"vcv0000ci2.pod0000b.sys00005.il2management.local",
"vcv0000ei2.pod0000f.sys00006.il2management.local",
"vcv00024i2.pod0002d.sys00013.il2management.local",
"vcv00028i2.pod0002e.sys00014.il2management.local"
)

$Creds = Get-Credential -Message "Please enter your management credentials:"

Connect-VIServer $vCenters -Credential $Creds

$VMs = Get-VM

$Report = $VMs | Select Name, ResourcePool, UsedSpaceGB, ProvisionedSpaceGB, PowerState, NumCPU, MemoryGB

$Report | Export-Csv $OutPath -NoTypeInformation

Disconnect-VIServer * -Confirm:$false