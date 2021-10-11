$Server = "dom00001i2"
$User = Read-Host -Prompt "Username:"
$s = New-PSSession -computer $Server
Invoke-Command -Session $s -script {Import-Module ActiveDirectory}
Import-PSSession -session $s -module ActiveDirectory
Get-ADUser