### Enter endpoint and credentials here
$vCloudUrl = "<vCloud URL String>"
$Username = "API Username String"
$Password = "Portal Password String"

### Convert credentials into Base64 encoded string
$Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username,$password)))

### Create headers for initial authentication request
$Headers = @{}
$Headers.Add("Authorization", "Basic $($Base64AuthInfo)")
$Headers.Add("Accept", "application/*+xml;version=32.0")

### POST initial authentication request with user's portal API credentials
$InitialResponse = Invoke-WebRequest -Method POST ("https://" + $vCloudUrl + "/api/sessions") -Headers $Headers

### Create headers using the returned x-vcloud-authorization token, to be user with all further requests
$Headers = @{}
$Headers.Add("x-vcloud-authorization", $InitialResponse.Headers.'x-vcloud-authorization')
$Headers.Add("Accept", "application/*+xml;version=32.0")

### Gather all vApps
[XML]$RawvApps = Invoke-WebRequest -Method GET ("https://" + $vCloudUrl + "/api/query?type=vApp") -Headers $Headers

### Dive into vApps and return their hrefs
$vApphrefs = $RawvApps.QueryResultRecords.vAppRecord.href

### Loop through each vApp and gather metadata, appending to array
$Report = @()
foreach ($vApphref in $vApphrefs){
    [XML]$vAppMetadata = Invoke-Webrequest -Method GET ($vApphref + "/metadata") -Headers $Headers
    $Report += $vAppmetadata
}

### Output array
$Report