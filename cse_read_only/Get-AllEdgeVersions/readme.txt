Get-AllEdgeVersions

This script gathers 3 things:

It will get the NSX Edge version for all Edges on customer facing production vCenters.

It will get their names as they are shown in the vCenter, which does not always necessarily match up with their names in vCloud.

It will also show the vCenter they are on.


The version reported will be the same as the version reported in the vCenter on the VM object for the edge, under the "vApp Details"
pane on the summary tab - NOT from NSX manager itself. This is because we have experienced issues whereby NSX actually lags behind in
reporting the current version. In short, getting this information from the vCenter is actually more accurate than getting it from
NSX itself.


To run the script, simply right-click the script and select "Run with powershell". You will then be prompted with credentials to log
in to the vCenters - this will be your IL2/IL3 management credentials (depending on which platform you are running it on).

Once the script is complete, it will tell you where you can find the output.
