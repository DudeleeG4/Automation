## Set this to resolve SSL cert errors on auth with NSX servers

if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type){
$certCallback = @"

    using System;

    using System.Net;

    using System.Net.Security;

    using System.Security.Cryptography.X509Certificates;

    public class ServerCertificateValidationCallback

    {

        public static void Ignore()

        {

            if(ServicePointManager.ServerCertificateValidationCallback ==null)

            {

                ServicePointManager.ServerCertificateValidationCallback +=

                    delegate

                    (

                        Object obj,

                        X509Certificate certificate,

                        X509Chain chain,

                        SslPolicyErrors errors

                    )

                   

{                         return true;                     }
;

            }

        }

    }

"@

    Add-Type $certCallback

}

[ServerCertificateValidationCallback]::Ignore()

### Change Tls type to 1.2 ###

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

##############################################################################################################################

Function Set-OVUri {
<# 
.SYNOPSIS
	This function will take an IP address and turn it into the https url endpoint to be used as the basis for an Opsview API request

.PARAMETER IP
    This will be one or more IP(s) for the Opsview server, taking the normal IPv4 format, i.e:
    xx.xx.xx.xx
#>
Param(
    [Parameter(ValueFromPipeline)]$IP
)
    Process {
        Foreach ($Address in $IP){
            "https://" + $Address + "/rest/"
        }
    }
}

function Get-SimpleCred {
<# 
.SYNOPSIS
	This function takes a powershell credential object and returns the username and password un-encrypted

.PARAMETER Credentials
	This would be a powershell credential object, such as would be created using "Get-Credential"
#>
param(
	[Parameter(ValueFromPipeline)][Management.Automation.PSCredential]$Credentials
)
Process {
	    $Username = $Credentials.Username
	    $Password = $Credentials.GetNetworkCredential().Password
        Return $Username, $Password
    }
}

Function Get-OVAuthToken {
<# 
.SYNOPSIS
	This function will authenticate against the REST api for a given Opsview endpoint(s) and retrieve an authentication token. It will then package this with the REST API endpoint and credentials object.

.PARAMETER EPs
    This is an Opsview endpoint(s) to be used for REST requests, provided by Set-OVUri

.PARAMETER Cred
	This would be a powershell credential object, such as would be created using "Get-Credential"
#>
Param(
    [Parameter(ValueFromPipeline=$True)]$EPs,
    $Cred
)
    Process{
        Foreach ($EP in $EPs){
            if (!$Cred){
                $Cred = Get-Credential
            }
            $Auth = $Cred | Get-SimpleCred
            Try {$AuthTokenRaw = Invoke-WebRequest -Uri ($EP + "login") -Method POST -Body @{username=$Auth[0];password=$Auth[1]}}
            Catch{
                Write-Error $_
                Break
            }
            
            [PSCustomObject]@{
                Server = $EP
                Token = $AuthTokenRaw.Content | ConvertFrom-Json | Select -ExpandProperty token
                ClientAuth = $Cred
            }
        }
    }
}

Function Set-DefaultOVServers {
<#
.SYNOPSIS
	This function will set a global variable which contains a REST API endpoint, headers and a credentials object created from Get-OVAuthToken

.PARAMETER OVServer
    This is one or more powershell objects created by Get-OVAuthToken that each contain both the Opsview endpoint and the authorisation token for that endpoint

.PARAMETER Silent
    This tells the function not to output anything to the terminal at the end, useful when re-authentication an existing session
#>
Param([Parameter(ValueFromPipeline)]$OVServer,
[Switch]$Silent
)
    Process{
        Foreach ($Server in $OVServer){
            if ($OVHeaders){
                Remove-Variable OVHeaders
            }
            $OVHeaders = @{}
            $OVHeaders.Add("X-Opsview-Username",$Server.ClientAuth.Username)
            $OVHeaders.Add("X-Opsview-Token",$Server.Token)
            If (!$Global:DefaultOVServers){
                $Global:DefaultOVServers = @()
            }
            $Global:DefaultOVServers += [PSCustomObject]@{
                Server = $Server.Server
                Headers = $OVHeaders
                ClientAuth = $Server.ClientAuth
            }
            if (!$Silent){
                $Global:DefaultOVServers | Select -Last 1 | Select Server
            }
        }
    }
}

Function Connect-OVServer {
<# 
.SYNOPSIS
	This function will authenticate against (and store global variables containing connection details for) one or more Opsview REST api endpoints

.PARAMETER OVServer
    This will be one or more IP(s) for the Opsview server, taking the normal IPv4 format, i.e:
    xx.xx.xx.xx

.PARAMETER
    This would be a powershell credential object, such as would be created using "Get-Credential"
#>
Param(
    [Parameter(Position=0)]$OVServer,
    $Credential
)
    Process{
        Foreach ($Server in $OVServer){
            $EPs = Set-OVUri -IP $Server
            $EPs | Get-OVAuthToken -Cred $Credential | Set-DefaultOVServers
        }
    }
}

Function Disconnect-OVServer {
<# 
.SYNOPSIS
	This function will remove the global variables containing all UKCloud.Opsview connection and authentication information for the current session.
#>
    Remove-Variable -Scope Global -Name DefaultOVServers
}

Function Invoke-OVQuery {
<# 
.SYNOPSIS
	This function makes REST requests to all of the servers stored in $Global:DefaultOVServers, and is called by the functions the user would use such as Get-OVInfo.
    It will attempt to re-authenticate using the credentials stored alongside each server in $Global:DefaultOVServers if a query fails due to an expired token.

.PARAMETER Query
    This will be the query appended on to the end of the basic https url endpoint for Opsview REST API requests (provided by Set-OVUri)
#>
Param(
    [Parameter(ValueFromPipeline)]$Query,
    $Method
)
    Begin{
        if (!$Method){
            $Method = "GET"
        }
    }
    Process{
        Foreach ($Q in $Query){
            Foreach ($OVServer in $Global:DefaultOVServers){
                Try{
                    [xml]$RawContent = Invoke-WebRequest -Uri ($OVServer.Server + $Query) -Method $Method -Headers $OVServer.Headers -ContentType "text/xml"
                    $RawContent
                }Catch{
                    If ($_.ErrorDetails.Message -match "Token has expired"){
                        $OtherOVServers = $Global:DefaultOVServers | Where {$_.Server -notmatch $OVServer.Server}
                        Remove-Variable -Scope Global -Name DefaultOVServers
                        $Global:DefaultOVServers = @()
                        $Global:DefaultOVServers += $OtherOVServers
                        $OVServer.Server | Get-OVAuthToken -Cred $OVServer.ClientAuth | Set-DefaultOVServers -Silent
                        $OVServer = $Global:DefaultOVServers | Where {$_.Server -match $OVServer.Server}
                        [xml]$RawContent = Invoke-WebRequest -Uri ($OVServer.Server + $Query) -Method $Method -Headers $OVServer.Headers -ContentType "text/xml" 
                        $RawContent
                    }
                    Else{
                        Write-Error $_
                    }

                }
            }
        }
    }
}

Function Convert-EpochTime {
Param(
    [Parameter(ValueFromPipeline)]$EpochTime
)
    Process{
        ([Datetime]"1/1/1970").AddSeconds($EpochTime) 
    }
}

Function Get-OVInfo {
<# 
.SYNOPSIS
	This function queries the $Global:DefaultOVServers for basic information about the Opsview installations, such as the Version and Timezone
#>
    $RawContent = Invoke-OVQuery -Query "info"
    $RawContent.opsview
}

Function Get-OVHost {
<# 
.SYNOPSIS
	This function queries the $Global:DefaultOVServers for basic information about the hosts it has
#>
    $RawContent = Invoke-OVQuery -Query "status/host"
    $RawContent.opsview.list.ChildNodes
}

Function Get-OVHostGroup {
<# 
.SYNOPSIS
	This function queries the $Global:DefaultOVServers for basic information about the hostgroups it has
#>
    $RawContent = Invoke-OVQuery -Query "status/hostgroup"
    $RawContent.opsview.list.ChildNodes
}

Function Get-OVService {
<# 
.SYNOPSIS
	This function queries the $Global:DefaultOVServers for information on the services that are configured to pull metrics from hosts
#>
    $RawContent = Invoke-OVQuery -Query "status/service"
    $RawContent.opsview.list.ChildNodes.Services.ChildNodes
}

Function Get-OVPerformanceMetric {
<# 
.SYNOPSIS
	This function queries the $Global:DefaultOVServers for performance metrics on the hosts

.PARAMETER hostgroupname
    Includes this host group in list. If the name is associated with more than one host group, all will be included in the response.

.PARAMETER hostname
    Filter hosts by this host name. Can specify wildcards with %.

.PARAMETER Query
    filter services by this service check name. Can specify wildcards with %
#>
Param (
    [Alias("Hostgroup")]$hostgroupname,
    [Alias("Host")]$hostname,
    $hostid,
    [Alias("Metric")]$metricname,
    [Alias("Service")]$servicename
)
    $ParameterList = (Get-Command -Name $MyInvocation.InvocationName).Parameters
    foreach ($key in $ParameterList.keys){
        $Vars = Get-Variable -Name $key -ErrorAction SilentlyContinue
        foreach($Var in $Vars){
            if($Var.value){
                foreach ($Value in $Var.Value){
                    $ReqParams += "$($Var.name)=$($Value)&"
                }
            }
        }
    }
    $Query = "status/performancemetric?" + $ReqParams
    $RawContent = Invoke-OVQuery -Query $Query
    $RawContent.opsview.list.ChildNodes
}


Function Get-OVEvent {
<# 
.SYNOPSIS
	This function queries the $Global:DefaultOVServers for basic information about the events it has
#>
    $RawContent = Invoke-OVQuery -Query "event"
    $RawContent.opsview.list.ChildNodes
}

Function Get-OVDowntime {
<#
.SYNOPSIS
    This function queries the $Global:DefaultOVServers for which hostgroups, hosts & services are currently in downtime
#>
    $RawContent = Invoke-OVQuery -Query "downtime"
    $RawContent.opsview.list.ChildNodes
}

Function Set-OVDowntime {
<#
.SYNOPSIS
    This function will schedule downtime for a hostgroup, host or service
.EXAMPLE
    Set-OVDowntime -host "v3-Farn-Mgmt" -starttime "2020-11-24 14:13:00" -endtime "2020-11-24 14:10:00" -comment "dudley testing setting downtime"
#>
Param (
    [Alias("Hostgroup")]$hostgroupname,
    [Alias("Host")]$hostname,
    $hostid,
    [Alias("Service")]$servicename,
    [Alias("Start")]$starttime,
    [Alias("End")]$endtime,
    $comment
)
    $ParameterList = (Get-Command -Name $MyInvocation.InvocationName).Parameters
    foreach ($key in $ParameterList.keys){
        $Vars = Get-Variable -Name $key -ErrorAction SilentlyContinue
        foreach($Var in $Vars){
            if($Var.value){
                foreach ($Value in $Var.Value){
                    $VariableName = $Var.name
                    if ($VariableName -match "hostname"){
                        $VariableName = "hst.hostname"
                    }
                    elseif ($VariableName -match "hostgroupname"){
                        $VariableName = "hg.hostgroupname"
                    }
                    elseif ($VariableName -match "servicename"){
                        $VariableName = "svc.servicename"
                    }                   
                    $ReqParams += "$VariableName=$($Value)&"
                }
            }
        }
    }
    $Query = "downtime?" + $ReqParams
    Invoke-OVQuery -Method POST -Query $Query
}