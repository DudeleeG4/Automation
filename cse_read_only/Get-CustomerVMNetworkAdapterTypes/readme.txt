Get-CustomerVMNetworkAdapterTypes

This is a script that I THINK I might have written for customer use as well as internal use. The idea is to retrieve the Network Adapter types for a chosen selection of VMs. The script will give options to narrow the search as much as possible.

i.e it will allow the user to specify an OrgVDC within their Organisation, and vApp(s) within this OrgVDC. If an OrgVDC is not chosen, all VMs in the Org will be displayed and the user will be asked to pick from the list. 

To run the script, navigate to a jumpbox with PowerCLi installed which has access to the Assured and Elevated environments, then right-click the script and select "Run with powershell"