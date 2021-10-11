Get-VMDiskData.ps1

The purpose of this script is to get the actual disk data for a given VM and the datastores which those disks reside on.



It outputs the used space, provisioned space and uncommitted space of the hard disks, as well as the used space, provisioned space, total space and free space of the datastore that each disk is on.



To run the script, from a jumpbox, right-click and select "Run with powershell". 

It will then prompt you to enter a vCenter, enter it in the format "vcw00002i2".

It will then ask for your management credentials to log in to the vCenter.

Then, a list of every VM in the vCenter will be displayed to the screen. Select which VM(s) you require and press ok.



The results will then be displayed on screen - select which ones you want and press OK to export the selected to your desktop as a CSV.