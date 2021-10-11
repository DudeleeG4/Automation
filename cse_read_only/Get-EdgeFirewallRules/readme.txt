Get-EdgeFirewallRules

The purpose of this script is to pull off every firewall rule present on Edge gateways and vApp edges for a given vCloud instance.

This can take a very long time to run on PV1 as there are a huge amount of edges and vApp networks to sift through.

To run the script, you will want to edit the vCloud API endpoint used, and then you should simply be able to run the script from the jumpbox which has access to the vCloud instance you specify, plus has PowerCLI installed.

Problems:
Slow
Does not match edges up to their VMs in vCenter, making it's usefullness limited