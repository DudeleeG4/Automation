Function ipsec_vpn($externalNetwork, $edgeName, $tunnelName, $IP){
    $url = "https://api.vcd.portal.skyscapecloud.com/api"
    $path = [Environment]::GetFolderPath("MyDocuments")
    $cred = get-credential
    $user = ($cred.getNetworkCredential().Username)+"@"+($cred.getNetworkCredential().Domain)
    $pass = $cred.getNetworkCredential().Password
    $pair = "${user}:${pass}"
    $base64 = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
    $basicAuthValue = "Basic $base64"
    $headers=@{"AUTHORIZATION"=$basicAuthValue;"Accept"="application/*+xml;version=5.5"}
    try{   
        write-host "Logging into vCloud API.."
        $result = Invoke-WebRequest -Method POST -uri "$url/sessions" -Headers $headers -ContentType "application/vnd.vmware.admin.edgeGatewayServiceConfiguration+xml"
        write-host "Logged in"
    } catch {
        throw $_
    }
     
    $x_vcloud_token_name = $result.Headers.Keys.split([environment]::NewLine)[1]
    $x_vcloud_token_value = $result.Headers.Values.split([environment]::NewLine)[1]
    $headers=@{"$x_vcloud_token_name"=$x_vcloud_token_value;"Accept"="application/*+xml;version=5.5"}
    try{
        write-host "Going to /admin..."
        [xml]$result = Invoke-WebRequest -Method GET -uri "$url/admin" -Headers $headers -ContentType "application/vnd.vmware.admin.edgeGatewayServiceConfiguration+xml"
    } catch {
        throw $_
    }
    $href = $result.VCloud.Networks.Network | ?{$_.name -match $externalNetwork} | select -property href
    try {
        write-host "Searching for external network..."
        [xml]$result = Invoke-WebRequest -Method GET -uri $href.href -Headers $headers -ContentType "application/vnd.vmware.admin.edgeGatewayServiceConfiguration+xml"
        write-host "Found external network"
    } catch {
        throw "Cannot find external network"
    }
    $edges = $result.ExternalNetwork.Configuration.IpScopes.IpScope
        foreach($edge in $edges){
            if ($edge.suballocations.suballocation.edgegateway.name -match $edgeName){
                $href = $edge.suballocations.suballocation.edgegateway | ?{$_.name -match $edgeName} | select -property href
            }
        }
    try {
        write-host "Searching for edge gateway..."
        [xml]$result = Invoke-WebRequest -Method GET -uri $href.href -Headers $headers -ContentType "application/vnd.vmware.admin.edgeGatewayServiceConfiguration+xml"
        write-host "Found edge gateway"
    } catch {
        throw "Cannot find edge gateway"
    }
    foreach($tunnel in $result.EdgeGateway.Configuration.EdgeGatewayServiceConfiguration.GatewayIpsecVpnService.Tunnel){
        if($tunnel.Name -Match $tunnelName){
            if($tunnel.LocalIPAddress -like "172.*"){
                $tunnel.LocalIPAddress="$IP"
            }
        }
    }
    try {
        write-host "Saving temp xml to: $path\edgeXML.txt"
        $result.Save("$path\edgeXML.txt")
    } catch {
        throw "Cannot save temp xml: $path\edgeXML.txt! `nExiting script"
    }
    $text = Get-Content "$path\edgeXML.txt"
    $line = 0
    $found = $false
    While ($found -eq $false){
        if($text[$line] -like "*<GatewayIpsecVpnService>*"){
            $found = $true
            $end_found = $false
            $ipsec = @()
            $ipsec += "<?xml version=`"1.0`" encoding=`"UTF-8`"?>"
            $ipsec += "<EdgeGatewayServiceConfiguration xmlns=`"http://www.vmware.com/vcloud/v1.5`">"
            While($end_found -eq $false){
                if ($text[$line] -like "*</GatewayIpsecVpnService>*"){
                    $end_found = $true
                    $ipsec += $text[$line].Trim()
                } else {
                    $ipsec += $text[$line].Trim()
                    $line++
                }          
            }
        } else {
            $line++
        }
        $ipsec += "</EdgeGatewayServiceConfiguration>"
    }
    $href = $href.href + "/action/configureServices" 
    try {
        write-host "Posting back to edge..."
        [xml]$result = Invoke-WebRequest -Method POST -uri $href -Headers $headers -ContentType "application/vnd.vmware.admin.edgeGatewayServiceConfiguration+xml" -Body $ipsec
        write-host "Completed"
    } catch {
        throw $_
    }
    try {
        write-host "Deleting temp xml file: $path\edgeXML.txt"
        remove-item "$path\edgeXML.txt"
        write-host "Deleted `nFinished Script"
    } catch {
        write-host "Cannot delete temp xml file: $path\edgeXML.txt"
    }
}
Function run_gui(){
    Add-Type -AssemblyName System.Windows.Forms
    $form = New-Object Windows.Forms.Form
    $form.Size = New-Object Drawing.Size @(550,300)
    $form.text = "IPSEC VPN - CHANGE LOCAL IP"
    $form.StartPosition = "CenterScreen"
    $form.Add_Shown({$form.Activate()})
    $objLabel = New-Object System.Windows.Forms.Label
    $objLabel.Location = New-Object System.Drawing.Size(10,30)
    $objLabel.Size = New-Object System.Drawing.Size(150,20)
    $objLabel.Text = "Please enter the edge name:"
    $form.Controls.Add($objLabel)
    $edgeTextBox = New-Object System.Windows.Forms.TextBox
    $edgeTextBox.Location = New-Object System.Drawing.Size(275,30)
    $edgeTextBox.Size = New-Object System.Drawing.Size(200,20)
    $form.Controls.Add($edgeTextBox)
    $objLabel = New-Object System.Windows.Forms.Label
    $objLabel.Location = New-Object System.Drawing.Size(10,60)
    $objLabel.Size = New-Object System.Drawing.Size(250,20)
    $objLabel.Text = "Please enter the external network name:"
    $form.Controls.Add($objLabel)
    $nftTextBox = New-Object System.Windows.Forms.TextBox
    $nftTextBox.Location = New-Object System.Drawing.Size(275,60)
    $nftTextBox.Size = New-Object System.Drawing.Size(200,20)
    $form.Controls.Add($nftTextBox)
    $objLabel = New-Object System.Windows.Forms.Label
    $objLabel.Location = New-Object System.Drawing.Size(10,90)
    $objLabel.Size = New-Object System.Drawing.Size(250,20)
    $objLabel.Text = "Please enter the tunnel name:"
    $form.Controls.Add($objLabel)
    $tunnelTextBox = New-Object System.Windows.Forms.TextBox
    $tunnelTextBox.Location = New-Object System.Drawing.Size(275,90)
    $tunnelTextBox.Size = New-Object System.Drawing.Size(200,20)
    $form.Controls.Add($tunnelTextBox)
    $objLabel = New-Object System.Windows.Forms.Label
    $objLabel.Location = New-Object System.Drawing.Size(10,120)
    $objLabel.Size = New-Object System.Drawing.Size(250,20)
    $objLabel.Text = "Please enter the IP you wish to change to:"
    $form.Controls.Add($objLabel)
    $ipTextBox = New-Object System.Windows.Forms.TextBox
    $ipTextBox.Location = New-Object System.Drawing.Size(275,120)
    $ipTextBox.Size = New-Object System.Drawing.Size(200,20)
    $form.Controls.Add($ipTextBox)
    $eventHandler = [System.EventHandler]{
    $textBox1.Text;
    $textBox2.Text;
    $textBox3.Text;
    $form.Close();};
    $okbtn = New-Object System.Windows.Forms.Button
    $okbtn.Location =  New-Object Drawing.Size @(275,200)
    $okbtn.Add_Click($eventHandler)
    $okbtn.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $okbtn.Text = "Go..."
    $form.Controls.Add($okbtn)
    $cancelbtn = New-Object System.Windows.Forms.Button
    $cancelbtn.Location =  New-Object Drawing.Size @(175,200)
    $cancelbtn.Add_Click($eventHandler)
    $cancelbtn.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $cancelbtn.Text = "Cancel"
    $form.Controls.Add($cancelbtn)
    $result = $form.ShowDialog()
    if($result -eq [System.Windows.Forms.DialogResult]::OK){
        $edgeName = $edgeTextBox.Text.Trim()
        $externalNetwork = $nftTextBox.Text.Trim()
        $tunnelName = $tunnelTextBox.Text.Trim()
        $IP = $ipTextBox.Text.Trim()
        $edgeName
        $externalNetwork
        $tunnelName
        $IP
        ipsec_vpn -externalNetwork $externalNetwork -edgeName $edgeName -tunnelName $tunnelName -IP $IP
    } else {
        write-host "Cancelled..."
    }
}
run_gui