Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

Connect-VIServer vcw00002i3
$Datastores = Get-Datastore 

$Datastores |% {
	[PSCustomObject]@{
		Datastore = $_.Name
		Capacity = $_.CapacityGB
		Freespace = [int]$_.FreeSpaceGB
	}
} | Sort Freespace -Descending | Out-File "C:\Scripts\Technology\CSE\Datastores.txt"
