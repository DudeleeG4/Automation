Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

iex "python read_xtraction.py"
Read-Host -Prompt "Press Enter to exit"
