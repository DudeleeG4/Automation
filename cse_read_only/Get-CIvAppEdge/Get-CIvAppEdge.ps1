Get-Module -ListAvailable | Where {$_.Name -like "vm*"} | Import-Module
Clear

Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

# Prompt user for client credentials
$Cred = Get-Credential -Message "Please enter your client credentials"
# Connet to vCloud
Connect-CIServer api.vcd.portal.skyscapecloud.com -Credential $Cred
# Pull down the vApp network objects using  powerCLI
Clear-Variable ("Edges") -ErrorAction SilentlyContinue
$Edges = Search-Cloud -QueryType AdminVAppNetwork

$Report =@()
$Progress = 0
Foreach ($Edge in $Edges)
{
	$Progress ++
	Write-Progress -Id 1 -Activity "Gathering vApp Edge Data" -PercentComplete ($Progress/$Edges.count*100)
	
	# Get the CIView object for the vApp networks
    $Edgeviews = $Edge | Get-CIView
	if (!$Edgeviews){
		Write-Warning "vApp network with name $Edgeview not found"
	}
	
	# Loop through vApp edges in case multiple were returned 
	foreach ($Edgeview in $Edgeviews){
		$name = $Edgeview.name
		
		# Pull down the XML objects for the vApp Networks
		$webclient = New-Object system.net.webclient
		$webclient.Headers.Add("x-vcloud-authorization",$Edgeview.Client.SessionKey)
		$webclient.Headers.Add("accept",$EdgeView.Type + ";version=5.1")
		[xml]$EGWConfXML = $webclient.DownloadString($EdgeView.href)
		
		# Check if the network is deployed and if not, skip it
		if ($Edgeview.Deployed -notlike "True"){Continue}
		
		# Get the vApp that the vApp network is in
		$vapp = Get-CIVApp -Id ($Edge.VApp) -ErrorAction SilentlyContinue
		
		# Build Report Object
		$final = [PSCustomObject]@{
		"Edge Name" = $Name
		"Edge Type" = "vApp Edge"
		Description = $EGWConfXML.VAppNetwork.Description
		"Firewall Enabled" = $EGWConfXML.vAppNetwork.Configuration.Features.FirewallService.IsEnabled
		"NAT Enabled" = $EGWConfXML.vAppNetwork.Configuration.Features.NATService.IsEnabled
		"DHCP Enabled" = $EGWConfXML.vAppNetwork.Configuration.Features.DHCPService.IsEnabled
		Org = $vApp.Org.Name
		TenantId = $Edge.Org.Split(':')[3]
		vApp = $Edge.vAppName
		DefaultGateway = $Edge.Gateway
		}
		$Report += $final
	}
}

# Export the report and show it on screen
$Report | Export-Csv "C:\Scripts\Technology\CSE\vApp Edges.csv" -NoTypeInformation
$Report | out-gridview

Disconnect-CIServer * -Confirm:$false
