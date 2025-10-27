Function Get-DayList{
    $TheDayToday = (Get-Date).Day
    $DateCounter = 0

    Do{
        $Date = (Get-Date).AddDays($DateCounter)
        $DateNumber = ($Date.Day + 1)
        $Date
        $DateCounter ++
    }Until(
    $DateNumber -eq $TheDayToday
    )
}


########################################################################################################################################################################

### Create filepath
        if ($PSScriptRoot){
            ### Create filepath variable for the source file from the directory the script is run from
            $Filepath = $PSScriptRoot + "\Event Day Script Testing.xlsx"
        }Else{
            ### Filepath variable for the source file for testing script in ISE
            $Filepath = "C:\Users\dudley.andrews\Desktop\EoDs" + "\Event Day Script Testing.xlsx"
        }


$Sheet = Import-Excel $Filepath

### Gather user's credentials for Lon and Uxb DB 6
$UxbCreds = Get-Credential -Message "Enter your Uxb Insight DB creds"
#$LonCreds = Get-Credential -Message "Enter your Lon Insight DB creds"

### Get the SQL instances used by the script and store then in variables
$UxbInstance = Get-SQLInstance -ServerInstance 192.168.166.206 -Credential $UxbCreds
if (!$UxbInstance){
    Write-Host "Uxbridge Insight DB creds invalid or connection failure - please re-run the script"
    Read-Host -Prompt "Press enter to exit"
    Exit
}
<#$LonInstance = Get-SQLInstance -ServerInstance 192.168.178.206 -Credential $LonCreds
if (!$LonInstance){
    Write-Host "London Insight DB creds invalid or connection failure - please re-run the script"
    Read-Host -Prompt "Press enter to exit"
    Exit
}#>

$BankHolidaysQuery = "SELECT TOP 1000 *
    FROM RingGo_BankHoliday with (NOLOCK)
    ORDER BY BHoliday Desc"

$BankHolidayResults = Invoke-Sqlcmd -ServerInstance $UxbInstance -Database "RingGo_Config" -Query $BankHolidaysQuery -Credential $UxbCreds

$BankHolidays = @()
Foreach ($BankHolidayResult in $BankHolidayResults){
    $BankHolidays += $BankHolidayResult.BHoliday.Insert(4,'-').Insert(7,'-') | Get-Date
}

### Filter out bank holidays from the past
$RelevantBankHolidays = $BankHolidays | Where {$_ -gt (Get-Date)}

### Pull the data from the spreadsheet and format it correctly
$DesiredZoneRules = Foreach ($Zone in $Sheet){

    ### Format the Date data - the form the customers fill in needs to have formatting rules enforced because this WILL cause problems otherwise
    $WeekdayStart = (($Zone.'Weekday Start').ToString()).Split(" ") | Select -Last 1
    $WeekdayEnd = (($Zone.'Weekday End').ToString()).Split(" ") | Select -Last 1

    $SaturdayStart = (($Zone.'Saturday Start').ToString()).Split(" ") | Select -Last 1
    $SaturdayEnd = (($Zone.'Saturday End').ToString()).Split(" ") | Select -Last 1


    $SundayStart = (($Zone.'Sunday & Bank Hol Start').ToString()).Split(" ") | Select -Last 1
    $SundayEnd = (($Zone.'Sunday & Bank Hol End').ToString()).Split(" ") | Select -Last 1

    [PSCustomObject]@{
        "Tarrif ID" = ($Zone."Tariff ID").ToString()
        "Zone num" = ($Zone."Zone Num").ToString()
        #"Zone name" = ($Zone."Zone name").ToString()
        "Weekdays" = [PSCustomObject]@{
            Start = "{0:HH:mm:ss}" -f [Datetime]$WeekdayStart
            End = "{0:HH:mm:ss}" -f [Datetime]$WeekdayEnd
            }
        "Saturdays" = [PSCustomObject]@{
            Start = "{0:HH:mm:ss}" -f [Datetime]$SaturdayStart
            End = "{0:HH:mm:ss}" -f [Datetime]$SaturdayEnd
            }
        "Sunday & Bank Hols" = [PSCustomObject]@{
            Start = "{0:HH:mm:ss}" -f [Datetime]$SundayStart
            End = "{0:HH:mm:ss}" -f [Datetime]$SundayEnd
            }
        #"Notes" = ($Zone."Notes").ToString()
    }
}

### Group the zone rules via their zone number - this isn't strictly necessary but allows for easier troubleshooting in case of multiple entries
$ZoneGroups = $DesiredZoneRules | Group-Object -Property "Zone num"

### Loop through each zone group and pull the event days for each zone
$Progress = 0
$Results = Foreach ($ZoneGroup in $ZoneGroups){
    Write-Progress -Activity "Looping through Zone Groups" -PercentComplete ($Progress/$ZoneGroups.count*100)

    ### Loop through each zone in the zone group and do a DB query for the event days for just that zone
    Foreach ($FormattedZone in $ZoneGroup.Group){

        $EventDaysQuery = "SELECT TOP (200) *
        FROM EventDays with (NOLOCK)
        WHERE Zone = '$($FormattedZone."Zone num")'
        AND Date >= GETDATE()" 

        $UxbEventDays = Invoke-Sqlcmd -ServerInstance $UxbInstance -Database "Ringgo" -Query $EventDaysQuery -Credential $UxbCreds
        #$LonEventDays = Invoke-Sqlcmd -ServerInstance $LonInstance -Database "Ringgo" -Query $EventDaysQuery -Credential $LonCreds

        #Write-Host "Number of Uxbridge Event Days found: $($UxbEventDays.count)"
        #Write-Host "Number of London Event Days found: $($LonEventDays.count)"

        $EventDaysCombined = @()
        $EventDaysCombined += $UxbEventDays
        $EventDaysCombined += $LonEventDays

        ### Combine results from both sites and filter out duplicates
        $EventDays = $EventDaysCombined | Sort-Object -Property Counter -Unique

        #$FormattedZone | Out-GridView -Title "What the customer wants:"
        #$EventDays | Out-GridView -Title "What is currently configured:" -PassThru

        Foreach ($EventDay in $EventDays){
            If ($RelevantBankHolidays -contains ($EventDay.Date | Get-Date)){
                $IsBankHoliday = "True"
            }Else{$IsBankHoliday = "False"}

            [PSCustomObject]@{
                Zone = $EventDay.Zone
                Date = $EventDay.Date
                PSDate = $EventDay.Date | Get-Date
                Notes = $EventDay.Notes
                DayOfWeek = ($EventDay.Date | Get-Date).DayOfWeek
                BankHoliday = $IsBankHoliday
                Counter = $EventDay.Counter
                VisibleFrom = $EventDay.VisibleFrom
                CountryCode = $EventDay.CountryCode
                ZoneSelectNote = $EventDay.ZoneSelectNote
                SessionConfirmationNote = $EventDay.sessionconfirmationnote
                StartTime = $EventDay.StartTime
                EndTime = $EventDay.EndTime
                StartDate = $EventDay.StartDate
                EndDate = $EventDay.EndDate
                OperatorID = $EventDay.OperatorId
                TariffId = $EventDay.TarrifId
                RowGUID = $EventDay.rowguid
            }
        }
    }
    $Progress ++
}


$DayList = Get-DayList

### Loop through each day within the next month to build a list of event days that are just for the next month
### It has been done like this rather than simply filtering by date ranges because the script was originally intended to be used a different way
### However, this is still a handy bit of code to have saved, so I've kept it this way, even though it's inefficient - this is also why a large portion is commented out
$Progress2 = 0
$FinalResults = Foreach ($Day in $DayList){
    Write-Progress -Activity "Gathering configured event days for the next month" -PercentComplete ($Progress2/$DayList.count*100)
    If ($Results.PSDate.Date -Contains $Day.Date){
        $Results | Where {$Results.PSDate.Date -match $Day.Date}
    }
    $Progress2 ++
    <#Else{
    If ($RelevantBankHolidays -contains ($Day.Date)){
        $IsBankHoliday = "True"
    }Else{$IsBankHoliday = "False"}
        [PSCustomObject]@{
            Zone = $null
            Date = ($Day | Get-Date -Format dd/MM/yyyy)
            #PSDate = $Day 
            Notes = $null
            DayOfWeek = $Day.DayOfWeek
            BankHoliday = $IsBankHoliday
            Counter = $null
            VisibleFrom = $null
            CountryCode = $null
            ZoneSelectNote = $null
            SessionConfirmationNote = $null
            StartTime = $null
            EndTime = $null
            StartDate = $null
            EndDate = $null
            OperatorID = $null
            TariffId = $null
            RowGUID = $EventDay.rowguid
        }
    }#>
}


##########################################################################################################################

### Venue IDs
# Emirates Stadium = 494
# London Stadium = 598
# Tottenham Hotspur Stadium = 593
# Queen Elizabeth II Stadium = 10660
# Craven Cottage = 535
# The Cherry Red Records Stadium = 12456

### Create headers for request - API Key is found under "Security" on the relevant app at https://rapidapi.com/developer/apps
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("x-rapidapi-key", "7983aeb949mshc6d8640a76cab97p16c530jsnca1c23908812")
$headers.Add("x-rapidapi-host", "api-football-v1.p.rapidapi.com")

### Query to get venues
$Venues = Invoke-RestMethod "https://api-football-v1.p.rapidapi.com/v3/venues?country=England" -Method 'GET' -Headers $headers



### Get current year to use as season, start and end date ranges are to get results for the next month
$CurrentYear = Get-Date -Format yyyy
$LastYear = (Get-Date).addYears(-1) | Get-Date -Format yyyy
$StartDate = Get-Date -Format yyyy-MM-dd
$EndDate = (Get-Date).AddMonths(1) | Get-Date -Format yyyy-MM-dd


### Separate API request for each team
$Englandresponse = Invoke-RestMethod "https://api-football-v1.p.rapidapi.com/v3/fixtures?team=10&from=$($StartDate)&to=$($EndDate)&season=$($CurrentYear)" -Method 'GET' -Headers $headers
if ($EnglandResponse.results -like "0"){
    $Englandresponse = Invoke-RestMethod "https://api-football-v1.p.rapidapi.com/v3/fixtures?team=10&from=$($StartDate)&to=$($EndDate)&season=$($LastYear)" -Method 'GET' -Headers $headers
}
$EnglandWomensresponse = Invoke-RestMethod "https://api-football-v1.p.rapidapi.com/v3/fixtures?team=1721&from=$($StartDate)&to=$($EndDate)&season=$($CurrentYear)" -Method 'GET' -Headers $headers
if ($EnglandWomensresponse.results -like "0"){
    $EnglandWomensresponse = Invoke-RestMethod "https://api-football-v1.p.rapidapi.com/v3/fixtures?team=1721&from=$($StartDate)&to=$($EndDate)&season=$($LastYear)" -Method 'GET' -Headers $headers
}


$Fulhamresponse = Invoke-RestMethod "https://api-football-v1.p.rapidapi.com/v3/fixtures?team=36&from=$($StartDate)&to=$($EndDate)&season=$($CurrentYear)" -Method 'GET' -Headers $headers
if ($FulhamResponse.results -like "0"){
    $Fulhamresponse = Invoke-RestMethod "https://api-football-v1.p.rapidapi.com/v3/fixtures?team=36&from=$($StartDate)&to=$($EndDate)&season=$($LastYear)" -Method 'GET' -Headers $headers
}
$FulhamWomensresponse = Invoke-RestMethod "https://api-football-v1.p.rapidapi.com/v3/fixtures?team=18236&from=$($StartDate)&to=$($EndDate)&season=$($CurrentYear)" -Method 'GET' -Headers $headers
if ($FulhamWomensresponse.results -like "0"){
    $FulhamWomensresponse = Invoke-RestMethod "https://api-football-v1.p.rapidapi.com/v3/fixtures?team=18236&from=$($StartDate)&to=$($EndDate)&season=$($LastYear)" -Method 'GET' -Headers $headers
}


$ArsenalResponse = Invoke-RestMethod "https://api-football-v1.p.rapidapi.com/v3/fixtures?team=42&from=$($StartDate)&to=$($EndDate)&season=$($CurrentYear)" -Method 'GET' -Headers $headers
if ($ArsenalResponse.results -like "0"){
    $ArsenalResponse = Invoke-RestMethod "https://api-football-v1.p.rapidapi.com/v3/fixtures?team=42&from=$($StartDate)&to=$($EndDate)&season=$($LastYear)" -Method 'GET' -Headers $headers
}
$ArsenalWomensResponse = Invoke-RestMethod "https://api-football-v1.p.rapidapi.com/v3/fixtures?team=1850&from=$($StartDate)&to=$($EndDate)&season=$($CurrentYear)" -Method 'GET' -Headers $headers
if ($ArsenalWomensResponse.results -like "0"){
    $ArsenalWomensResponse = Invoke-RestMethod "https://api-football-v1.p.rapidapi.com/v3/fixtures?team=1850&from=$($StartDate)&to=$($EndDate)&season=$($LastYear)" -Method 'GET' -Headers $headers
}


$TottenhamResponse = Invoke-RestMethod "https://api-football-v1.p.rapidapi.com/v3/fixtures?team=47&from=$($StartDate)&to=$($EndDate)&season=$($CurrentYear)" -Method 'GET' -Headers $headers
if ($TottenhamResponse.results -like "0"){
    $TottenhamResponse = Invoke-RestMethod "https://api-football-v1.p.rapidapi.com/v3/fixtures?team=47&from=$($StartDate)&to=$($EndDate)&season=$($LastYear)" -Method 'GET' -Headers $headers
}
$TottenhamWomensResponse = Invoke-RestMethod "https://api-football-v1.p.rapidapi.com/v3/fixtures?team=4899&from=$($StartDate)&to=$($EndDate)&season=$($CurrentYear)" -Method 'GET' -Headers $headers
if ($TottenhamWomensResponse.results -like "0"){
    $TottenhamWomensResponse = Invoke-RestMethod "https://api-football-v1.p.rapidapi.com/v3/fixtures?team=4899&from=$($StartDate)&to=$($EndDate)&season=$($LastYear)" -Method 'GET' -Headers $headers
}


$WestHamResponse = Invoke-RestMethod "https://api-football-v1.p.rapidapi.com/v3/fixtures?team=48&from=$($StartDate)&to=$($EndDate)&season=$($CurrentYear)" -Method 'GET' -Headers $headers
if ($WestHamResponse.results -like "0"){
    $WestHamResponse = Invoke-RestMethod "https://api-football-v1.p.rapidapi.com/v3/fixtures?team=48&from=$($StartDate)&to=$($EndDate)&season=$($LastYear)" -Method 'GET' -Headers $headers
}
$WestHamWomensResponse = Invoke-RestMethod "https://api-football-v1.p.rapidapi.com/v3/fixtures?team=1856&from=$($StartDate)&to=$($EndDate)&season=$($CurrentYear)" -Method 'GET' -Headers $headers
if ($WestHamWomensResponse.results -like "0"){
    $WestHamWomensResponse = Invoke-RestMethod "https://api-football-v1.p.rapidapi.com/v3/fixtures?team=1856&from=$($StartDate)&to=$($EndDate)&season=$($LastYear)" -Method 'GET' -Headers $headers
}


$AFCWimbledonResponse = Invoke-RestMethod "https://api-football-v1.p.rapidapi.com/v3/fixtures?team=1333&from=$($StartDate)&to=$($EndDate)&season=$($CurrentYear)" -Method 'GET' -Headers $headers
if ($AFCWimbledonResponse.results -like "0"){
    $AFCWimbledonResponse = Invoke-RestMethod "https://api-football-v1.p.rapidapi.com/v3/fixtures?team=1333&from=$($StartDate)&to=$($EndDate)&season=$($LastYear)" -Method 'GET' -Headers $headers
}
$AFCWimbledonWomensResponse = Invoke-RestMethod "https://api-football-v1.p.rapidapi.com/v3/fixtures?team=15435&from=$($StartDate)&to=$($EndDate)&season=$($CurrentYear)" -Method 'GET' -Headers $headers
if ($AFCWimbledonWomensResponse.results -like "0"){
    $AFCWimbledonWomensResponse = Invoke-RestMethod "https://api-football-v1.p.rapidapi.com/v3/fixtures?team=15435&from=$($StartDate)&to=$($EndDate)&season=$($LastYear)" -Method 'GET' -Headers $headers
}

### Filter each team's results to only home games and then add them all to array
$RawFixtures = @()
$RawFixtures += $EnglandResponse.response | Where {$_.teams.home.id -match "10"}
$RawFixtures += $EnglandWomensResponse.response | Where {$_.teams.home.id -match "1721"}

$RawFixtures += $FulhamResponse.response | Where {$_.teams.home.id -match "36"}
$RawFixtures += $FulhamWomensResponse.response | Where {$_.teams.home.id -match "18236"}

$RawFixtures += $ArsenalResponse.response | Where {$_.teams.home.id -match "42"}
$RawFixtures += $ArsenalWomensResponse.response | Where {$_.teams.home.id -match "1850"}

$RawFixtures += $TottenhamResponse.response | Where {$_.teams.home.id -match "47"}
$RawFixtures += $TottenhamWomensResponse.response | Where {$_.teams.home.id -match "4899"}

$RawFixtures += $WestHamResponse.response | Where {$_.teams.home.id -match "48"}
$RawFixtures += $WestHamWomensResponse.response | Where {$_.teams.home.id -match "1856"}

$RawFixtures += $AFCWimbledonResponse.response | Where {$_.teams.home.id -match "1333"}
$RawFixtures += $AFCWimbledonWomensResponse.response | Where {$_.teams.home.id -match "15435"}


# Pull relevant data from fixtures to present to user
$Fixtures = Foreach ($RawFixture in $RawFixtures){
    [PSCustomObject]@{
        "Home Team" = $RawFixture.teams.home.name
        "Away Team" = $RawFixture.teams.away.name
        League = $RawFixture.league.Name
        Date = $RawFixture.Fixture.date | Get-Date
        PSDate = $RawFixture.Fixture.date | Get-Date -Format yyyy-MM-dd
        Venue = $RawFixture.Fixture.venue.name
        VenueID = $RawFixture.Fixture.venue.id
        City = $RawFixture.fixture.venue.city
        Status = $RawFixture.fixture.status.long
    }
}

### Filter fixtures byAsk the user to choose the relevant fixture(s)
$FixturesChoices = $Fixtures | Where {($_.VenueID -like "494") -OR ($_.VenueID -like "593") -OR ($_.VenueID -like "10660") -OR ($_.VenueID -like "535") -OR ($_.VenueID -like "12456") -OR ($_.VenueID -like "")} | Out-Gridview -PassThru -Title "Choose fixture(s) to check:"

### Create list of relevant zone numbers
$ZoneNumbers = $DesiredZoneRules."Zone num" | Get-Unique

### Create array of weekday days to check against later
$Weekdays = @("Monday","Tuesday","Wednesday","Thursday","Friday")

### Loop through each fixture chosen by the user and build the final report
$Log = @()
$Report = @()
Foreach ($FixturesChoice in $FixturesChoices){
    
    ### Filter the event days previously gathered to only those that match the date of the current fixture
    $FilteredEventDays = $FinalResults | Where {$_.Date -match $FixturesChoice.PSdate}

    ### Check to see if there are no event days configured whatsoever - if so, output to pipeline and log
    If (!$FilteredEventDays){
        Write-Host "No event days entries for $($FixturesChoice.'Home Team') v $($FixturesChoice.'Away Team') $($FixturesChoice.Date)"
        $Log += "No event days entries for $($FixturesChoice.'Home Team') v $($FixturesChoice.'Away Team') $($FixturesChoice.Date)"
        Continue
    }Else{
        ### Check the matching event days' zone numbers against the zone numbers list to catch any that are missing event day config completely - output to log any that are missing
        $MissingZones = $ZoneNumbers | Where {$_ -notin $FilteredEventDays.Zone}
        
        If ($MissingZones){
            $Log += "($FixturesChoice.'Home Team') v $($FixturesChoice.'Away Team') $($FixturesChoice.Date) configuration missing for the following zones:"
            Foreach ($MissingZone in $MissingZones){
                $Log += $MissingZone
            }
        }

        ### Loop through the event days that do exist for the chosen fixture's date
        $Progress3 = 0
        Foreach ($FilteredEventDay in $FilteredEventDays){
            Write-Progress -Activity "Verifying configured event days"  -PercentComplete ($Progress3/$FilteredEventDays.count*100)
            
            ### Check for duplicate Eventday entry in DB
            If ($PreviousEventDay.Zone -match $FilteredEventDay.Zone){
                    $DuplicateEventDay = "Yes"
                }Else{
                    If ($DuplicateEventDay){
                        Clear-Variable DuplicateEventDay
                    }
                }
            
            ### Filter the desired zone rules for the one matching the zone of the event day
            $FilteredDesiredZoneRules = $DesiredZoneRules | Where {$_."Zone num" -like $FilteredEventDay.Zone}
            
            Foreach($FilteredDesiredZoneRule in $FilteredDesiredZoneRules){
                ### Check which zone rules to comply with and then create variables containing the start and end times for comparison
                ### First, check to see if the date in question is a bank holiday
                If ($FilteredEventDay.BankHoliday -like "True"){
                    $DesiredStart = $FilteredDesiredZoneRule.'Sunday & Bank Hols'.Start
                    $ConfiguredStart = $FilteredEventDay.StartTime
                    $DesiredEnd = $FilteredDesiredZoneRule.'Sunday & Bank Hols'.End     
                    $ConfiguredEnd = $FilteredEventDay.EndTime
                }
                ### If the date in question is not a bank holiday, it can be dealt with as a normal weekday, saturday or sunday.
                ElseIf ($FilteredEventDay.DayOfWeek -in $Weekdays){
                    $DesiredStart = $FilteredDesiredZoneRule.Weekdays.Start
                    $ConfiguredStart = $FilteredEventDay.StartTime
                    $DesiredEnd = $FilteredDesiredZoneRule.Weekdays.End     
                    $ConfiguredEnd = $FilteredEventDay.EndTime
                }
                ElseIf ($FilteredEventDay.DayOfWeek -match "Saturday"){
                    $DesiredStart = $FilteredDesiredZoneRule.Saturdays.Start
                    $ConfiguredStart = $FilteredEventDay.StartTime
                    $DesiredEnd = $FilteredDesiredZoneRule.Saturdays.End     
                    $ConfiguredEnd = $FilteredEventDay.EndTime
                }
                ElseIf ($FilteredEventDay.DayOfWeek -match "Sunday"){
                    $DesiredStart = $FilteredDesiredZoneRule.'Sunday & Bank Hols'.Start
                    $ConfiguredStart = $FilteredEventDay.StartTime
                    $DesiredEnd = $FilteredDesiredZoneRule.'Sunday & Bank Hols'.End     
                    $ConfiguredEnd = $FilteredEventDay.EndTime
                }         

                ### Check to see if the desired start and end times match the configured start and end times
                If ($DesiredStart -like $ConfiguredStart){
                    $StartMatch = "Yes"
                }Else{
                    $StartMatch = "No"
                }

                If ($DesiredEnd -like $ConfiguredEnd){
                    $EndMatch = "Yes"
                } Else{
                    $EndMatch = "No"
                }

                ### Build the final report
                $Report += [PSCustomObject]@{
                    Zone = $FilteredEventDay.Zone
                    "Intended Tariff ID" = $FilteredDesiredZoneRule.'Tarrif ID'
                    Date = $FilteredEventDay.Date
                    "Desired Start" = $DesiredStart
                    "Configured Start" = $ConfiguredStart
                    "Start Time Match" = $StartMatch
                    "Desired End" = $DesiredEnd
                    "Configured End" = $ConfiguredEnd
                    "End Time Match" = $EndMatch
                    RowGUID = $FIlteredEventDay.RowGUID
                    "Duplicate Eventday Entry" = $DuplicateEventDay
                }
            } 
            $PreviousEventDay = $FilteredEventDay
            $Progress3 ++ 
        }
    }
}


### Get today's date and time to use for the unique filename
$Date = Get-Date -Format ddMMyy-hhmm

### Create output path
    if ($PSScriptRoot){
    ### Filepath for running as script - same directory as script
        $LogFilepath = $PSScriptRoot + "\EventDaysLog-" + $Date + ".txt"
        $ReportFilepath = $PSScriptRoot + "\EventDaysReport-" + $Date + ".csv"
    }else{
    ### Filepath for testing from ISE:
        $LogFilepath = "C:\Users\dudley.andrews\Desktop" + "\EventDaysLog-" + $Date + ".txt"
        $ReportFilepath = "C:\Users\dudley.andrews\Desktop" + "\EventDaysReport-" + $Date + ".csv"
    }
### Output log file and report
$Log | Out-File $LogFilepath
$Report | Export-Csv -Path $ReportFilepath -NoTypeInformation

### Report to the user where they can find the results and then prompt for exit
Write-Host "Log generated at $LogFilePath"
Write-Host "Report generated at $ReportFilePath"
Read-Host -Prompt "Press Enter to exit"