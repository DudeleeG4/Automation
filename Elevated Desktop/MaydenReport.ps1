Connect-CIServer vcloud

$OrgVDC = Get-OrgVdc -Name "Office for National Statistics (IL3-PROD-ENHANCED)"

$VMs = $OrgVDC | Get-CIVM

$DateTime = Get-Date -format ddMMhhmm

if ($VMs){
    $Filepath = "C:\Users\sudandrews\Desktop\Mayden VM Reports\MaydenVMReport$DateTime.csv"

    $VMs | Export-Csv $Filepath -NoTypeInformation
}else{
    $Filepath = "C:\Users\sudandrews\Desktop\Mayden VM Reports\MaydenVMReport$DateTime.txt"
    "The script failed to retrieve any VMs" | Out-File $Filepath
}