Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

$Folders = Get-ChildItem "C:\Users"

$Results = $Folders |% {
$Size = Get-ChildItem $_.FullName -Recurse | Measure-Object -Property length -sum
	[PSCustomObject]@{
		User = $_.Name
		"Size MB" = $Size.Sum / 1000000
	}
}

$Results | Out-GridView
