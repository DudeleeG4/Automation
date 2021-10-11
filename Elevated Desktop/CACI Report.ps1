Connect-CIServer api.vcd.portal.skyscapecloud.gsi.gov.uk
$Orgs = Get-Org | Where {($_.name -like "8-22*") -or ($_.name -like "8-42*") -or ($_.name -like "8-59*") -or ($_.name -like "8-83*") -or ($_.name -like "8-88*") -or ($_.name -like "8-109*")}
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
