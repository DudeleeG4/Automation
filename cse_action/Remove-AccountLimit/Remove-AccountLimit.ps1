<#
.SYNOPSIS
    This script removes the limit placed on Enterprise customers' accounts upon them passing the verification stage.

.DESCRIPTION
    This script asks the user to enter the Account number of the account they wish to remove the limit on.
	It then retrieves the Account from the EstateAPI and prints it to the console for user review before continuing.
	Upon continuing, the script will then set the "Limited" field on the Account to "false" within the EstateAPI.
	Finally, it will show the new status of the account and then prompt the user to press enter to exit the script.

.PREREQUISITES
	Please ensure you have installed these two modules before running this script:
	UKCloud.Support
	UKCloud.EstateAPI
	
	Both of the modules can be found in the CSE bitbucket under the cse_action repo, in the "PSModules" folder.
	
.NOTES
	Author: Dudley Andrews
	Last Update: 21/12/2018
#>
Try{
	Get-Module -ListAvailable | Where {$_.Name -like "UKCloud.EstateAPI"} | Import-Module
	Get-Module -ListAvailable | Where {$_.Name -like "UKCloud.Support"} | Import-Module
}Catch{
	Write-Error -Message "Pre-requisite modules not installed!"
	Write-Host -ForegroundColor Yellow "Please install the prerequisite modules: UKCloud.Support & UKCloud.EstateAPI"
}
# Prompt user to enter their IL2 Sint API key
Select-EApiSecurityDomain

# Prompt user to enter the account number
Do{
	$AccountNumber = Read-Host -Prompt "Enter the account number:"
	if (!$AccountNumber){Write-Error -Message "No account number entered."}
}Until(
	$AccountNumber
)

# Print $AccountNumber to pipeline
Write-Host "Account Number: $AccountNumber"

# Get the Account specified from the EstateAPI and spit it out to the pipeline for user review
$Account = Get-EApiAccount -AccountDomainIdentifier $AccountNumber
$Account

# Ask the user if this is the account they wanted
$Read = Read-Host -Prompt "Is this the correct account? [Default:Yes] Yes/No"
if (!$Read){$Read = "Yes"}

# If this is the correct account, disable the limit on the account, if it isnt exit the script
If ($Read -match "Yes"){
	Try{
		$Account | Set-EApiAccountLimit -Limited "false"
	}Catch{
		Write-Host -ForegroundColor Red "Unable to change account limit."
	}
	# Get the specified Account again and show it's value
	Write-Host -ForegroundColor Green "Account $AccountNumber limit removed."
	Get-EApiAccount -AccountDomainIdentifier $AccountNumber
}

# Allow the user to exit by pressing enter
Read-Host -Prompt "Press Enter to Exit"
Exit