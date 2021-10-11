Get-DuplicateVTEPIPs

The purpose of this script is to check that none of the IP addresses assigned to the vmk4 network adapters of ESXi hosts 
(the NIC responsible for VXLAN traffic) are duplicates of any other hosts. This can cause networking problems with 
customer VMs that are difficult to troubleshoot.

