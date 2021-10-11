### Specify Output path for XML dump of External Network
$ExtNetXMLPath = "C:\Users\sudandrews\Desktop\ExtNetFull.xml"

### Specify which External network you'd like to interact with
$ExtNetName = "CSE Temp"

### Connect to vCloud using PowerCLI
Connect-CIServer vcd.z0000f.r00006.frn.portal.skyscapecloud.com

### Do a Search-Cloud for all external networks and filter by name provided above
$ExtNetworkView = Search-Cloud -QueryType ExternalNetwork | Where {$_.name -match $ExtNetName} | Get-CIView
$Headers = @{
    "x-vcloud-authorization"=$ExtNetworkView.Client.SessionKey
    "Accept"=$ExtNetworkView.Type + ";version=32.0"
}

# Get Edge Configuration in XML format
$Uri = $ExtNetworkView.href
[XML]$ExtNetConfXML = Invoke-RestMethod -URI $Uri -Method GET -Headers $Headers

### Export External Network XML to desktop ###
$ExtNetConfXML.save($ExtNetXMLPath)

### - After editing XML,  Load XML and push it back to vCloud (un-comment these lines and run them)
[XML]$Body = Get-Content -Path $ExtNetXMLPath
Invoke-RestMethod -URI $Uri -Method PUT -Headers $Headers -Body $Body

### To check it's worked run:
[XML]$ExtNetConfXML = Invoke-RestMethod -URI $Uri -Method GET -Headers $Headers
$ExtNetConfXML.VMWExternalNetwork.Configuration.IPScopes.IpScope