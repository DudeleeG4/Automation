# Set headers
$Headers = @{
    "x-vcloud-authorization"=$DefaultCIServers.SessionSecret
    "Accept"="application/*+xml;version=32.0"
}



$CIVM = Get-CIVapp -Name "gurch-temp2i3" | Get-CIVM | Where {$_.name -match "temp1-test"}


# Get Edge Configuration in XML format
$Uri = $CIVM.href

#[xml]$searchvm = Invoke-WebRequest -Headers $headers -Method "GET" -Uri $Uri -UseBasicParsing
#$VM_href = $searchvm.QueryResultRecords.VMRecord.href

#$vminfo = Invoke-WebRequest -Headers $headers -Method "GET" -Uri $Uri -UseBasicParsing
#[XML]$vminfoxml = $vminfo.content

$vurl="$Uri/metadata" 
 
$Metadata_Type = "application/vnd.vmware.vcloud.metadata+xml"
$MetadataValue_Type = "application/vnd.vmware.vcloud.metadata.value+xml"

$Headers = @{
    "x-vcloud-authorization"=$DefaultCIServers.SessionSecret
    "Accept"="application/*+xml;version=32.0"
    "Content-Type"=$Metadata_Type
}


#:
$ADDMData=@"
<Metadata xmlns="http://www.vmware.com/vcloud/v32.0">
    <MetadataEntry>
        <Key>asset-tag</Key>
        <Value>oooqqq</Value>
    </MetadataEntry>
</Metadata>
"@


$result = Invoke-WebRequest -Headers $headers -Method "POST" -Uri $vurl -Body $ADDMData -UseBasicParsing

$result = Invoke-WebRequest -Headers $headers -Method "GET" -Uri $vurl -UseBasicParsing


###########################################################################################
### trying it another way

$Metadata = New-Object VMware.VimAutomation.Cloud.Views.Metadata
$Metadata.MetadataEntry = New-Object VMware.VimAutomation.Cloud.Views.MetadataEntry
$Metadata.MetadataEntry[0].Key = "asset-tag"
$Metadata.MetadataEntry[0].Value = "oooqqq"


Function New-CIMetaData {
    <#
    .SYNOPSIS
        Creates a Metadata Key/Value pair.
    .DESCRIPTION
        Creates a custom Metadata Key/Value pair on a specified vCloud object
    .PARAMETER  Key
        The name of the Metadata to be applied.
    .PARAMETER  Value
        The value of the Metadata to be applied.
    .PARAMETER  CIObject
        The object on which to apply the Metadata.
    .EXAMPLE
        PS C:\> New-CIMetadata -Key "Owner" -Value "Alan Renouf" -CIObject (Get-Org Org1)
    #>
     [CmdletBinding(
         SupportsShouldProcess=$true,
        ConfirmImpact="High"
    )]
    param(
        [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
            [PSObject[]]$CIObject,
            $Key,
            $Value
        )
    Process {
        Foreach ($Object in $CIObject) {
            $Metadata = New-Object VMware.VimAutomation.Cloud.Views.Metadata
            $Metadata.MetadataEntry = New-Object VMware.VimAutomation.Cloud.Views.MetadataEntry
            $Metadata.MetadataEntry[0].Key = $Key
            $Metadata.MetadataEntry[0].Value = $Value
            $Object.ExtensionData.CreateMetadata($Metadata)
            ($Object.ExtensionData.GetMetadata()).MetadataEntry | Where {$_.Key -eq $key } | Select @{N="CIObject";E={$Object.Name}}, Key, Value
        }
    }
}

Function Get-CIMetaData {
    <#
    .SYNOPSIS
        Retrieves all Metadata Key/Value pairs.
    .DESCRIPTION
        Retrieves all custom Metadata Key/Value pairs on a specified vCloud object
    .PARAMETER  CIObject
        The object on which to retrieve the Metadata.
    .PARAMETER  Key
        The key to retrieve.
    .EXAMPLE
        PS C:\> Get-CIMetadata -CIObject (Get-Org Org1)
    #>
    param(
        [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
            [PSObject[]]$CIObject,
            $Key
        )
    Process {
        Foreach ($Object in $CIObject) {
            If ($Key) {
                ($Object.ExtensionData.GetMetadata()).MetadataEntry | Where {$_.Key -eq $key } | Select @{N="CIObject";E={$Object.Name}}, Key, Value
            } Else {
                ($Object.ExtensionData.GetMetadata()).MetadataEntry | Select @{N="CIObject";E={$Object.Name}}, Key, Value
            }
        }
    }
}