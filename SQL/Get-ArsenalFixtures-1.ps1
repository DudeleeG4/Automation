function ConvertFrom-HTMLTable {
    <#
    .SYNOPSIS
    Function for converting ComObject HTML object to common PowerShell object.
    .DESCRIPTION
    Function for converting ComObject HTML object to common PowerShell object.
    ComObject can be retrieved by (Invoke-WebRequest).parsedHtml or IHTMLDocument2_write methods.
    In case table is missing column names and number of columns is:
    - 2
        - Value in the first column will be used as object property 'Name'. Value in the second column will be therefore 'Value' of such property.
    - more than 2
        - Column names will be numbers starting from 1.
    .PARAMETER table
    ComObject representing HTML table.
    .PARAMETER tableName
    (optional) Name of the table.
    Will be added as TableName property to new PowerShell object.
    .EXAMPLE
    $pageContent = Invoke-WebRequest -Method GET -Headers $Headers -Uri "https://docs.microsoft.com/en-us/mem/configmgr/core/plan-design/hierarchy/log-files"
    $table = $pageContent.ParsedHtml.getElementsByTagName('table')[0]
    $tableContent = @(ConvertFrom-HTMLTable $table)
    Will receive web page content >> filter out first table on that page >> convert it to PSObject
    .EXAMPLE
    $Source = Get-Content "C:\Users\Public\Documents\MDMDiagnostics\MDMDiagReport.html" -Raw
    $HTML = New-Object -Com "HTMLFile"
    $HTML.IHTMLDocument2_write($Source)
    $HTML.body.getElementsByTagName('table') | % {
        ConvertFrom-HTMLTable $_
    }
    Will get web page content from stored html file >> filter out all html tables from that page >> convert them to PSObjects
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.__ComObject] $table,

        [string] $tableName
    )

    $twoColumnsWithoutName = 0

    if ($tableName) { $tableNameTxt = "'$tableName'" }

    $columnName = $table.getElementsByTagName("th") | % { $_.innerText -replace "^\s*|\s*$" }

    if (!$columnName) {
        $numberOfColumns = @($table.getElementsByTagName("tr")[0].getElementsByTagName("td")).count
        if ($numberOfColumns -eq 2) {
            ++$twoColumnsWithoutName
            Write-Verbose "Table $tableNameTxt has two columns without column names. Resultant object will use first column as objects property 'Name' and second as 'Value'"
        } elseif ($numberOfColumns) {
            Write-Warning "Table $tableNameTxt doesn't contain column names, numbers will be used instead"
            $columnName = 1..$numberOfColumns
        } else {
            throw "Table $tableNameTxt doesn't contain column names and summarization of columns failed"
        }
    }

    if ($twoColumnsWithoutName) {
        # table has two columns without names
        $property = [ordered]@{ }

        $table.getElementsByTagName("tr") | % {
            # read table per row and return object
            $columnValue = $_.getElementsByTagName("td") | % { $_.innerText -replace "^\s*|\s*$" }
            if ($columnValue) {
                # use first column value as object property 'Name' and second as a 'Value'
                $property.($columnValue[0]) = $columnValue[1]
            } else {
                # row doesn't contain <td>
            }
        }
        if ($tableName) {
            $property.TableName = $tableName
        }

        New-Object -TypeName PSObject -Property $property
    } else {
        # table doesn't have two columns or they are named
        $table.getElementsByTagName("tr") | % {
            # read table per row and return object
            $columnValue = $_.getElementsByTagName("td") | % { $_.innerText -replace "^\s*|\s*$" }
            if ($columnValue) {
                $property = [ordered]@{ }
                $i = 0
                $columnName | % {
                    $property.$_ = $columnValue[$i]
                    ++$i
                }
                if ($tableName) {
                    $property.TableName = $tableName
                }

                New-Object -TypeName PSObject -Property $property
            } else {
                # row doesn't contain <td>, its probably row with column names
            }
        }
    }
}

$Months = @()
$Months += [PSCustomObject]@{
        Month = "Jan"
        No = 01
        }
$Months += [PSCustomObject]@{
        Month = "Feb"
        No = 02
        }
$Months += [PSCustomObject]@{
        Month = "Mar"
        No = 03
        }
$Months += [PSCustomObject]@{
        Month = "Apr"
        No = 04
        }
$Months += [PSCustomObject]@{
        Month = "May"
        No = 05
        }
$Months += [PSCustomObject]@{
        Month = "Jun"
        No = 06
        }
$Months += [PSCustomObject]@{
        Month = "Jul"
        No = 07
        }
$Months += [PSCustomObject]@{
        Month = "Aug"
        No = 08
        }
$Months += [PSCustomObject]@{
        Month = "Sep"
        No = 09
        }
$Months += [PSCustomObject]@{
        Month = "Oct"
        No = 10
        }
$Months += [PSCustomObject]@{
        Month = "Nov"
        No = 11
        }
$Months += [PSCustomObject]@{
        Month = "Dec"
        No = 12
        }




$RawResults = Invoke-Webrequest "https://www.arsenal.com/results-and-fixtures-list?"

$Alltables = $RawResults.ParsedHtml.getElementsByTagName('table')

$Fixtures = $Alltables |%{ConvertFrom-HTMLTable $_}




$FormattedFixtures = Foreach ($Fixture in $Fixtures){

    $RawDateInfo = $Fixture.1 -Split " " | Select -First 3

    $Month = $Months | Where {$_.Month -Match "Jul"}

    

    $Time = $Fixture.1 -split " - " | Select -Index 1

    [PSCustomObject]@{
        Date = $Fixture.1
        Team1 = $Fixture.2
        Score = $Fixture.3
        Team2 = $Fixture.4
        MatchType = $Fixture.5
    }
}