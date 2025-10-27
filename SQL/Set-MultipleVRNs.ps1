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

### Gather user's credentials for Lon and Uxb DB 6
$UxbCreds = Get-Credential -Message "Enter your Uxb Insight DB creds"
$LonCreds = Get-Credential -Message "Enter your Lon Insight DB creds"

### Get the SQL instances used by the script and store then in variables
$UxbInstance = Get-SQLInstance -ServerInstance 192.168.166.206 -Credential $UxbCreds
$LonInstance = Get-SQLInstance -ServerInstance 192.168.178.206 -Credential $LonCreds

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

$UxbQueryResults = Invoke-Sqlcmd -ServerInstance $UxbInstance -Database "Ringgo" -Query $InitialQuery -Credential $UxbCreds
$LonQueryResults = Invoke-Sqlcmd -ServerInstance $LonInstance -Database "Ringgo" -Query $InitialQuery -Credential $LonCreds

Write-Host "Number of Uxbridge sessions found: $($UxbQueryResults.count)"
Write-Host "Number of London sessions found: $($LonQueryResults.count)"

$QueryResultsCombined = @()
$QueryResultsCombined += $UxbQueryResults
$QueryResultsCombined += $LonQueryResults

### Combine results from both sites and filter out duplicates
$DeduplicatedQueryResults = $QueryResultsCombined | Sort-Object -Property auditlink -Unique

$Report = @()
$LoopCount = 0
$RateLimitCount = 0
$Progress = 0
Foreach ($DeduplicatedQueryResult in $DeduplicatedQueryResults){
    $Progress ++

    ### Write-Progress bar for user to see the progress
    Write-Progress -Activity "Looping through and fixing records" -CurrentOperation "Current Permit: $($DeduplicatedQueryResult.id)" -PercentComplete ($Progress/$DeduplicatedQueryResults.Count*100)

    ### Search for the vehicle details using the VRN from the LaPermitAcceptVRMs table entry, and the UserID
    $MemberVehiclesQuery = "SELECT TOP (1000)
      [vehicleid],
      [VRN]
    FROM [Ringgo].[dbo].[RingGo_Members_Vehicles] WITH (nolock)
    WHERE VRN = '" + $DeduplicatedQueryResult.arg3 + "' AND UserID = '" + $DeduplicatedQueryResult.UserId + "'"

    ### Query both DBs
    $UxbMembersVehicles = Invoke-Sqlcmd -ServerInstance $UxbInstance -Database "Ringgo" -Query $MemberVehiclesQuery -Credential $UxbCreds
    $LonMembersVehicles = Invoke-Sqlcmd -ServerInstance $LonInstance -Database "Ringgo" -Query $MemberVehiclesQuery -Credential $LonCreds
    
    $MembersVehiclesCombined = @()
    $MembersVehiclesCombined += $UxbMembersVehicles
    $MembersVehiclesCombined += $LonMembersVehicles

    ### Members Vehicles Variable
    $DeduplicatedMembersVehicles = $MembersVehiclesCombined | Sort-Object -Property vehicleid -Unique
    
    ### Retrieve the session for the permit
    $SessionsQuery = "SELECT TOP 1000 *
      FROM [Ringgo].[dbo].[Sessions] WITH (nolock)
      WHERE session_Auditlink = '" + $DeduplicatedQueryResult.auditlink + "'"

    ### Query both DBs
    $UxbSession = Invoke-Sqlcmd -ServerInstance $UxbInstance -Database "Ringgo" -Query $SessionsQuery -Credential $UxbCreds
    $LonSession = Invoke-Sqlcmd -ServerInstance $LonInstance -Database "Ringgo" -Query $SessionsQuery -Credential $LonCreds
    
    $SessionsCombined = @()
    $SessionsCombined += $UxbSession
    $SessionsCombined += $LonSession
    
    ### Session variable
    $DeduplicatedSession = $SessionsCombined | Sort-Object -Property session_Auditlink -Unique
    <#If (($DeduplicatedSession.session_End | Get-Date) -lt (Get-Date)){
        $ErrMssg = "`nINFO - Expired session found for current permit $($DeduplicatedQueryResult.id) - Skipping`n"
        Write-Host $ErrMssg
        $Report += $ErrMssg
        Continue
    }#>
   
    Clear-Variable Count -ErrorAction SilentlyContinue
    ### Populate and error check variables before doing the insert
    $Expires = $DeduplicatedSession.session_End
    If ($Expires.count -ne 1){
        If (!$Expires){$Count = 0}
        Else{
            $Count = $Expires.count
        }
        $ErrMssg = "`nERROR - $($Count) entries found in Sessions table for permit ID $($DeduplicatedQueryResult.id) is not 1 - skipping`n"
        Write-Host $ErrMssg
        $Report += $ErrMssg
        Continue
    }
    $Arg1 = $DeduplicatedMembersVehicles.vehicleid
    If ($Arg1.count -ne 1){
        If (!$Arg1){$Count = 0}
        Else{
            $Count = $Arg1.count
        }
        $ErrMssg = "`nERROR - $($Count) entries found in RingGo_Members_Vehicles table  for permit ID $($DeduplicatedQueryResult.id) - skipping`n"
        Write-Host $ErrMssg
        $Report += $ErrMssg
        Continue  
    }   
    $Arg2 = $DeduplicatedSession.operatorId
    If ($Arg2.count -ne 1){
        If (!$Arg2){$Count = 0}
        Else{
            $Count = $Arg2.count
        }
        $ErrMssg = "`nERROR - $($Count) entries found in Sessions table  for permit ID $($DeduplicatedQueryResult.id) - skipping`n"
        Write-Host $ErrMssg
        $Report += $ErrMssg
        Continue  
    }
    $Arg3 = $DeduplicatedMembersVehicles.VRN
    If ($Arg3.count -ne 1){
        If (!$Arg3){$Count = 0}
        Else{
            $Count = $Arg3.count
        }
        $ErrMssg = "`nERROR - $($Count) entries found in RingGo_Members_Vehicles table  for permit ID $($DeduplicatedQueryResult.id) - skipping`n"
        Write-Host $ErrMssg
        $Report += $ErrMssg
        Continue  
    }
    $UserID = $DeduplicatedQueryResult.UserId
    $Created = $DeduplicatedSession.PurchaseDate
    If ($Created.count -ne 1){
        If (!$Created){$Count = 0}
        Else{
            $Count = $Created.count
        }
        $ErrMssg = "`nERROR - $($Count) entries found in Sessions table for permit ID $($DeduplicatedQueryResult.id) is not 1 - skipping`n"
        Write-Host $ErrMssg
        $Report += $ErrMssg
        Continue
    }
    $ArwenID = New-Guid
    $Auditlink = $DeduplicatedQueryResult.auditlink

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
        Invoke-sqlcmd -ServerInstance $UxbInstance -Database "Ringgo" -Query $InsertResults -Credential $UxbCreds
        Invoke-sqlcmd -ServerInstance $LonInstance -Database "Ringgo" -Query $InsertResults -Credential $LonCreds
        

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
$Report | Out-File $Filepath

Write-Host "Log generated at: $Filepath"
Read-Host -Prompt "Press enter to exit"