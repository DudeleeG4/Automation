### Create filepath
    if ($PSScriptRoot){
        ### Create filepath variable for the ticket data file from the directory the script is run from
        $Filepath = $PSScriptRoot + "\EoMEmailBody.txt"
    }Else{
        ### Filepath variable for testing script in ISE
        $Filepath = "C:\Users\dudley.andrews\Desktop\EoDs" + "\EoMEmailBody.txt"
    }
### Import ticket data from "EoMEmailBody.txt" file contained in the same directory as the script
$EmailBody = Get-Content -Path $Filepath

### Get the HDnumber to use to get the OperatorID later
$HdNumber = ($EmailBody | Select-String "HD Number:") -Split " " | Select -Index 2

### Get the lines with "FAIL" at the start, grab the relevent information and turn them into usable objects
$RawStrings = $EmailBody | Select-String "FAIL"

$EomEntries = Foreach ($RawString in $RawStrings){
    $TrimmedString = $RawString -split " " | Where {$_ -notlike ""}
    [PSCustomObject]@{
        Date = $TrimmedString[1]
        "Session ServiceCharge" = $TrimmedString[2]
        "Session SessionCount" = $TrimmedString[3]
        "EOMSC ServiceCharge" = $TrimmedString[4]
        "EOMSC SessionCount" = $TrimmedString[5]
    }
}

$FdateGroups = @()
$CurrentFdateGroup = @()
Foreach ($EomEntry in $EomEntries){
    $DateObject = $EomEntry.Date | Get-Date
    $Fdate = ([String]$DateObject.Year) + ([String]$DateObject.DayOfYear)



    ### If this is not the first entry, decide whether to group it with the previous entry or whether to start a new group
    If ($PreviousFdate){
        If (([Int]$Fdate -1) -like [Int]$PreviousFdate){
            $CurrentFdateGroup += $Fdate
        }Else{
            ### "Finish" the fdate group by adding current FdateGroup to CurrentFdateGroups array, joined by a comma
            $FdateGroups += $CurrentFdateGroup -join ","

            ### Start new CurrentFdateGroup and add current Fdate to it
            $CurrentFdateGroup = @()
            $CurrentFdateGroup += $Fdate
        }
    }Else{
        ### Add Fdate to $CurrentFdateGroup array
        $CurrentFdateGroup += $Fdate
    }
    $PreviousFdate = $Fdate
}
### Add final Fdate group to $FdateGroups array
$FdateGroups += ($CurrentFdateGroup -join ",")



### Gather user's credentials for Lon and Uxb DB 6
$UxbCreds = Get-Credential -Message "Enter your Uxb Insight DB creds"
$LonCreds = Get-Credential -Message "Enter your Lon Insight DB creds"

### Get the SQL instances used by the script and store then in variables
$UxbInstance = Get-SQLInstance -ServerInstance 192.168.166.206 -Credential $UxbCreds
$LonInstance = Get-SQLInstance -ServerInstance 192.168.178.206 -Credential $LonCreds



### Loop through and find information for each group of dates
Foreach ($FdateGroup in $FdateGroups){
    
    ### Split apart the Fdates so they can be dealt with separately
    $Fdates = $FdateGroup -split ","

    ### Get First and last Fdate dates:
    $FirstFdate = $Fdates | Sort | Select -First 1
    $LastFDate = $Fdates | Sort -Descending | Select -First 1



    ### Query DB to get the OperatorID
    $OperatorQuery = "
    SELECT TOP (1000) *
      FROM [RingGo].[dbo].[RingGo_Operator] WITH (Nolock)
      WHERE HDnumber = " + $HDNumber

    ### Run query to find the Operatorinfo from the HDnumber
    $OperatorQueryResults = Invoke-Sqlcmd -ServerInstance $UxbInstance -Database "Ringgo" -Query $OperatorQuery -Credential $UxbCreds

    ### Pick the OperatorID out of the results and assign to $OperatorID
    $OperatorID = $OperatorQueryResults.Operator_ID



    ### First Query to get Sessions Data:
    $SessionsQuery = "
    SELECT * 
    FROM Sessions WITH (nolock)
    WHERE (operatorId = '$($OperatorID)') AND (F_day BETWEEN '$($FirstFdate)' AND '$($LastFdate)') AND (primaryAuditLink > '') OR
                      (operatorId = '$($OperatorID)') AND (F_day BETWEEN '$($FirstFdate)' AND '$($LastFdate)') AND (primaryAuditLink IS NULL OR
                      primaryAuditLink = '') AND (Session_Quantity = '1')
    ORDER BY PurchaseDate DESC
    "

    $SessionsUxb = Invoke-Sqlcmd -ServerInstance $UxbInstance -Database "Ringgo" -Query $SessionsQuery -Credential $UxbCreds
    $SessionsLon = Invoke-Sqlcmd -ServerInstance $LonInstance -Database "Ringgo" -Query $SessionsQuery -Credential $LonCreds

    $SessionsCombined = @()
    $SessionsCombined += $SessionsUxb
    $SessionsCombined += $SessionsLon

    ### Combine results from both sites and filter out duplicates
    $Sessions = $SessionsCombined | Sort-Object -Property session_Auditlink -Unique



    ### Second Query to get RinggoServceCharge table data
    $ServiceChargeQuery = "
    SELECT *
    FROM     RinggoServiceCharge WITH (nolock)
    WHERE  (operatorid = '$($OperatorID)') AND (f_day BETWEEN '$($FirstFdate)' AND '$($LastFdate)') AND (ItemNumber = 1)
    ORDER BY f_day
    "

    $ServiceChargeUxb = Invoke-Sqlcmd -ServerInstance $UxbInstance -Database "Ringgo" -Query $ServiceChargeQuery -Credential $UxbCreds
    $ServiceChargeLon = Invoke-Sqlcmd -ServerInstance $LonInstance -Database "Ringgo" -Query $ServiceChargeQuery -Credential $LonCreds

    $ServiceChargeCombined = @()
    $ServiceChargeCombined += $ServiceChargeUxb
    $ServiceChargeCombined += $ServiceChargeLon

    ### Combine results from both sites and filter out duplicates
    $ServiceCharges = $ServiceChargeCombined | Sort-Object -Property ID -Unique

    ### Show RingoServiceCharge table results to user
    $ServiceCharges | Out-GridView -Title "RinggoServiceCharge WHERE OperatorID = $($OperatorID) AND F_day BETWEEN $($FirstFdate) AND $($LastFDate)" -PassThru
}
