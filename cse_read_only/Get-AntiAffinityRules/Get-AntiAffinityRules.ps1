Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

# Connect to the vCentre
Connect-VIServer -Server vcw0000xxx
 
# Amend the directory and cluster name. Put the cluster name in "CLUSTERNAME"
$outfile = "C:\Users\Your directory here\rules.txt"
$clusterName = CLUSTERNAME
$rules = get-cluster -Name $clusterName | Get-DrsRule
if($rules){
     foreach($rule in $rules){
          $line = (Get-View -Id $rule.ClusterId).Name
          $line += ("," + $rule.Name + "," + $rule.Enabled + "," + $rule.KeepTogether)
          foreach($vmId in $rule.VMIds){
               $line += ("," + (Get-View -Id $vmId).Name)
          }
          $line | Out-file -Append $outfile
     }
}
