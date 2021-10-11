Get-VMvOrgsfromhost.ps1

The purpose of this script is to allow someone who is unfamiliar with scripting to easily pull off a list
of VMs that reside on a given host.

The output is simply a list of VM names and their vOrgs.

To run the script, right-click and select "run with powershell" from a jumpbox with access to the desired vCenter.

The outputs will be exported to the CSE scripts folder at "C:\Scripts\Technology\CSE\VMsOnHost.csv"