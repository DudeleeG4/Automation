<#
.SYNOPSIS
    This function logs to a generic log file.

.DESCRIPTION
    This function when ran is designed to log the following properties:
        * The script's name.
        * The location of the script.
        * The time the script was run.
    
.EXAMPLE
    Write-Log
#>
function Write-UKCloudLogEntry {

    #Create Custom Object and Write the Custom Object to a CSV Log File
    $Entry = [pscustomobject]@{
        Time = (Get-Date -format g)
        Name = [string]$MyInvocation.ScriptName.Split("\")[-1]
        Location = $MyInvocation.ScriptName
        User = $env:USERNAME
    } 
    try {
        $Entry | Export-CSV -path "C:\Scripts\Logging\Logfile.csv" -append -noTypeInformation
        Write-Host "Action Logged."
    }
    catch {
        Write-Host "Unable to write to Log File."
    }
}