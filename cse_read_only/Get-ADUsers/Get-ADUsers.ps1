Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

# Store the domain controller name in a variable
$Server = "dom00001i2"

# Start a new powershell session on that domain controller
$s = New-PSSession -computer $Server

# On the remote server, load the ActiveDirectory powershell module
Invoke-Command -Session $s -script {Import-Module ActiveDirectory}

# Import the powershell session over so that commands can be run from here
Import-PSSession -session $s -module ActiveDirectory

# Retrieve all users along with the date they were created
$Users = Get-ADUser -Filter * -Properties whencreated

# Export file
$Users | Export-Csv "C:\Scripts\Technology\CSE\ADUsersOutput.Csv" -NoTypeInformation
