UKCloud.Support.psm1


Pre-Requisites:
You must have the VMWare PowerCLI modules installed in order for this module to function.


Purpose:
This is a powershell module with some useful functions that make things easier when using powershell within UKCloud's environment.
It is primarily written for the support team.
For instance, it has a function that allows you to automatically connect to all active customer facing vCenters or vCloud instances.


Installation:
To install the module, you can copy the UKCloud.Support folder into the powershell custom module folder on any windows machine at:
"C:\Program Files\WindowsPowerShell\Modules"

Once you have copied the UKCloud.Support folder into this directory, you can load the module in a powershell session by running:
Import-Module UKCloud.Support