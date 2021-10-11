This script allows you to easily retrieve all the Edge gateway firewall rules for an Edge.
It is much quicker than using the vCloud API as it used the NSX API instead. The results are put into an easily readable
.csv file rather than a multi-level object in an XML file, so the results are much nicer to view. Allows easy filtering
of customer edge rules when there are hundreds of rules to look through.

To run the script, you must have these modules loaded:
UKCloud.NSX
UKCloud.Support
PowerCLI (although UKCloud.Support will load PowerCLI for you anyway)

Currently, this will not work with PV2 vCenters as they
are not set up for Domain integration, so the user's SU credentials are insufficient to login.