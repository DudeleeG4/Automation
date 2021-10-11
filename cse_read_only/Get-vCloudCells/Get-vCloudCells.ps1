Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}
Function Get-PVDCs {
<#
.SYNOPSIS
Discovers all vCloud Director cells
.DESCRIPTION
Discovers all vCloud Director cells including Cloud Proxies and report their status and version and if they ran VC proxy .EXAMPLE PS C:\> Get-VRCells
.NOTES
Author: Tomas Fojta
#>
 
if (-not $global:DefaultCIServers) {Connect-CIServer}
 
$Uri = $global:DefaultCIServers.ServiceUri.AbsoluteUri + "admin/extension/providerVdcReferences/query"
$head = @{"x-vcloud-authorization"=$global:DefaultCIServers.SessionSecret} + @{"Accept"="application/*+xml;version=5.6;vr-version=3.0"}
$r = Invoke-WebRequest -URI $Uri -Method Get -Headers $head -ErrorAction:Stop
[xml]$sxml = $r.Content
$PVDCs = $sxml.QueryResultRecords.VMWProviderVdcRecord
 
 
$PVDCs
}

Connect-CIServer

Get-PVDCs | Out-Gridview

Disconnect-CIServer -Confirm:$false
