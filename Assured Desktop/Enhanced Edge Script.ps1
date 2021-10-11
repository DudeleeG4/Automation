Connect-CIServer vcloud
$EdgeGateways = Get-EdgeGateways
$vAppNetworks = Search-Cloud -QueryType  AdminVAppNetwork
$VSENames = $FreeVSEs |%{[PSCustomObject]@{Name = ($_.Name | Split-vCloudID | select -First 1).TrimStart("vse-"); vCenterName = $_.Name}}

$PotentialvAppEdges = @()
$GatewayReport = Foreach ($VSEName in $VSENames){
	$EscapedName = [Regex]::Escape($VSEName.name)
	$CloudEdgeGateway = $EdgeGateways | Where {$_.name -like $EscapedName}
	if (!$CloudEdgeGateway){
		$CloudEdgeGateway = $EdgeGateways | Where {$_.name -match $EscapedName}
	}
	if (!$CloudEdgeGateway){
		$CloudEdgeGateway = $vAppNetworks | Where {$_.name -match $EscapedName} | Get-Unique
		$EdgeType = "Yes"
	}
	if (!$CloudEdgeGateway){
		Clear-Variable EdgeType
		Continue
	}
	[PSCustomObject]@{
		"Search Name" = $VSEName.Name
		"Escaped Name" = $EscapedName
		"vCenter Name" = $VSEName.vCenterName
		"vCloud Edge" = $CloudEdgeGateway.name
		"vApp Edge?" = $EdgeType
	}
}

$GatewayReport | Out-GridView


$vAppEdgeReport = Foreach ($PotentialvAppEdge in $PotentialvAppEdges){
	$vAppEdge = $vAppNetworks | Where {$_.name -match $PotentialvAppEdge."Escaped Name"} | Get-Unique
	[PSCustomObject]@{
		"vApp Edge Name" = $vAppEdge.name
		"vApp Edge Object" = $vAppEdge
		"Search Name" = $PotentialvAppEdge."Search Name"
		"vCenter Name" = $PotentialvAppEdge."vCenter Name"
	}
}
$vAppEdgeReport | Out-GridView