Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}
function Choice-Prompt
{
	Param (
	[Parameter(Mandatory=$true)]$Title,
	[Parameter(Mandatory=$true)]$Message,
	[Parameter(Mandatory=$true)]$Options
	)
	process
	{	
	$defaultchoice = 0
	$host.UI.PromptForChoice($Title , $Message , $Options, $defaultchoice)
	}
}

##################################################################################################################################################

[Reflection.Assembly]::LoadWithPartialName("System.Web")
$Length = Read-Host -Prompt "How long do you want the password? (e.g 12)"
Do{
	do { $PWD = [System.Web.Security.Membership]::GeneratePassword($Length,2)} until (($PWD -match "\d") -and ($PWD -cmatch "[a-z]") -and ($PWD -cmatch "[A-Z]"))
	Write-Host ""
	Write-Host "Password '$PWD' copied to clipboard."
	Set-Clipboard $PWD 
	$Choice = Choice-Prompt -Title "Choice:" -Message "Do you want to continue?" -Options "Yes", "No"
}
Until($Choice -match "No")

Read-Host -Prompt "Press Enter to exit"
