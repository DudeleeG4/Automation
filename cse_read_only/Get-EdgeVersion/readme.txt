Get-EdgeVersion

The purpose of this script is to simply retrieve every single edge gateway from the specified vCenters, and then to retrieve the version of the edge as it appears in NSX manager. i.e 5.5.4, 6.2.7, 6.2.8 etc...

To run the script, you will probably want to edit which vCenters are being connected to. Then, you should just be able to run it from any jumpbox which has access to the vCenters you specify, and has PowerCLI installed.

Problems:
I could provide a bit more data
VSE VM names in vCenter do not always match up to their names in vCloud.