# Function to turn credentials into Base64 auth token to use for REST requests
function Get-BasicAuthCreds {
param(
	[Parameter(ValueFromPipelineByPropertyName)][string]$Username,
	[Parameter(ValueFromPipelineByPropertyName)][string]$Password,
	[Management.Automation.PSCredential]$Credentials
)
	if ($Credentials){
	$Username = $Credentials.Username
	$Password = $Credentials.GetNetworkCredential().Password
	}
    $AuthString = "{0}:{1}" -f $Username,$Password
    $AuthBytes  = [System.Text.Encoding]::Ascii.GetBytes($AuthString)
    return [Convert]::ToBase64String($AuthBytes)
}

############################################################################################

function Set-NSXAuthHeaders {
Param(
	$Creds
)
	if (!$Creds){
		# Prompt user for their vCenter credentials
		$Creds = Get-Credential
	}
	# Convert credentials to base64 auth token
	$BasicCreds = Get-BasicAuthCreds -Credentials $Creds	
	#Set Authorisation Headers
	$Global:Headers = @{}
	$Global:Headers.Add("Authorization","Basic $BasicCreds")
}

#############################################################################################

function Get-NSXEP {
Param (
	[Parameter(ValueFromPipeline)]$VM,
	$Server
)
	if ($server){
		$SelectedVIServer = $Server
	}elseif ($VM){
		# Determine the NSX Manager IP address from the relevent connected vCenter by using a VM as a reference point
		$SelectedVIServer = $Global:DefaultVIServers | Where {$VM.Client.ConnectivityService.ServerAddress -match $_}
	}
	$ExtensionManager = Get-View ExtensionManager -Server $SelectedVIServer
	$NSXExtension = $ExtensionManager.ExtensionList | Where-Object {$_.key -match "com.vmware.vShieldManager"}
	[string[]]$EndpointCol = $NSXExtension.Client.url -split "/"
	[string[]]$ServerCol = $EndpointCol[2] -split ":"
	$Global:NSXServer = "https://" + $ServerCol[0]
}

##############################################################################################

function Get-NSXEdge {
	$RestEP = $Global:NSXServer + "/api/4.0" + "/edges"
	$RawOutput = Invoke-WebRequest -Uri $RestEP -Method Get -Headers $Global:Headers -ContentType "application/xml"
	$Output = [XML]$RawOutput.Content
	$Output.pagedEdgeList.edgePage.edgeSummary
}

##############################################################################################

function Get-NSXEdgeSupportLogs {
<# 
.SYNOPSIS
	This function retrieves the technical support bundle from an edge gateway in NSX
	
.PARAMETER EdgeID
	This is the NSX edge id - it always looks like this:
	edge-XX (i.e edge-47)

.PARAMETER Outpath
	This is the output path to export the support bundle
	
.NOTES
	Example usage
	$EdgeID = "edge-7"
	$OutPath = "C:\Users\sudandrews\Desktop"
	Get-NSXEdgeSupportLogs -EdgeID "edge-7" -Outpath $OutPath
	
	Or
	
	$OutPath = "C:\Users\sudandrews\Desktop"
	Get-NSXEdge | Out-Gridview -PassThru | Get-NSXEdgeSupportLogs -Outpath $OutPath
#>

Param(
	[Parameter(ValueFromPipeline)]$Edge,
	$EdgeID,
	[Parameter(Mandatory)]$Outpath
)
	if ($Edge){
		[String]$EdgeID = $Edge.Id
	}
	$FinalOutpath = $OutPath + "\" + $EdgeID + "_Support_Logs.tar.gz"
	$RestEP = $Global:NSXServer + "/api/4.0/edges/" + $EdgeID + "/techsupportlogs"
	Invoke-WebRequest -Uri $RestEP -Method Get -Headers $Global:Headers -ContentType "application/xml" -OutFile $FinalOutpath
}

##############################################################################################

function Get-NSXEdgeSummary {
Param(
	[Parameter(ValueFromPipeline)]$Edge,
	$EdgeID
)
	if ($Edge){
		[String]$EdgeID = $Edge.Id
	}
	$RestEP = $Global:NSXServer + "/api/4.0/edges/" + $EdgeID + "/summary"
	$Output = Invoke-WebRequest -Uri $RestEP -Method Get -Headers $Global:Headers -ContentType "application/xml"
	$Output = [XML]$Output.Content
	$Output.EdgeSummary
}

##############################################################################################

function Get-NSXEdgeFirewall {
Param(
	[Parameter(ValueFromPipeline)]$Edge,
	$EdgeID
)
	if ($Edge){
		[String]$EdgeID = $Edge.Id
	}
	$RestEP = $Global:NSXServer + "/api/4.0/edges/" + $EdgeID + "/firewall/config"
	$Output = Invoke-WebRequest -Uri $RestEP -Method Get -Headers $Global:Headers -ContentType "application/xml"
	$Output = [XML]$Output.Content
	$Output.Firewall
}