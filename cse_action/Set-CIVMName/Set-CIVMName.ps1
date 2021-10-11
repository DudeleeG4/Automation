Clear

Connect-CIServer "api.vcd.portal.skyscapecloud.com"

$CIVM = Get-CIVM -VApp "Deployment Test_ai2" | Out-Gridview -Title "Select a VM" -PassThru

$Uri = $CIVM.Href
$head = @{"x-vcloud-authorization"=$global:DefaultCIServers.SessionSecret} + @{"Accept"="application/*+xml;version=5.6;vr-version=3.0"}
$r = Invoke-WebRequest -URI $Uri -Method Get -Headers $head -ErrorAction:Stop
$sxml = $r.Content
$sxml | Export-CLixml "C:\Scripts\Technology\CSE\VMDetails.xml"

Continue

### Edit Exported XML before running next section ###

$newxml = Import-Clixml "C:\Scripts\Technology\CSE\VMDetails.xml"

$headers = @{"x-vcloud-authorization"=$global:DefaultCIServers.SessionSecret} + @{"Accept"="application/*+xml;version=5.6;vr-version=3.0"} + @{"Content-Type"="application/vnd.vmware.vcloud.vm+xml"}

Invoke-WebRequest -URI $URI -Method Put -Headers $headers -Body $newxml.vm