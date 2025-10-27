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
    $DateObject = $TrimmedString[1] | Get-Date
    $Fday = ([String]$DateObject.Year) + ([String]$DateObject.DayOfYear)
    [PSCustomObject]@{
        Date = $TrimmedString[1]
        Fday = $Fday
        "Session ServiceCharge" = $TrimmedString[2]
        "Session SessionCount" = $TrimmedString[3]
        "EOMSC ServiceCharge" = $TrimmedString[4]
        "EOMSC SessionCount" = $TrimmedString[5]
    }
}



### Gather user's credentials for Lon and Uxb DB 6
$UxbCreds = Get-Credential -Message "Enter your Uxb Insight DB creds"
$LonCreds = Get-Credential -Message "Enter your Lon Insight DB creds"

### Get the SQL instances used by the script and store then in variables
$UxbInstance = Get-SQLInstance -ServerInstance 192.168.166.206 -Credential $UxbCreds
if (!$UxbInstance){
    Write-Host "Uxbridge Insight DB creds invalid or connection failure - please re-run the script"
    Read-Host -Prompt "Press enter to exit"
    Exit
}
$LonInstance = Get-SQLInstance -ServerInstance 192.168.178.206 -Credential $LonCreds
if (!$LonInstance){
    Write-Host "London Insight DB creds invalid or connection failure - please re-run the script"
    Read-Host -Prompt "Press enter to exit"
    Exit
}



### Query DB to get the OperatorID
$OperatorQuery = "
SELECT TOP (1000) *
    FROM [RingGo].[dbo].[RingGo_Operator] WITH (Nolock)
    WHERE HDnumber = " + $HDNumber

### Run query to find the Operatorinfo from the HDnumber
$OperatorQueryResults = Invoke-Sqlcmd -ServerInstance $UxbInstance -Database "Ringgo" -Query $OperatorQuery -Credential $UxbCreds

### Pick the OperatorID out of the results and assign to $OperatorID
$OperatorID = $OperatorQueryResults.Operator_ID



Foreach ($EomEntry in $EomEntries){
    ### First Query to get Sessions Data:
    $SessionsQuery = "
    SELECT * 
    FROM Sessions WITH (nolock)
    WHERE (operatorId = '$($OperatorID)') AND F_day = '$($EomEntry.Fday)' AND (primaryAuditLink > '') OR
                        (operatorId = '$($OperatorID)') AND (F_day = '$($EomEntry.Fday)') AND (primaryAuditLink IS NULL OR
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



    ### Work out what the value of "TotalSessionsCost" should be in RingoServiceCharge by summing the Session_Cost_Total field of all the sessions within the Sessions table
    #$TotalSessionsCost = [String](($Sessions | Measure-Object 'session_Cost_Total' -Sum).sum) + "00"

    ### Work out what the value of "Quantity" should be in RingoServiceCharge by counting the number of sessions in the Sessions table
    #$Quantity = $Sessions.count

    ### Work out whether Fday and LocalPurchaseTime do not match
    Foreach ($Session in $Sessions){
        ### Convert LocalPurchaseTime to Fday format
        $SessionDateObject = $Session.LocalPurchaseTime | Get-Date
        $LocalPurchaseTimeFdayFormat = ([String]$DateObject.Year) + ([String]$DateObject.DayOfYear)

        if ($LocalPurchaseTimeFdayFormat -notlike $Fday){
            Write-Host "Bad session data found for $($Session.primaryAuditLink)"
            
            ### Query to get PaymentAppAudit Data:
            $PAAQuery = "
            SELECT TOP (1000) *
            FROM [Cobalt_Payments].[dbo].[PaymentAppAudit] WITH (nolock)
            Where Fref = '$($Session.FRef)'
            "

            $PAAUxb = Invoke-Sqlcmd -ServerInstance $UxbInstance -Database "Cobalt_Payments" -Query $PAAQuery -Credential $UxbCreds
            If ($PAAUxb.count){
                Write-Host "More than one PAA Entry found for Fref $($Session.Fref) - Skipping"
                Continue
            }Else{
                ### Take the TxDate field and convert the format to match what is expected in the Sessions table
                $CorrectDate = $PAAUxb.TxDate | Get-Date -Format "yyyy-MM-dd hh:mm:ss.fff"

                ### Make the update into both sessions tables - left aligned formatting because it won't work otherwise here
$SessionUpdateBody = @"
UPDATE Sessions
SET PurchaseDate = '$CorrectDate', LocalPurchaseTime = '$CorrectDate', InvoiceDate = '$CorrectDate'
WHERE session_Auditlink = '$($Session.session_Auditlink)'
"@
                ### Print update statement to pipeline for "Whatif" purposes
                $SessionUpdateBody
                
                <#
                Invoke-sqlcmd -ServerInstance $UxbInstance -Database "Ringgo" -Query $SessionUpdateBody -Credential $UxbCreds
                Invoke-Sqlcmd -ServerInstance $LonInstance -Database "Ringgo" -Query $SessionUpdateBody -Credential $LonCreds
                #>
            }
        }
    }

    <#
    ### Second Query to get RinggoServceCharge table data
    $ServiceChargeQuery = "
    SELECT *
    FROM     RinggoServiceCharge WITH (nolock)
    WHERE  (operatorid = '$($OperatorID)') AND (f_day = '$($EomEntry.Fday)') AND (ItemNumber = 1)
    ORDER BY f_day
    "

    $ServiceChargeUxb = Invoke-Sqlcmd -ServerInstance $UxbInstance -Database "Ringgo" -Query $ServiceChargeQuery -Credential $UxbCreds
    $ServiceChargeLon = Invoke-Sqlcmd -ServerInstance $LonInstance -Database "Ringgo" -Query $ServiceChargeQuery -Credential $LonCreds

    $ServiceChargeCombined = @()
    $ServiceChargeCombined += $ServiceChargeUxb
    $ServiceChargeCombined += $ServiceChargeLon

    ### Combine results from both sites and filter out duplicates
    $ServiceCharges = $ServiceChargeCombined | Sort-Object -Property ID -Unique
    #>    
}
