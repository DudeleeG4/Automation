Remove-AccountLimit.ps1

Summary:
This script removes the limit placed on Enterprise customers' accounts upon them passing the verification stage.

Description:
This script will first ask the user to either select their security domain and then prompt them for their SINT token -
however if they are on the Assured domain it will just prompt them for their Assured SINT token.
The script then asks the user to enter the Account number of the account they wish to remove the limit on.
It then retrieves the Account from the EstateAPI and prints it to pipeline for user review before continuing.
Upon continuing, the script will then set the "Limited" field on the Account to "false" within the EstateAPI.
Finally, it will show the new status of the account and then prompt the user to press enter to exit the script.

Running the Script:
The script can be run from either the internal.local domain (provided the user has the correct modules installed 
and selects "Assured" at the first prompt"), or from the Assured Farnborough Jumpbox.
All one has to do is right-click > run with powershell.