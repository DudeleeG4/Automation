UKCloud.EstateAPI.psm1

Pre-Requisites:
You must have the UKCloud.Support.psm1 module installed for this module to function.



Purpose:
This is a module built to allow easy use of the customer Estate API. It contains no hardcoded credentials and will ask for a sint API token for it's authentication.



Installation:
To install the module, you can copy the UKCloud.EstateAPI folder into the powershell custom module folder on any windows machine at:
"C:\Program Files\WindowsPowerShell\Modules"

Once you have copied the UKCloud.EstateAPI folder into this directory, you can load the module in a powershell session by running:
Import-Module UKCloud.EstateAPI



Use:
Many of the functions in this module are just authentication / actual access to the estate api, therefore they don't need to be called manually. The useful ones so far are:

Select-EApiSecurityDomain
This only needs to be run if you need to change security domain within the estate API, otherwise the other cmdlets will all prompt you to connect to a security domain if you are not already.

This will prompt the user which security domain they wish to use for the estate api. The options are "Assured, Elevated, Combined". You will need to enter your SINT API token for authentication.
You will need to use your Assured SINT token for the assured security domain, and your Elevated SINT token for the elevated and combined security domains. This function will then get the appropriate
authentication token from the estate api.

Get-EApiService:
This pulls down the "Service" type and it's associated fields from the estate API. It accepts a "Company Domain Identifier" and/or a "Account Domain Identifier" as parameters, allowing you to filter
the query to what you want. Both of these can be passed via pipeline in an object where these are properties with the same name.

Get-EApiCompany:
This pulls down the "Company" type and it's associated fields from the estate API. It accepts a "Company Domain Identifier" and/or a "Account Domain Identifier" as parameters, allowing you to filter
the query to what you want. Both of these can be passed via pipeline in an object where these are properties with the same name.
In addition, you can pass an "Account" EstateAPI object as a parameter (either named or via pipeline) to this function and it will retrieve the company for that account.

Get-EApiAccount:
This pulls down the "Account" type and it's associated fields from the estate API. It accepts a "Company Domain Identifier" and/or a "Account Domain Identifier" as parameters, allowing you to filter
the query to what you want. Both of these can be passed via pipeline in an object where these are properties with the same name.
In addition, you can pass a "Company" EstateAPI object as a parameter (either named or via pipeline) to this function and it will retrieve the accounts for that company.

Get-EApiVM:
This pulls down the "vcloud_vm" type from the estate api. There are many filters available, but they have only just been added to the estate API upon my request. As such, I have only added one as a parameter
so far, more work needs to be done to add all the possible filters as parameters. The parameter is "Name" and allows you to pull down a VM by name. This can be passed via pipeline in an object where this is
a property of the same name.

Get-EApivApp:
This pulls down the "vcloud_vapp" type from the estate api. Currently there are no filters available for this in the estateAPI itself so there are no parameters, as so it will just retrieve all of them.

Get-EApiVdc:
This pulls down the "vcloud_vdc" type from the estate api. Currently there are no filters available for this in the estateAPI itself so there are no parameters, as so it will just retrieve all of them.
