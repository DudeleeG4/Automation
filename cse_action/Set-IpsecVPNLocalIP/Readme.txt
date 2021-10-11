#Change Local IP of IPSEC VPN

This script has been imported from confluence;

https://confluence.il2management.local/display/BAC/Change+Local+IP+of+IPSEC+VPN


This details a script that can be used to change over the Local IP of an IPSEC VPN.
It uses the vCloud API to do this. When it asks for you credentials, please enter: username = "su_____@system", password = il2mgmt
Triple check before running that the details are correct.

#Params 
$edgeName is the edge you want to search for
$externalNetwork is the external network name the edge is attached to
$tunnelName is the name of the VPN tunnel
$IP is the public IP you wish to change the tunnel to be
when asked for your credentials: username = su_____@system password = il2mgmt

$externalNetwork = "nft002bbi2"
$edgeName = "nft002bbi2-1"
$tunnelName = "WTG_VPN"
$IP = "51.179.196.178"

