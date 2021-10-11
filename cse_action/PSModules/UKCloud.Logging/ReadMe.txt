UKCloud.Logging.psm1

Pre-Requisites:
None

Purpose:
This powershell module is designed to log to a logfile on C:\Scripts at the earliest possible convenience whenever a script, 
which the module is called in, is run. This is to make the auditing of most commonly run scripts possible as part of the 
Tactical Automation process.

Installation:
*1 - To install the module on other jumpboxes or any windows machine, you can copy the UKCloud.Logging folder into the powershell custom module folder at:
"C:\Program Files\WindowsPowerShell\Modules".
*2 - Once you have copied the UKCloud.Logging folder into this directory, you can load the module in a powershell session by running:
"Import-Module UKCloud.Logging".

!!Do not install onto any jump box or production environment without authorisation and an approved change request!!