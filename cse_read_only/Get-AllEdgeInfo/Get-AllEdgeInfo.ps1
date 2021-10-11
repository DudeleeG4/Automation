Get-Module -ListAvailable | Where {$_.Name -Like "VM*"} | Import-Module
Clear

Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

# Gather the user's client credentials
$Cred = Get-Credential -Message "Please enter your client credentials"
# Connect to vCloud (for the time being you will have to manually change this to be whichever vCloud instance you require)
Connect-CIServer api.vcd.z0000f.r00006.frn.portal.skyscapecloud.com -Credential $Cred

#Gather the vApp Edges and the Edge gateways and combine them together
$vAppEdges = Search-Cloud -QueryType AdminVAppNetwork
$Edges1 = Search-Cloud -QueryType EdgeGateway
Clear-Variable ("Edges") -ErrorAction SilentlyContinue
$Edges = $Edges1 += $vAppEdges

# Loop through all the gateways retrieved
$Report =@()
$Progress = 0
Foreach ($Edge in $Edges)
{
	$Progress ++
	Write-Progress -Id 1 -Activity "Gathering Edge Data" -PercentComplete ($Progress/$Edges.count*100)
	# Take the current edge and get the CIView object for that edge
    $Edgeviews = $Edge | Get-CIView
	# Check if that Edge gateway actually exists
	if (!$Edgeviews) 
	{
		Write-Warning "Edge Gateway with name $Edgeview not found"
	}
	# In case more than one Edge was retrieved from the Get-CIView cmdlet, start looping through them
	foreach ($Edgeview in $Edgeviews)
	{
		# Take the edge's name and store it in a variable
		$name = $Edgeview.name		
		# Using the edge's href in the URL, pull down the edge's XML using vCloud's API
		$webclient = New-Object system.net.webclient
		$webclient.Headers.Add("x-vcloud-authorization",$Edgeview.Client.SessionKey)
		$webclient.Headers.Add("accept",$EdgeView.Type + ";version=5.1")
		# Convert the raw XML into an XML object that powershell can work with
		[xml]$EGWConfXML = $webclient.DownloadString($EdgeView.href)
		# Check if the edge is an Edge Gateway or a vApp edge
		$IsEdge = $EGWConfXML.EdgeGateway
		$IsvAppEdge = $EGWConfXML.VAppNetwork
		If ($IsEdge){
			# Get default gateway for each interface
			Foreach ($Interface in $EGWConfXML.EdgeGateway.Configuration.GatewayInterfaces.GatewayInterface){
				if ($Interface.UseForDefaultRoute -eq 'true') {
					$DefaultGateway = $Interface.SubnetParticipation.Gateway
				}
			}
			$EdgeType = "EdgeGateway"
			# Get the VDC for the Edge
			$vdc = Get-OrgVdc -Id ($edge.PropertyList.Vdc) -ErrorAction SilentlyContinue
			# Create the report object
			$final = [PSCustomObject]@{
				"Edge Name" = $Name
				"Edge Type" = $EdgeType
				Description = $EGWConfXML.EdgeGateway.Description
				EdgeBacking = $EGWConfXML.EdgeGateway.GatewayBackingRef.gatewayId
				Interfaces = $EGWConfXML.EdgeGateway.Configuration.GatewayInterfaces.GatewayInterface
				Firewall = $EGWConfXML.EdgeGateway.Configuration.EdgegatewayServiceConfiguration.FirewallService.IsEnabled
				NAT = $EGWConfXML.EdgeGateway.Configuration.EdgegatewayServiceConfiguration.NatService.IsEnabled
				LoadBalancer = $EGWConfXML.EdgeGateway.Configuration.EdgegatewayServiceConfiguration.LoadBalancerService.IsEnabled
				DHCP = $EGWConfXML.EdgeGateway.Configuration.EdgegatewayServiceConfiguration.GatewayDHCPService.IsEnabled
				VPN = $EGWConfXML.EdgeGateway.Configuration.EdgegatewayServiceConfiguration.GatewayIpsecVpnService.IsEnabled
				Routing = $EGWConfXML.EdgeGateway.Configuration.EdgeGatewayServiceConfiguration.StaticRoutingService.IsEnabled
				Syslog = $EGWConfXML.EdgeGateway.Configuration.SyslogServerSettings.TenantSyslogServerSettings.IsEnabled
				Size = $EGWConfXML.EdgeGateway.Configuration.GatewayBackingConfig
				HA = $EGWConfXML.EdgeGateway.Configuration.HaEnabled
				DNSRelay = $EGWConfXML.EdgeGateway.Configuration.UseDefaultRouteForDnsRelay
				AdvancedNetworking = $EGWConfXML.EdgeGateway.Configuration.AdvancedNetworkingEnabled
				HAEnabled = $EGWConfXML.EdgeGateway.Configuration.HaEnabled
				Org = $Vdc.Org.Name
				TenantId = $Vdc.Org.Id.Split(':')[3]
				"OrgVDC/vApp" = $Vdc.Name
				OrgVDCId = $Vdc.Id.Split(':')[3]
				ProviderVDC = $Vdc.ProviderVDC.Name
				ProviderVDCId = $Vdc.ProviderVDC.Id.Split(':')[3]
				DefaultGateway = $DefaultGateway
			}
		}
		elseIf ($IsvAppEdge){	
			# Check if the edge is actually deployed, skip if it isn't
			if ($Edgeview.Deployed -notlike "True"){Continue}
			$EdgeType = "vAppEdge"
			# Get the vApp for the Edge
			$vapp = Get-CIVApp -Id ($Edge.VApp) -ErrorAction SilentlyContinue
			# Create the report object
			$final = [PSCustomObject]@{
				"Edge Name" = $Name
				"Edge Type" = $EdgeType
				Description = $EGWConfXML.VAppNetwork.Description
				EdgeBacking = "N/A"
				Interfaces = "N/A"
				Firewall = $EGWConfXML.vAppNetwork.Configuration.Features.FirewallService.IsEnabled
				NAT = $EGWConfXML.vAppNetwork.Configuration.Features.NATService.IsEnabled
				LoadBalancer = $EGWConfXML.vAppNetwork.Configuration.Features.LoadBalancerService.IsEnabled
				DHCP = $EGWConfXML.vAppNetwork.Configuration.Features.DHCPService.IsEnabled
				VPN = $EGWConfXML.vAppNetwork.Configuration.Features.IpsecVpnService.IsEnabled
				Routing = $EGWConfXML.vAppNetwork.Configuration.Features.StaticRoutingService.IsEnabled
				Syslog = $EGWConfXML.vAppNetwork.Configuration.SyslogServerSettings
				Size = "N/A"
				HA = $EGWConfXML.vAppNetwork.Configuration.HaEnabled
				DNSRelay = $EGWConfXML.EdgeGateway.Configuration.UseDefaultRouteForDnsRelay
				AdvancedNetworking = $EGWConfXML.EdgeGateway.Configuration.AdvancedNetworkingEnabled
				HAEnabled = $EGWConfXML.EdgeGateway.Configuration.HaEnabled
				Org = $vApp.Org.Name
				TenantId = $Edge.Org.Split(':')[3]
				"OrgVDC/vApp" = $Edge.vAppName
				OrgVDCId = "N/A"
				ProviderVDC = "N/A"
				ProviderVDCId = "N/A"
				DefaultGateway = $Edge.Gateway
			}
		}
		# Add the report object into the final report
		$Report += $final
	}
}


$Report | Export-Csv "C:\Scripts\Technology\CSE\AllEdgeInfo.csv" -NoTypeInformation
$Report | out-gridview

Disconnect-CIServer * -Confirm:$false
