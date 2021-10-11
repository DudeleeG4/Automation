Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

#Connect-VIServer -Server vcw00003i2
#Connect-VIServer -Server vcw00003i3
 
 
$rules = Get-DrsRecommendation
$vms = @()
$hostRecommendations = @()
$currentHosts = @()
foreach($rule in $rules){
    $vms += $rule .Recommendation.Split("'" )[1]
    $currentHosts += $rule .Recommendation.Split("'" )[3]
    $hostRecommendations += $rule .Recommendation.Split("'" )[5]
}
 
 
$list = @()
$hostRecommendationIterator = 0
foreach($vm in $vms){
    if (($vm.Endswith("0" )) - or ($vm .Endswith("1"))){
        write-host "found vSE...   " $vm
        $VDC_Name = "vSE"
        $Org_ID = "vSE"
        $Vm_Name = $vm.Trim()
    } else {
        $id = $vm.Substring($vm.Length-38 )
        $id = $id.Insert( $id.length ,"*")
        $id = $id.Insert( 0,"*" )
        write-host "searching for...   " $id
        $vm = Get-VM -Name $id
        write-host "found:    "   $vm
        $VDC_Name = $vm.Folder. Parent.name
        $Org_ID = $vm.Folder. Parent.Parent .name
        $Vm_Name = $vm.name
    } 
 
 
    $obj = New-Object System .Object
    $obj | Add-Member -type NoteProperty -name ORG -value $Org_ID
    $obj | Add-Member -type NoteProperty -name VDC -value $VDC_Name
    $obj | Add-Member -type NoteProperty -name VM -value $Vm_Name
    $obj | Add-Member -type NoteProperty -name CurrentHost -value $currentHosts[$hostRecommendationIterator ]
    $obj | Add-Member -type NoteProperty -name MoveToHost -value $hostRecommendations[$hostRecommendationIterator ]
    $list += $obj
    $hostRecommendationIterator++
}
 
 
### !!! Change the path specific to yourself !!! ###
$list | export-csv -path C:\Users\ ############\documents\drs.csv
