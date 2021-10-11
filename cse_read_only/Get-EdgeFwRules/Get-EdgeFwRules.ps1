$vCenter = Get-CustomerVIServers | Invoke-MultiSelectForm
Connect-VIServer $vCenter

$EdgeFW = Get-NSXEdge | Out-GridView -PassThru | Get-NSXEdgeFirewall

$Report = foreach ($Rule in $EdgeFW.firewallRules.firewallRule){
	$SourceIPs = $Rule.source.IpAddress
	if (!$SourceIPs){$SourceIPs = "Any"}
	$DestinationIPs = $Rule.destination.IPAddress
	if (!$DestinationIPs){$DestinationIPs = "Any"}
	$Ports = foreach ($Service in $Rule.Application.Service){
		$Service.Protocol + ":" + ($Service.port -join ",")
	}
	[PSCustomObject]@{
		id = $Rule.Id
		name = $Rule.Name
		"Source IPs" = $SourceIPs -join ", "
		"Destination IPs" = $DestinationIPs -join ", "
		Action = $Rule.Action
		Ports = $Ports -join "; "
		Description = $Rule.description
		Enabled = $Rule.Enabled
		"Rule Type" = $Rule.RuleType
	}
}

$OutPath = ([Environment]::GetFolderPath("Desktop")) + "\FirewallRules.csv"

$Report | Export-Csv $OutPath -NoTypeInformation