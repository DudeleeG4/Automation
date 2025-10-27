### Football team IDs:
# England = 10
# Fulham = 36
# Arsenal = 42
# Tottenham = 47
# West Ham = 48
# AFC Wimbledon = 1333

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
#$Venues = Invoke-RestMethod "https://api-football-v1.p.rapidapi.com/v3/venues?country=England" -Method 'GET' -Headers $headers


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
$Fulhamresponse = Invoke-RestMethod "https://api-football-v1.p.rapidapi.com/v3/fixtures?team=36&from=$($StartDate)&to=$($EndDate)&season=$($CurrentYear)" -Method 'GET' -Headers $headers
if ($FulhamResponse.results -like "0"){
    $Fulhamresponse = Invoke-RestMethod "https://api-football-v1.p.rapidapi.com/v3/fixtures?team=36&from=$($StartDate)&to=$($EndDate)&season=$($LastYear)" -Method 'GET' -Headers $headers
}
$ArsenalResponse = Invoke-RestMethod "https://api-football-v1.p.rapidapi.com/v3/fixtures?team=42&from=$($StartDate)&to=$($EndDate)&season=$($CurrentYear)" -Method 'GET' -Headers $headers
if ($ArsenalResponse.results -like "0"){
    $ArsenalResponse = Invoke-RestMethod "https://api-football-v1.p.rapidapi.com/v3/fixtures?team=42&from=$($StartDate)&to=$($EndDate)&season=$($LastYear)" -Method 'GET' -Headers $headers
}
$TottenhamResponse = Invoke-RestMethod "https://api-football-v1.p.rapidapi.com/v3/fixtures?team=47&from=$($StartDate)&to=$($EndDate)&season=$($CurrentYear)" -Method 'GET' -Headers $headers
if ($TottenhamResponse.results -like "0"){
    $TottenhamResponse = Invoke-RestMethod "https://api-football-v1.p.rapidapi.com/v3/fixtures?team=47&from=$($StartDate)&to=$($EndDate)&season=$($LastYear)" -Method 'GET' -Headers $headers
}
$WestHamResponse = Invoke-RestMethod "https://api-football-v1.p.rapidapi.com/v3/fixtures?team=48&from=$($StartDate)&to=$($EndDate)&season=$($CurrentYear)" -Method 'GET' -Headers $headers
if ($WestHamResponse.results -like "0"){
    $WestHamResponse = Invoke-RestMethod "https://api-football-v1.p.rapidapi.com/v3/fixtures?team=48&from=$($StartDate)&to=$($EndDate)&season=$($LastYear)" -Method 'GET' -Headers $headers
}
$AFCWimbledonResponse = Invoke-RestMethod "https://api-football-v1.p.rapidapi.com/v3/fixtures?team=1333&from=$($StartDate)&to=$($EndDate)&season=$($CurrentYear)" -Method 'GET' -Headers $headers
if ($AFCWimbledonResponse.results -like "0"){
    $AFCWimbledonResponse = Invoke-RestMethod "https://api-football-v1.p.rapidapi.com/v3/fixtures?team=1333&from=$($StartDate)&to=$($EndDate)&season=$($LastYear)" -Method 'GET' -Headers $headers
}

### Filter each team's results to only home games and then add them all to array
$RawFixtures = @()
$RawFixtures += $EnglandResponse.response #| Where {$_.teams.home.id -match "10"}
$RawFixtures += $FulhamResponse.response #| Where {$_.teams.home.id -match "36"}
$RawFixtures += $ArsenalResponse.response #| Where {$_.teams.home.id -match "42"}
$RawFixtures += $TottenhamResponse.response #| Where {$_.teams.home.id -match "47"}
$RawFixtures += $WestHamResponse.response #| Where {$_.teams.home.id -match "48"}
$RawFixtures += $AFCWimbledonResponse.response #| Where {$_.teams.home.id -match "1333"}

$Fixtures = Foreach ($RawFixture in $RawFixtures){
    [PSCustomObject]@{
        "Home Team" = $RawFixture.teams.home.name
        "Away Team" = $RawFixture.teams.away.name
        League = $RawFixture.league.Name
        Date = $RawFixture.Fixture.date | Get-Date
        Venue = $RawFixture.Fixture.venue.name
        City = $RawFixture.fixture.venue.city
        Status = $RawFixture.fixture.status.long
    }
}