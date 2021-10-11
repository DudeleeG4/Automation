Get-PinnedVMs

This script is designed to find all the VMs on the platform which are pinned to hosts and are not Zerto VRAs or a part of GEL's HPC VMs.
It will return the VM's name, what vCenter they are on, what DRS rule they are in, which host they are pinned to, which cluster the host 
is in and whether the rule is mandatory or not.

The purpose of this is to find any VMs which are set to "Must" instead of "Should" as we should not have any VMs that are pinned to hosts under
a "Must" rule, as this will cause problems if we need to put hosts into maintenance mode.

To run the script, you need to go on a jumpbox with access to either the Assured or Elevated platforms which also has PowerCLI installed. Then, 
you can simply right-click the script and select "Run with powershell" and the script will do the rest. Results will be displayed to the screen.