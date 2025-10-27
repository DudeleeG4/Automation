add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

############################################################################################################################################################################

### Gather user's credentials for PR-DB-LS-01.cobalt-lon1.ctt.co.uk
$Creds = Get-Credential -Message "Enter your Insight DB creds"


Do {
### Get the SQL instance used by the script and store in variable
$DBInstance = Get-SqlInstance -ServerInstance PR-DB-LS-01.cobalt-lon1.ctt.co.uk -Credential $Creds

### Initial query to find the permits that are missing entries in AdditionalSessionValues
$InitialQuery = "SELECT DISTINCT t1.id, t1.OperatorId as arg2, t1.AccountTypeId, t1.created, t1.AcceptVRN,t2.VRM as arg3, t1.UserId, t3.auditlink
FROM [Ringgo].[dbo].[ResidentVisitorPermits] t1 with(nolock)
inner join RingGo.dbo.LaPermitAcceptVRMs t2 with(nolock) ON t1.id = t2.LAPermitID
inner join RingGo.dbo.LAPermitSessionLinks t3 with(nolock) ON t1.id = t3.RVPrecid
left join RingGo.dbo.AdditionalSessionValues t4 with(Nolock) ON t3.Auditlink = t4.auditlink
left join RingGo.dbo.[Sessions] t5 with(NoLock) ON t5.session_Auditlink = t3.Auditlink
where t1.validto >= dateadd(hour, +1, getdate()) 
AND t1.status NOT IN (9,11,5,3)
AND t4.id IS NULL 
AND t1.AccountTypeId <> 'SPG'
AND NOT t2.VRM like t1.AcceptVRN
AND t5.session_End > getdate()
order by Created desc"

$DBQueryResults = Invoke-Sqlcmd -ServerInstance $DBInstance -Database "Ringgo" -Query $InitialQuery -Credential $Creds

Write-Host "Number of sessions found: $($DBQueryResults.count)"

$Report = @()
$LoopCount = 0
$RateLimitCount = 0
$Progress = 0
Foreach ($DBQueryResult in $DBQueryResults){
    $Progress ++

    ### Write-Progress bar for user to see the progress
    Write-Progress -Activity "Looping through and fixing records" -CurrentOperation "Current Permit: $($DBQueryResult.id)" -PercentComplete ($Progress/$DBQueryResults.Count*100) -Id 0

    ### Search for the vehicle details using the VRN from the LaPermitAcceptVRMs table entry, and the UserID
    $MemberVehiclesQuery = "SELECT TOP (1000)
      [vehicleid],
      [VRN]
    FROM [Ringgo].[dbo].[RingGo_Members_Vehicles] WITH (nolock)
    WHERE VRN = '" + $DBQueryResult.arg3 + "' AND UserID = '" + $DBQueryResult.UserId + "'"

    ### Query DB
    $MembersVehicles = Invoke-Sqlcmd -ServerInstance $DBInstance -Database "Ringgo" -Query $MemberVehiclesQuery -Credential $Creds
    
    ### Retrieve the session for the permit
    $SessionsQuery = "SELECT TOP 1000 *
      FROM [Ringgo].[dbo].[Sessions] WITH (nolock)
      WHERE session_Auditlink = '" + $DBQueryResult.auditlink + "'"

    ### Query DB
    $Session = Invoke-Sqlcmd -ServerInstance $DBInstance -Database "Ringgo" -Query $SessionsQuery -Credential $Creds
   
    Clear-Variable Count -ErrorAction SilentlyContinue
    ### Populate and error check variables before doing the insert
    $Expires = $Session.session_End
    If ($Expires.count -ne 1){
        If (!$Expires){$Count = 0}
        Else{
            $Count = $Expires.count
        }
        $ErrMssg = "`nERROR - $($Count) entries found in Sessions table for permit ID $($DBdQueryResult.id) is not 1 - skipping`n"
        Write-Host $ErrMssg
        #$Report += $ErrMssg
        Continue
    }
    $Arg1 = $MembersVehicles.vehicleid
    If ($Arg1.count -ne 1){
        If (!$Arg1){$Count = 0}
        Else{
            $Count = $Arg1.count
        }
        $ErrMssg = "`nERROR - $($Count) entries found in RingGo_Members_Vehicles table  for permit ID $($DBQueryResult.id) - skipping`n"
        Write-Host $ErrMssg
        #$Report += $ErrMssg
        Continue  
    }   
    $Arg2 = $Session.operatorId
    If ($Arg2.count -ne 1){
        If (!$Arg2){$Count = 0}
        Else{
            $Count = $Arg2.count
        }
        $ErrMssg = "`nERROR - $($Count) entries found in Sessions table  for permit ID $($DBQueryResult.id) - skipping`n"
        Write-Host $ErrMssg
        #$Report += $ErrMssg
        Continue  
    }
    $Arg3 = $MembersVehicles.VRN
    If ($Arg3.count -ne 1){
        If (!$Arg3){$Count = 0}
        Else{
            $Count = $Arg3.count
        }
        $ErrMssg = "`nERROR - $($Count) entries found in RingGo_Members_Vehicles table  for permit ID $($DBQueryResult.id) - skipping`n"
        Write-Host $ErrMssg
        #$Report += $ErrMssg
        Continue  
    }
    $UserID = $DBQueryResult.UserId
    $Created = $Session.PurchaseDate
    If ($Created.count -ne 1){
        If (!$Created){$Count = 0}
        Else{
            $Count = $Created.count
        }
        $ErrMssg = "`nERROR - $($Count) entries found in Sessions table for permit ID $($DBQueryResult.id) is not 1 - skipping`n"
        Write-Host $ErrMssg
        #$Report += $ErrMssg
        Continue
    }
    $ArwenID = New-Guid
    $Auditlink = $DBQueryResult.auditlink

    ### Implement rate limiting as the "resync enforcement" call should be limited to 10 per second
    if ($LoopCount -like 9){
        $LoopCount = 0
        $RateLimitCount ++
        Write-Host "Rate limited $RateLimitCount times - (Limited to 10 per second)"
        Start-Sleep -Seconds 1
    }Else{
        $LoopCount ++
    }
        ### insert new row into AdditionalSessionValues table (must be left-aligned in code for formatting reasons)
$InsertResults = @"
INSERT INTO AdditionalSessionValues ( arwenid, dataType, expires, arg1, arg2, arg3, userid, Created, auditlink )
VALUES ('$ArwenID','3','$Expires','$Arg1','$Arg2','$Arg3','$UserId','$Created', '$Auditlink')
"@
        ### Write insert call to log
        $Report += $InsertResults
        
        ### Do the database inserts
        Invoke-sqlcmd -ServerInstance $DBInstance -Database "Ringgo" -Query $InsertResults -Credential $Creds
        

        ### Now call "resync enforcement" to update enforcement with the new vehicle data
        $ResyncEnforcementEP = "https://192.168.166.102:9098/robotringgo?Do=SYNCENF&A=" + $Auditlink

        ### Write API call to log
        $Report += "Calling $ResyncEnforcementEP"

        ### Call "resync enforcement"
        $ResyncEnfResults = Invoke-WebRequest $ResyncEnforcementEP

        ### Write "resync enforcement" results to log
        $Report += $ResyncEnfResults.Content
}

$Date = Get-Date -Format ddMMyy-hhmm
 ### Create output path
    if ($PSScriptRoot){
    ### Filepath for running as script - same directory as script
        $Filepath = $PSScriptRoot + "\MultipleVRNsLog-" + $Date + ".txt"
    }else{
    ### Filepath for testing from ISE:
        $Filepath = "C:\Users\dudley.andrews\Desktop" + "\MultipleVRNsLog-" + $Date + ".txt"
    }
if ($Report){
    $Report | Out-File $Filepath
    Write-Host "Log generated at: $Filepath"
}

Write-Progress -Activity "Looping through and fixing records" -Completed -Id 0

### Clean up variables for next loop
Remove-Variable InsertResults, Report, Filepath, ResyncEnfResults, ResyncEnforcementEP -ErrorAction SilentlyContinue

$TimeLimit = 300
$Seconds = 0
$StartTime = $(get-date)
Do {
Start-Sleep -Seconds 1
$Seconds ++
$secondsRemaining = $TimeLimit - $Seconds
Write-Progress -Activity "Run complete" -Status "Waiting for next run."  -SecondsRemaining $secondsRemaining
}while ($Seconds -lt 300)

}while ((Get-Date) -lt (Get-Date).AddMonths(1))

Read-Host -Prompt "Press enter to exit"