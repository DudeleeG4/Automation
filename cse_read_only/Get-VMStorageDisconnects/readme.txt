VMs Lost Storage.ps1

The purpose of this script is to identify which VMs may have gone into a read-only state due to vCenter storage disconnects.

It attempts to do this by retrieving all of the hosts which report a storage disconnect, retrieving the datastores which they reported a loss of storage to, then retrieving the
VMs which were running on those hosts and datastores.

This list is then filtered down to show only those VMs which have not been powered off or restarted since THE EVENT.

To run the script, right-click and select "run with powershell". You will then be prompted to select a date you want to check for disconnects.

The output is VM name, vApp, OrgVDC, Organisation. The results will be output to a CSV on the user's desktop.