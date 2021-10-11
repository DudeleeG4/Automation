Get-AllEdgeInfo

This script gathers as much information as possible for Edge Gateways and vApp edges via the vCloud API, without diving into individual firewall and NAT rules.

To run the script, you may need to edit the endpoint after the "Connect-CIServer" cmdlet as it's currently hardcoded as the last one I used (sorry).

Once you have edited the vCloud endpoint, you should be able to just hit run from whatever you are using (Powershell ISE, PowerGUI, Visual Studeio Code) as it will load all the VMWare PowerCLI modules automatically.


Problems:
. Slow
. Cannot differentiate between vApp Edges and vApp networks properly