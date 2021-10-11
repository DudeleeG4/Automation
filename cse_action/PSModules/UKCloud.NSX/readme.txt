UKCloud.NSX.psm1


Pre-Requisites:
You must have the VMWare PowerCLI modules installed in order for this module to function.
You must have UKCloud.Support module (or the equivilant estate API modules i.e VMWare and SINT) installed in order for this module to function.

Purpose:
This is a powershell module that allows more precise use of the NSX API. Intended as an in-house alternative to PowerNSX


Installation:
To install the module, you can copy the UKCloud.Support folder into the powershell custom module folder on any windows machine at:
"C:\Program Files\WindowsPowerShell\Modules"

Once you have copied the UKCloud.NSX folder into this directory, you can load the module in a powershell session by running:
Import-Module UKCloud.NSX

!!Do not install onto any jump box or production environment without authorisation and an approved change request!!

