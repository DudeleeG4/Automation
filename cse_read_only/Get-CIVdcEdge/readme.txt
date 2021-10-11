Get-CIVdcEdge.ps1

This is really a function which I've written to pull down some data from vCloud's API in XML format. It will retrieve data about Edge Gateways, and filter the results by OrgVdc(s).

This shouldn't really be run as standalone as it is more of a function that a script but if you wish to run it, you will need to jump on a jumpbox and load up a powerCLI environment. Then, copy and paste the function and run it to load the
function into memory - then connect to a vCloud instance via the Connect-CIServer cmdlet. finally, run "Get-OrgVdc" to get some org VDCs and pipe those OrgVdcs into this function to get some results.