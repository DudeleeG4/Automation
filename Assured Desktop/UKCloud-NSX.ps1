# Function to turn credentials into Base64 auth token to use for REST requests
function Get-BasicAuthCreds {
<# 
.SYNOPSIS
	This function takes a username/password combination or a powershell credential object and converts it into a base64 authorisation token to be used with REST APIs

.PARAMETER Username
	A username

.PARAMETER Password
	A password
	
.PARAMETER Credentials
	This would be a powershell credential object, such as would be created using "Get-Credential"
#>
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
<# 
.SYNOPSIS
	This function sets a global variable for authorisation headers to be used with NSX REST api requests

.PARAMETER Creds
	This is used so that the user can pass credentials to this function non-interactively
#>
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

function Set-NSXEP {
<# 
.SYNOPSIS
	This function sets the NSX manager IP as a global variable to be used in rest API requests

.PARAMETER VM
	This will use a VM object to find which NSX manager to use in relation to that VM
	
.PARAMETER Server
	This allows the user to specify which vCenter they want to use (the function will set the endpoint to be the NSX manager of that vCenter)
#>
Param (
	[Parameter(ValueFromPipeline)]$VM,
	$Server
)
	if ($server){
		$SelectedVIServer = $Server
	}elseif ($VM){
		# Determine the NSX Manager IP address from the relevent connected vCenter by using a VM as a reference point
		$SelectedVIServer = $Global:DefaultVIServers | Where {$VM.Client.ConnectivityService.ServerAddress -match $_}
	}elseif($Global:DefaultVIServers){
		$SelectedVIServer = $DefaultVIServers | Invoke-MultiSelectForm -Title "vCenters" -Message "Please select vCenter:"
	}else{
		Write-Error "Not connected to a vCenter"
	}
	$ExtensionManager = Get-View ExtensionManager -Server $SelectedVIServer
	$NSXExtension = $ExtensionManager.ExtensionList | Where-Object {$_.key -match "com.vmware.vShieldManager"}
	[string[]]$EndpointCol = $NSXExtension.Client.url -split "/"
	[string[]]$ServerCol = $EndpointCol[2] -split ":"
	$Global:NSXServer = "https://" + $ServerCol[0]
}

##############################################################################################

function Invoke-NSXQuery{
Param(
	$RestEP,
	$OutPath,
	$Cred,
	$Server,
	$VM
)
	if (!$Global:NSXServer){
		if ($Server){
			Set-NSXEP -Server $Server
		}
		elseif($VM){
			Set-NSXEP -VM $VM
		}else{
			Set-NSXEP
		}
	}
	$Endpoint = $Global:NSXServer + $RestEP
	if (!$Global:Headers){
		if($Cred){
			Set-NSXAuthHeaders -Creds $Cred
		}else{
			Set-NSXAuthHeaders
		}
	}
	Invoke-WebRequest -Uri $Endpoint -Method Get -Headers $Global:Headers -ContentType "application/xml"
}

##############################################################################################

function Get-NSXEdge {
<# 
.SYNOPSIS
	This function retrieves the NSX Edge objects from NSX for a vCenter
	
.NOTES
	Example usage
	Get-NSXEdge | Out-Gridview 
#>
	$RawOutput = Invoke-NSXQuery -RestEP "/api/4.0/edges"
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
<# 
.SYNOPSIS
	This function retrieves a summary of an edge gateway from NSX

.PARAMETER Edge
	This is an NSX edge summary object which can be retrieved using Get-NSXEdge
	
.PARAMETER EdgeID
	This is the NSX edge id - it always looks like this:
	edge-XX (i.e edge-47)
#>
Param(
	[Parameter(ValueFromPipeline)]$Edge,
	$EdgeID
)
	Process{
		if ($Edge){
			foreach ($Gateway in $Edge){
				[String]$EdgeID = $Gateway.Id
				$RestEP = "/api/4.0/edges/" + $EdgeID + "/summary"
				$Output = Invoke-NSXQuery -RestEP $RestEP
				$Output = [XML]$Output.Content
				$Output.EdgeSummary				
			}
		}elseif ($EdgeID){
			foreach ($ID in $EdgeID){
				$RestEP = "/api/4.0/edges/" + $ID + "/summary"
				$Output = Invoke-NSXQuery -RestEP $RestEP
				$Output = [XML]$Output.Content
				$Output.EdgeSummary
			}
		}
	}
}

##############################################################################################

function Get-NSXEdgeFirewall {
<# 
.SYNOPSIS
	This function retrieves the firewall status and associated rules for an NSX edge

.PARAMETER Edge
	This is an NSX edge summary object which can be retrieved using Get-NSXEdge
	
.PARAMETER EdgeID
	This is the NSX edge id - it always looks like this:
	edge-XX (i.e edge-47)
#>
Param(
	[Parameter(ValueFromPipeline)]$Edge,
	$EdgeID
)
	Process{
		if ($Edge){
			foreach ($Gateway in $Edge){
				[String]$EdgeID = $Gateway.Id
				$RestEP = "/api/4.0/edges/" + $EdgeID + "/firewall/config"
				$Output = Invoke-NSXQuery -RestEP $RestEP
				$Output = [XML]$Output.Content
				$Output.Firewall
				}
		}elseif($EdgeID){
			Foreach ($ID in $EdgeID){
				$RestEP = "/api/4.0/edges/" + $ID + "/firewall/config"
				$Output = Invoke-NSXQuery -RestEP $RestEP
				$Output = [XML]$Output.Content
				$Output.Firewall
			}
		}
	}
}