Connect-CIServer vcloud

# Set headers for initial request, exploiting the powerCLI connection for it's authentication token
$Headers = @{
    "x-vcloud-authorization"=$DefaultCIServers.SessionSecret
    "Accept"="application/*+xml;version=32.0"
}


# Get a VM using PowerCLI, in this case one of Gurch's test VMs
$CIVM = Get-CIVapp -Name "gurch-temp2i3" | Get-CIVM | Where {$_.name -match "temp1-test"}


# Get Edge Configuration in XML format
$Uri = $CIVM.href


# Append "/metadata" onto the end of VM Href the same way the customer is
$vurl="$Uri/metadata" 
 
# Create variable for a specific content-type, to be used in request headers
$Metadata_Type = "application/vnd.vmware.vcloud.metadata+xml"
$MetadataValue_Type = "application/vnd.vmware.vcloud.metadata.value+xml"


# Create request headers the same way the customer is
$Headers = @{
    "x-vcloud-authorization"=$DefaultCIServers.SessionSecret
    "Accept"="application/*+xml;version=32.0"
    "Content-Type"=$Metadata_Type
}


# Build metadata XML form
$ADDMData=@"
<Metadata xmlns="http://www.vmware.com/vcloud/v32.0">
    <MetadataEntry>
        <Key>asset-tag</Key>
        <Value>oooqqq</Value>
    </MetadataEntry>
</Metadata>
"@


### Get request to retrieve metadata for VM - works okay
$GetResult = Invoke-WebRequest -Headers $headers -Method "GET" -Uri $vurl -UseBasicParsing

### Post request to add some metadata - fails
$PostResult = Invoke-WebRequest -Headers $headers -Method "POST" -Uri $vurl -Body $ADDMData -UseBasicParsing

