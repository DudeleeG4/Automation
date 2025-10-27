function ConvertTo-DataTable {
    <#
        .SYNOPSIS
            Convert regular PowerShell objects to a DataTable object.

        .DESCRIPTION
            Convert regular PowerShell objects to a DataTable object.

        .EXAMPLE
            $myDataTable = $myObject | ConvertTo-DataTable

        .NOTES
            Name: ConvertTo-DataTable
            Author: Øyvind Kallstad @okallstad
            Version: 1.1
    #>
    [CmdletBinding()]
    param (
        # The object to convert to a DataTable
        [Parameter(ValueFromPipeline = $true)]
        [PSObject[]] $InputObject,

        # Override the default type.
        [Parameter()]
        [string] $DefaultType = 'System.String'
    )

    begin {
    
        # create an empty datatable
        try {
            $dataTable = New-Object -TypeName 'System.Data.DataTable'
            Write-Verbose -Message 'Empty DataTable created'
        }

        catch {
            Write-Warning -Message $_.Exception.Message
            break
        }
        
        # define a boolean to keep track of the first datarow
        $first = $true

        # define array of supported .NET types
		$types = @(
            'System.String',
            'System.Boolean',
            'System.Byte[]',
            'System.Byte',
            'System.Char',
            'System.DateTime',
            'System.Decimal',
            'System.Double',
            'System.Guid',
            'System.Int16',
            'System.Int32',
            'System.Int64',
            'System.Single',
            'System.UInt16',
            'System.UInt32',
            'System.UInt64'
		)
    }

    process {

        # iterate through each input object
        foreach ($object in $InputObject) {
            
            try {

                # create a new datarow
                $dataRow = $dataTable.NewRow()
                Write-Verbose -Message 'New DataRow created'

                # iterate through each object property
                foreach ($property in $object.PSObject.get_properties()) {

                    # check if we are dealing with the first row or not
                    if ($first) {
                    
                        # handle data types
                        if ($types -contains $property.TypeNameOfValue) {
                            $dataType = $property.TypeNameOfValue
                            Write-Verbose -Message "$($property.Name): Supported datatype <$($dataType)>"
                        }

                        else {
                            $dataType = $DefaultType
                            Write-Verbose -Message "$($property.Name): Unsupported datatype ($($property.TypeNameOfValue)), using default <$($DefaultType)>"
                        }

                        # create a new datacolumn
                        $dataColumn = New-Object 'System.Data.DataColumn' $property.Name, $dataType
                        Write-Verbose -Message 'Created new DataColumn'

                        # add column to DataTable
                        $dataTable.Columns.Add($dataColumn)
                        Write-Verbose -Message 'DataColumn added to DataTable'
                    }                  

                    # add values to column
                    if ($property.Value -ne $null) {

                        # if array or collection, add as XML
                        if (($property.Value.GetType().IsArray) -or ($property.TypeNameOfValue -like '*collection*')) {
	                        $dataRow.Item($property.Name) = $property.Value | ConvertTo-Xml -As 'String' -NoTypeInformation -Depth 1
	                        Write-Verbose -Message 'Value added to row as XML'
                        }

                        else{
	                        $dataRow.Item($property.Name) = $property.Value -as $dataType
	                        Write-Verbose -Message "Value ($($property.Value)) added to row as $($dataType)"
                        }
		    }
                }

                # add DataRow to DataTable
                $dataTable.Rows.Add($dataRow)
                Write-Verbose -Message 'DataRow added to DataTable'

                $first = $false
            }

            catch {
                Write-Warning -Message $_.Exception.Message
            }
        }
    }

    end { Write-Output (,($dataTable)) }
}

##################################################################################################################################################################

### Gather user's credentials for Lon and Uxb DB 6
$UxbCreds = Get-Credential -Message "Enter your Uxb Insight DB creds"
$LonCreds = Get-Credential -Message "Enter your Lon Insight DB creds"

### Get the SQL instances used by the script and store then in variables
$UxbInstance = Get-SQLInstance -ServerInstance 192.168.166.206 -Credential $UxbCreds
$LonInstance = Get-SQLInstance -ServerInstance 192.168.178.206 -Credential $LonCreds

### Create filepath variable for the ticket data file from the directory the script is run from
$Filepath = $PSScriptRoot + "\TicketBody.txt"

### Filepath variable for testing script in ISE
#$Filepath = "C:\Users\dudley.andrews\Desktop\EoDs" + "\TicketBody.txt"

### Import ticket data from "TicketBody.txt" file contained in the same directory as the script
$TicketBody = Get-Content -Path $Filepath

### Pull the Frefs out of the ticket data
$Frefs = $TicketBody | Select-String "\[" |%{($_ -Split " " | Select -Index 4).TrimStart("[")}


Foreach ($Fref in $Frefs){
    ### Get primaryauditlink from 
    $SessionsQueryCount = "SELECT TOP (1000) count(*) AS count
                FROM [Ringgo].[dbo].[Sessions] WITH (nolock)
                WHERE Fref = " + "'$FREF'"

    $UxbSessEntry = Invoke-Sqlcmd -ServerInstance $UxbInstance -Database "Ringgo" -Query $SessionsQueryCount -Credential $UxbCreds
    if ($UxbSessEntry.count -like '1'){
    
        "$Fref is a different issue, moving on"
        Continue
    }

    $SessionsQuery = "SELECT TOP (1000) *
    FROM [Ringgo].[dbo].[Sessions] WITH (nolock)
    WHERE Fref = " + "'$FREF'"

    $ExtensionSessions = Invoke-Sqlcmd -ServerInstance $UxbInstance -Database "Ringgo" -Query $SessionsQuery -Credential $UxbCreds | Where {$_.primaryAuditLink -notlike ''}
    $PrimaryAuditLink = $ExtensionSessions.primaryAuditLink



    $Query = "SELECT        TOP (200) *
    FROM            Sessions WITH (nolock)
    WHERE        (session_Auditlink = '" + $PrimaryAuditLink + "') OR
                             (primaryAuditLink = '" + $PrimaryAuditLink + "')"

    $Results = Invoke-Sqlcmd -ServerInstance $UxbInstance -Database "Ringgo" -Query $Query -Credential $UxbCreds


    ## if parent record is fine then final parent record should be the existing parent record - not implemented yet

    $ParentSession = $Results | Where {$_.primaryAuditLink -like ""}
    $ChildSessions = $Results | Where {$_.primaryAuditLink -notlike ""}
    $LatestChildSession = $ChildSessions | Sort-Object -Property session_End -Descending | Select -First 1


    $session_End = $LatestChildSession.session_End
    $ParentSessionAuditLink = $ParentSession.session_Auditlink
    $Session_Cost_SMSConfirm = $ChildSessions.Session_Cost_SMSConfirm | Measure-Object -Sum | Select -ExpandProperty Sum
    $Session_Cost_SMSEnd = $ChildSessions.Session_Cost_SMSEnd | Measure-Object -Sum | Select -ExpandProperty Sum
    $Session_Cost_Charge = $ChildSessions.Session_Cost_Charge | Measure-Object -Sum | Select -ExpandProperty Sum
    $Session_Cost_ParkingZone = $ChildSessions.Session_Cost_ParkingZone | Measure-Object -Sum | Select -ExpandProperty Sum
    $Session_Cost_Total = $ChildSessions.Session_Cost_Total | Measure-Object -Sum | Select -ExpandProperty Sum
    $Session_Quantity = $ChildSessions.Session_Quantity | Sort-Object -Descending | Select -First 1
    $Session_wantedTime = $ChildSessions.Session_wantedTime | Measure-Object -Sum | Select -ExpandProperty Sum
    $Paid_Time = $ChildSessions.Paid_Time | Measure-Object -Sum | Select -ExpandProperty Sum
    $FixedFRef = $LatestChildSession.Fref
    $PurchaseDate = $LatestChildSession.PurchaseDate
    $LocalPurchaseTime = $LatestChildSession.LocalPurchaseTime
    $service_charge = $ChildSessions.Service_charge | Measure-Object -Sum | Select -ExpandProperty Sum
    $ConfirmSMSChargeToOperator = $ChildSessions.ConfirmSMSChargeToOperator | Measure-Object -Sum | Select -ExpandProperty Sum
    $ReminderSMSChargeToOperator = $ChildSessions.ReminderSMSChargeToOperator | Measure-Object -Sum | Select -ExpandProperty Sum
    $ExtEnforcementUpdateDate = $LatestChildSession.ExtEnforcementUpdateDate
    $Session_Cost_SMSStop = $ChildSessions.Session_Cost_SMSStop | Measure-Object -Sum | Select -ExpandProperty Sum
    $StopSMSChargeToOperator = $ChildSessions.StopSMSChargeToOperator | Measure-Object -Sum | Select -ExpandProperty Sum
    $InvoiceDate = $LatestChildSession.InvoiceDate
    $BaseParkingCost = $ChildSessions.BaseParkingCost | Measure-Object -Sum | Select -ExpandProperty Sum


    $FixedParentSession = [PSCustomObject]@{
        Parking_Zone = $ParentSession.Parking_Zone
        session_Start = $ParentSession.session_Start
        session_End = $session_End
        session_Auditlink = $ParentSession.session_Auditlink
        session_Counter = $ParentSession.session_Counter
        UserId = $ParentSession.UserId
        CLI = $ParentSession.CLI
        session_ActiveReset = $ParentSession.session_ActiveReset
        session_Tariff_Type = $ParentSession.session_Tariff_Type
        session_Tariff_ID = $ParentSession.session_Tariff_ID
        Members_CardNumber = $ParentSession.Members_CardNumber
        VRN = $ParentSession.VRN
        Make = $ParentSession.Make
        Colour = $ParentSession.Colour
        Session_Cost_SMSConfirm = $Session_Cost_SMSConfirm
        Session_Cost_SMSEnd = $Session_Cost_SMSEnd
        session_ReceiptViewedDate = $ParentSession.session_ReceiptViewedDate
        Session_Cost_Charge = $Session_Cost_Charge
        Service_Charge_REMOVE = $ParentSession.Service_Charge_REMOVE
        Session_Cost_ParkingZone = $Session_Cost_ParkingZone
        Session_Cost_UnitPrice = $ParentSession.Session_Cost_UnitPrice
        Session_Cost_Total = $Session_Cost_Total
        Session_Quantity = $Session_Quantity
        Session_wantedTime = $Session_wantedTime
        Passenger_Code = $ParentSession.Passenger_Code
        Paid_Time = $Paid_Time
        F_day = $ParentSession.F_day
        Authcode = $ParentSession.Authcode
        Flags = $ParentSession.Flags
        FRef = $FixedFRef
        TariffRowSecLen = $ParentSession.TariffRowSecLen
        primaryAuditLink = $ParentSession.primaryAuditLink
        ParkingVatRate = $ParentSession.ParkingVatRate
        SundryVatRate = $ParentSession.SundryVatRate
        operatorId = $ParentSession.operatorId
        corporateid = $ParentSession.corporateid
        co2charging = $ParentSession.co2charging
        bay = $ParentSession.bay
        OperatorCardSurcharge = $ParentSession.OperatorCardSurcharge
        CardSurchargeCost = $ParentSession.CardSurchargeCost
        PurchaseDate = $PurchaseDate
        interface = $ParentSession.interface
        PermitType = $ParentSession.PermitType
        VehicleType = $ParentSession.VehicleType
        TowingType = $ParentSession.TowingType
        JournalType = $ParentSession.JournalType
        JournalCost = $ParentSession.JournalCost
        DisabledBadgeHolder = $ParentSession.DisabledBadgeHolder
        OAP = $ParentSession.OAP
        Rover = $ParentSession.Rover
        OnStreet = $ParentSession.OnStreet
        Resident = $ParentSession.Resident
        SentVATreceipt = $ParentSession.SentVATreceipt
        ParkNride = $ParentSession.ParkNride
        DispensationType = $ParentSession.DispensationType
        BaysOccupied = $ParentSession.BaysOccupied
        VATinvoiceID = $ParentSession.VATinvoiceID
        SiteTaken = $ParentSession.SiteTaken
        CountryCode = $ParentSession.CountryCode
        TZOffsetMins = $ParentSession.TZOffsetMins
        ParkingBay = $ParentSession.ParkingBay
        LocalPurchaseTime = $LocalPurchaseTime
        KnownUser = $ParentSession.KnownUser
        AcquirerServiceCharge = $ParentSession.AcquirerServiceCharge
        service_charge = $service_charge
        co2Band = $ParentSession.co2Band
        ConfirmSMSChargeToOperator = $ConfirmSMSChargeToOperator
        ReminderSMSChargeToOperator = $ReminderSMSChargeToOperator
        ExtEnforcementStatus = $ParentSession.ExtEnforcementStatus
        ExtEnforcementUpdateId = $ParentSession.ExtEnforcementUpdateId
        ExtEnforcementUpdateDate = $ExtEnforcementUpdateDate
        MultiplyFactor = $ParentSession.MultiplyFactor
        BackOfficeMark = $ParentSession.BackOfficeMark
        WalletId = $ParentSession.WalletId
        ChargeMethod = $ParentSession.ChargeMethod
        Tzid = $ParentSession.Tzid
        Session_Cost_SMSStop = $Session_Cost_SMSStop
        StopSMSChargeToOperator = $StopSMSChargeToOperator
        InvoiceDate = $InvoiceDate
        BaseParkingCost = $BaseParkingCost
        YOMsurcharge = $ParentSession.YOMsurcharge
    }

    $Report = @()
    $Report += $FixedParentSession | ConvertTo-DataTable
    $Report += $ChildSessions
    $Report | Out-GridView -Title "Please check that this looks okay"

    Remove-Variable UserChoice
    $UserChoice = Read-Host "Please check that everything looks okay with $ParentSessionAuditLink. Enter 'Y' to apply fix, or anything else to skip"
    If ($UserChoice -like "Y"){

    ### Create update query - has to be fully left aligned for formatting reasons
$UpdateResults = @"
UPDATE Sessions
SET session_end = '$session_End', session_Cost_SMSConfirm = '$Session_Cost_SMSConfirm', Session_Cost_SMSEnd = '$Session_Cost_SMSEnd', Session_Cost_Charge = '$Session_Cost_Charge', Session_Cost_ParkingZone = '$Session_Cost_ParkingZone', Session_Cost_Total = '$Session_Cost_Total', Session_Quantity = '$Session_Quantity', Session_wantedTime = '$Session_wantedTime', Paid_Time = '$Paid_Time', Fref = '$FixedFRef', PurchaseDate = '$PurchaseDate', LocalPurchaseTime = '$LocalPurchaseTime', service_charge = '$service_charge', ConfirmSMSChargeToOperator = '$ConfirmSMSChargeToOperator', ReminderSMSChargeToOperator = '$ReminderSMSChargeToOperator', ExtEnforcementUpdateDate = '$ExtEnforcementUpdateDate', Session_Cost_SMSStop = '$Session_Cost_SMSStop', StopSMSChargeToOperator = '$StopSMSChargeToOperator', InvoiceDate = '$InvoiceDate', BaseParkingCost = '$BaseParkingCost'
WHERE session_Auditlink = '$ParentSessionAuditLink'
"@

        Invoke-sqlcmd -ServerInstance $UxbInstance -Database "Ringgo" -Query $UpdateResults -Credential $UxbCreds
        Invoke-Sqlcmd -ServerInstance $LonInstance -Database "Ringgo" -Query $UpdateResults -Credential $LonCreds
    }Else{
    Write-Host "Skipping $Fref"
    }
}





