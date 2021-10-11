$Server = "dom00001i3"
$User = Read-Host -Prompt "Username:"
$s = New-PSSession -computer $Server
Invoke-Command -Session $s -script {Import-Module ActiveDirectory}
Import-PSSession -session $s -module ActiveDirectory
Set-ADAccountPassword $User -Reset