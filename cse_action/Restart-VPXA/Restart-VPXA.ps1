#This script will connect to a host selected by the user and will reconnect the host to the vcenter and will restart the vpxa service


Write-Output "Hi, this script will restart the vpxa on a selected supermicro host, please be ready to input the host's credentials when requested."
$ESXiHost = read-host "Please enter the name of the host (example: esx00xxxix.ilxmanagement.local): "
Connect-VIServer -Server $ESXiHost 
Set-VMHost -VMHost $ESXiHost -State "Connected"
Get-VMHostService -VMHost $ESXiHost | 
where {$_.Key -eq "vpxa"} | 
Restart-VMHostService -Confirm:$false
Disconnect-VIServer * -Confirm:$false