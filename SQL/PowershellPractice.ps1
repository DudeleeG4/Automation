function Get-MonthNumber {
    Param([Parameter(Mandatory=$true,ValueFromPipeline=$true)][String]$Months
    )
    $MonthsCount = [PSCustomObject] @{
        January = 1
        February = 2
        March = 3
        April = 4 
        May = 5
        June = 6
        July = 7
        August = 8
        September = 9
        October = 10
        November = 11
        December = 12
    }
    Foreach ($Month in $Months){
        $MonthsCount | Select -ExpandProperty ($Month)
    }
}

#################################################################################################

$Date = Get-Date

$MonthName = $Date.DateTime -Split " " | Select -Index 1

$MonthNumber = $MonthName | Get-MonthNumber

$Year = [String]$Date.Year
$Month = [String]$Date.Month
$Day = [String]$Date.Day
$Hour = [String]$Date.Hour
$Minute = [String]$Date.Minute
$Second = [String]$Date.Second
$MilliSecond = ([String](($Date.TimeOfDay.ToString("c")).Split(".") | Select -Index 1)).SubString(0,3)

$SQLDateTime = $Year + "-" + $Month + "-" + $Day + " " + $Hour + ":" + $Minute + ":" + $Second + ":" + $MilliSecond
