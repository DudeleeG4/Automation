Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

Get-Module -ListAvailable | Where {$_.Name -like "vm*"} | Import-Module

# Ask user for client credentials to connect to vCloud
$Cred = Get-Credential

# Connect to vCloud (you will need to edit the vCloud API endpoint)
Connect-CIServer api.vcd.z0000f.r00006.frn.portal.skyscapecloud.com -Credential $Cred

# Retrieve all Edge Gateways and vApp networks, put them together into one array
$vAppEdges = Search-Cloud -QueryType AdminVAppNetwork
$Edges1 = Search-Cloud -QueryType EdgeGateway
Clear-Variable ("Edges") -ErrorAction SilentlyContinue
$Edges = $Edges1 += $vAppEdges

# Start looping through results
$Report =@()
$Progress = 0
Foreach ($Edge in $Edges)
{
	$Progress ++
	Write-Progress -Id 1 -Activity "Gathering Firewall Rules" -PercentComplete ($Progress/$Edges.count*100)
	
	# Get the CIView object for the edge gateways / vapp networks
    $Edgeviews = $Edge | Get-CIView
	if (!$Edgeviews){
		Write-Warning "Edge Gateway with name $Edgeview not found"
	}
	
	# Loop through every CIView object returned in case of multiples
	foreach ($Edgeview in $Edgeviews){
		$name = $Edgeview.name		
		
		# Construct and run API request
		$webclient = New-Object system.net.webclient
		$webclient.Headers.Add("x-vcloud-authorization",$Edgeview.Client.SessionKey)
		$webclient.Headers.Add("accept",$EdgeView.Type + ";version=5.1")
		[xml]$EGWConfXML = $webclient.DownloadString($EdgeView.href)
		
		# Check if the returned result is a vApp network or Edge Gateway
		$IsEdge = $EGWConfXML.EdgeGateway
		$IsvAppEdge = $EGWConfXML.VAppNetwork
		
		# If it is an Edge Gateway, retrieve the Firewall rules for it
		If ($IsEdge){
			$EdgeType = "EdgeGateway"
			
			# Check if the firewall is enabled, if not, skip this edge
			$FirewallEnabled = $EGWConfXML.EdgeGateway.Configuration.EdgeGatewayServiceConfiguration.FirewallService.IsEnabled
			if ($FirewallEnabled -like "true"){
				$FirewallRules = $EGWConfXML.EdgeGateway.Configuration.EdgegatewayServiceConfiguration.FirewallService.FirewallRule
			}else{
				Continue
			}
			
			# Gather the Protocols used for each rule
			$final = $firewallrules |% {
				if (!$_){Return}
				$ProtocolList = @()
				$Icmp = $_.Protocols.Icmp
				if ($Icmp){$ProtocolList += "ICMP"}
				$Tcp = $_.Protocols.Tcp
				if ($TCP){$ProtocolList += "TCP"}
				$Any = $_.Protocols.Any
				if ($Any){$ProtocolList += "Any"}
				$UDP = $_.Protocols.Udp
				if ($Udp){$ProtocolList += "UDP"}
				$Other = $_Protocols.Other
				if ($Other){$ProtocolList += $Other}
				
				# Build report object
				[PSCustomObject]@{
					"Edge Name" = $Name
					"Edge Type" = $EdgeType
					"Firewall Rule Enabled" = $_.IsEnabled
					"Protocol" = $ProtocolList -join " & "
					"Description" = $_.Description
					"Policy" = $_.Policy
					"Source IP" = $_.SourceIP -join ", "
					"Destination IP" = $_.DestinationIp -join ", "
					"XML" = $_
					}
				}
		}
		
		# If it is a vApp network, get the firewall rules for it
		elseIf ($IsvAppEdge){
		
			# Narrow down number of vApp networks to only those which are deployed
			if ($Edgeview.Deployed -notlike "True"){Continue}
			$EdgeType = "vApp Edge"
			
			# Check if the firewall is enabled and if not, skip this vApp Edge / Network (Only vApp edges will have firewalls enabled anyway)
			$FirewallEnabled = $EGWConfXML.VAppNetwork.Configuration.Features.FirewallService.IsEnabled
			if ($FirewallEnabled -like "True"){
				$FirewallRules = $EGWConfXML.VAppNetwork.Configuration.Features.FirewallService.FirewallRule
			}else{
				Continue
			}
			
			# Gather the Protocols used for each rule
			$final = $firewallrules |% {
				if (!$_){Return}
				$ProtocolList = @()
				$Icmp = $_.Protocols.Icmp
				if ($Icmp){$ProtocolList += "ICMP"}
				$Tcp = $_.Protocols.Tcp
				if ($TCP){$ProtocolList += "TCP"}
				$Any = $_.Protocols.Any
				if ($Any){$ProtocolList += "Any"}
				$UDP = $_.Protocols.Udp
				if ($Udp){$ProtocolList += "UDP"}
				$Other = $_Protocols.Other
				if ($Other){$ProtocolList += $Other}
				
				# Build report object
				[PSCustomObject]@{
					"Edge Name" = $Name
					"Edge Type" = $EdgeType
					"Firewall Rule Enabled" = $_.IsEnabled
					"Protocol" = $ProtocolList -join " & "
					"Description" = $_.Description
					"Policy" = $_.Policy
					"Source IP" = $_.SourceIP -join ", "
					"Destination IP" = $_.DestinationIp -join ", "
					"XML" = $_
				}
			}	
		}
		$Report += $final
	}
}

# Export report and tell user where it is, prompt for input to exit
$Report | Export-Csv "C:\Scripts\Technology\CSE\FirewallRules.csv" -NoTypeInformation
Write-Host "Done! Report is at -> C:\Scripts\Technology\CSE\FirewallRules.csv"
Read-Host -Prompt "Please press enter to exit"

Disconnect-CIServer * -Confirm:$false
