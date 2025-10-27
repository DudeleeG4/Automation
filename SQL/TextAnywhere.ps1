$username = "support@ctt.co.uk"
$password = "rf27KADzA#gYGK%z"
$reportType = "All"
$startDate = "2022-03-07"
$endDate = "2022-03-07"
$outputFilePath = "C:\reports\DeliveryStatusReport.csv"

# Build the login request payload
$loginUri = "https://textanywhere.textapp.net/web/Login/LoginMain.aspx"
$loginPayload = @{
    "ctl00\$ContentPlaceHolder1\$Login1\$UserName" = $username
    "ctl00\$ContentPlaceHolder1\$Login1\$Password" = $password
    "ctl00\$ContentPlaceHolder1\$Login1\$LoginButton" = "Log in"
    "__VIEWSTATE" = $session.Content -match '__VIEWSTATE".*?value="(.+?)"'; $Matches[1] | Out-Null
}

# Login to the site
$session = Invoke-WebRequest -Uri $loginUri -Method POST -Body $loginPayload -SessionVariable 'textAnywhereSession'

# Build the report generation request payload
$reportUri = "https://textanywhere.textapp.net/web/AppsAccountAdmin/AccountReporting.aspx"
$reportPayload = @{
    "__EVENTTARGET" = "ctl00\$ContentPlaceHolder1\$btnReport"
    "__EVENTARGUMENT" = ""
    "__VIEWSTATE" = $session.Content -match '__VIEWSTATE".*?value="(.+?)"'; $Matches[1] | Out-Null
    "ctl00\$ContentPlaceHolder1\$ddlReportType" = $reportType
    "ctl00\$ContentPlaceHolder1\$txtStartDate" = $startDate
    "ctl00\$ContentPlaceHolder1\$txtEndDate" = $endDate
    "ctl00\$ContentPlaceHolder1\$chkDetailedReport" = "on"
    "ctl00\$ContentPlaceHolder1\$btnReport" = "Generate report"
}

# Generate the report and save it to a file
Invoke-WebRequest -Uri $reportUri -Method POST -Body $reportPayload -WebSession $session -OutFile $outputFilePath
