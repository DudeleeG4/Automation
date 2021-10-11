Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

# Function for getting edge Gateway XMLs from vCloud API
Function Get-OrgVDCGateways {
	[CmdletBinding()]
    Param(
        $filter,
        [Parameter(ValueFromPipeline=$true)]
        $OrganisationVdc
    )
	Begin{
		# Check if a filter has been specified and print this to console (no added functionality for this yet, this is all it does lol)
        if ($filter){Write-host "$filter"}
	}Process{   
		# Loop through each vCloud the user is connected to using powercli
        Foreach ($Server in $global:DefaultCIServers){
            $pagenumber = 1
            # Loop through each VDC in the $OrganisationVdc variable
			Foreach ($VDC in $OrganisationVdc){
				# Get the href from the VDC object that has been piped in
                $VarVdc = $VDC.ExtensionData.Href
				Do{
					<# Take the vCloud API address from the current connected vCloud instances, add the query to pull back vShield edges 
					+ Specify the page number (the API can only return 128 results at a time) and filter by VDC href #>
                    $Uri = $Server.ServiceUri.AbsoluteUri + "query?type=edgeGateway&pageSize=128&page=" + $pagenumber + "&filter=(vdc==$VarVdc)"
					
					# Build headers containing the authorisation (retrieved through the current powerCLI connection), the type of object to expect from the REST request and the version
					$head = @{"x-vcloud-authorization"=$Server.SessionSecret} + @{"Accept"="application/*+xml;version=5.6;vr-version=3.0"}
					
					# This is the actual REST api web request
					$r = Invoke-WebRequest -URI $Uri -Method Get -Headers $head -ErrorAction:Stop
					
                    # Get the actual content out of the (largely gibberish) and turn it into an XML object which powershell can handle
					[xml]$sxml = $r.Content
					
                    # Get the Edge gateways out of the content and store them in a variable
					$EdgeGateways = $sxml.QueryResultRecords.EdgeGatewayRecord
					
					# Increment the page number by 1 (This is a half baked idea atm - need to continually increment the pagenumber by 1 every time the $EdgeGateways number is 128
					if ($EdgeGateways.Count -ne "128"){
                    $PageNumber = 1
					}Else{
					$pagenumber ++
					}
					
					# Check if any Edge Gateways have been returned and if so, spit them out into the pipeline
                    if ($EdgeGateways){$EdgeGateways}
				}Until($PageNumber -eq 1)
            }
        }
    }
}

Connect-CIServer vcd.portal.skyscapecloud.com

# Get OrgVDCs and store them as variable
$OrgVdcs = Get-OrgVDC | select -First 10
# Take the OrgVDC objects and pipe them into this function to retrieve just the edges associated with them
$Edges = $OrgVdcs | Get-OrgVDCGateways
# Get the edges by specifying OrganisationVDC parameter manually
$Edges3 = Get-OrgVDCGateways -OrganisationVdc $OrgVDCs
