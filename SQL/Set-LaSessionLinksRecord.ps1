### Gather user's credentials for Lon and Uxb DB 6
#$UxbCreds = Get-Credential -Message "Enter your Uxb Insight DB creds"
$LonCreds = Get-Credential -Message "Enter your Insight DB creds"

### Get the SQL instances used by the script and store then in variables
#$UxbInstance = Get-SQLInstance -ServerInstance 192.168.166.206 -Credential $UxbCreds
$LonInstance = Get-SQLInstance -ServerInstance PR-DB-LS-01.cobalt-lon1.ctt.co.uk -Credential $LonCreds

$InitialQuery = "SELECT top 1000 Parking_Zone,
VRN,
s.session_Auditlink,
s.UserId,
s.PermitType,
s.PurchaseDate,
s.LocalPurchaseTime,
s.session_Start,
s.session_End,
s.operatorId
FROM [RingGo].[dbo].Sessions s WITH (nolock) left JOIN [RingGo].[dbo].LAPermitSessionLinks P ON s.session_Auditlink = P.Auditlink 
WHERE s.session_end >= dateadd(hour, +1, getdate()) AND PurchaseDate <= dateadd(hour, -1, getdate()) AND s.PermitType not in (0,1,83,105) AND P.auditlink is null
ORDER BY session_End"

#$UxbQueryResults = Invoke-Sqlcmd -ServerInstance $UxbInstance -Database "Ringgo" -Query $InitialQuery -Credential $UxbCreds
$LonQueryResults = Invoke-Sqlcmd -ServerInstance $LonInstance -Database "Ringgo" -Query $InitialQuery -Credential $LonCreds

#Write-Host "Number of Uxbridge sessions found: $($UxbQueryResults.count)"
Write-Host "Number of sessions found: $($LonQueryResults.count)"

$QueryResultsCombined = @()
$QueryResultsCombined += $UxbQueryResults
$QueryResultsCombined += $LonQueryResults

$DeduplicatedQueryResults = $QueryResultsCombined | Sort-Object -Property session_Auditlink -Unique

Foreach ($Entry in $DeduplicatedQueryResults){
    if($UserID){Clear-Variable UserID}
    $UserID = $Entry.UserId
    $PermitsQuery = "SELECT TOP (1000) *
      FROM [RingGo].[dbo].[ResidentVisitorPermits]with(nolock)
      WHERE [Userid] = " + "'$UserID'
      AND NOT Status in (3,4,5,9,11)"

    if ($PermitsCombined){Clear-Variable PermitsCombined}
    $PermitsCombined = @()
    #$UxbPermitsResults = Invoke-Sqlcmd -ServerInstance $UxbInstance -Database "Ringgo" -Query $PermitsQuery -Credential $UxbCreds
    $LonPermitsResults = Invoke-Sqlcmd -ServerInstance $LonInstance -Database "Ringgo" -Query $PermitsQuery -Credential $LonCreds

    $PermitsCombined += $UxbPermitsReults
    $PermitsCombined += $LonPermitsResults

    if ($PermitsCombined){
        $Entry | Out-GridView -Title "Please review this session:"
        $ChosenPermit = $PermitsCombined | Out-GridView -Title "Please select the permit to link with this session:" -PassThru

        if($Auditlink){Clear-Variable Auditlink}
        if($RVPrecid){Clear-Variable RVPrecid}
        if($Created){Clear-Variable Created}
        if($PermitType){Clear-Variable PermitType}
        $Auditlink = $Entry.session_Auditlink
        $RVPrecid = $ChosenPermit.Id
        $Created = $Entry.PurchaseDate
        $PermitType = $Entry.PermitType

    ### insert new row into sessions table:
$InsertResults = @"
INSERT INTO LAPermitSessionLinks ( Auditlink, RVPrecid, Created , userid, permitType )
VALUES ('$Auditlink','$RVPrecid','$Created','$UserId','$PermitType')
"@

        Invoke-sqlcmd -ServerInstance $LonInstance -Database "Ringgo" -Query $InsertResults -Credential $LonCreds


    }else {
        Write-Host "Error! Somethings gone wrong lol"
        Continue
    }
}
