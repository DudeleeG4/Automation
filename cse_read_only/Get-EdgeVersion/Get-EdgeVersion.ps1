Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

Get-Module -ListAvailable | Where {$_.Name -like "VM*"} | Import-Module
Clear

# Prompt user for management credentials
$Cred = Get-Credential

# Log on to vCenters
Connect-VIServer @("vcw00002i2","vcw00003i2","vcw00005i2","vcw00007i2","vcw00008i2","vcw00009i2","vcw0000ai2") -Credential $Cred
$Report = @()

# Use Get-View to find all vshield edge VMs
$filter = @{Name="vse-*"}
$viewvm = Get-View -ViewType VirtualMachine -Filter $filter

# Output just the VM's name and it's Version
$output = $viewvm | select Name, @{N="Version";E={$_.Config.VAppConfig.Product[0].Version}}
$output
$Report += $Output

# Export the Csv
$Report | Export-Csv "C:\Scripts\Technology\CSE\AllEdge55X Report.csv"

Disconnect-VIServer * -Confirm:$false
