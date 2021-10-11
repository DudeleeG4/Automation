Get-HAEvents.ps1

The purpose of this script is to gather all the VMs which have been restarted on other hosts during a vSphere High Availability failover event.
It will list the OrgVCD (called "Resource Pool" in the output) and the Organisation (vOrg) of the VM in the output.

To run the script, right-click and select "Run with powershell".

It will prompt you to enter the vCenter, do so in the format "vcw00003i2".
For PV2 you will need to put it in the format "vcv00003i3.pod0000d.sys00005.il3management.local"

Then, it will prompt you to select a Date. (Obviously you will want to select the date on which you suspect HA events occurred)

It will export the output into the NOC scripts folder on the current jumpbox at "C:\Scripts\Technology\NOC\HA Events"