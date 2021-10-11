Connect-CIServer api.vcd.portal.skyscapecloud.com
$Orgs = Get-Org | Where {($_.name -like "149-*") -and ($_.name -notlike "149-431*") -and ($_.name -notlike "149-301*")}
$Report = Foreach ($Org in $Orgs){
    $OrgVDCs = $Org | Get-OrgVdc
    Foreach ($OrgVDC in $OrgVDCs){
        $VMs = $OrgVDC | Get-CIVM
        foreach ($VM in $VMs){
            $Disks = $VMs[0].ExtensionData.getvirtualhardwaresection().Item | Where { $_.Description -like “Hard Disk”}
            Foreach ($Disk in $Disks){
                [PSCustomObject]@{
                    VM = $VM.Name
                    OS = $VM.GuestOSFullName
                    "CPU Count" = $VM.CpuCount
                    "Memory (GB)" = $VM.MemoryGB
                    HardDisk = $Disk.ElementName
                    "HardDiskSize (GB)" = $Disk.VirtualQuantity.Value/1GB
                    Org = $Org.FullName
                    VDC = $OrgVDC.Name
                }
            }
        }
    }
}

$Report | Export-Csv "C:\Users\sudandrews\Desktop\CACIReport.csv" -NoTypeInformation