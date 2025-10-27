#Open ISE as an admin and install module if you dont have
# Install-Module -Name ImportExcel

# Import the module
Import-Module ImportExcel

# Define the path to the Excel file
$excelFile = "C:\Users\dudley.andrews\Desktop\Message delivery January 2023 - Copy.xlsx"

$excelFileoutput = "C:\Users\dudley.andrews\Desktop\PivotTable.xlsx"

# Load the data into a variable
$data = Import-Excel $excelFile

$customdata = foreach ($row in $data){
    [PSCustomObject]@{
        "Api Space Id" = $row."Api Space Id"
        "Api Space Name" = $row."Api Space Name"
        "Date" = $row.Date
        "Total Segments" = $row."Total Segments"
        "Delivered Segments" = $row."Delivered Segments"
        "Rejected Segments" = $row."Rejected Segments"
        "Not Delivered Validity Segments" = $row."Not Delivered Validity Segments"
        "Unreachable Recipient Segments" = $row."Unreachable Recipient Segments"
        "Handset Full Segments" = $row."Handset Full Segments"
        "S M S C Unable To Send Segments" = $row."S M S C Unable To Send Segments"
        "User No Credit Segments" = $row."User No Credit Segments"
        "No Response From Operator Segments" = $row."No Response From Operator Segments"
        "Deleted Segments" = $row."Deleted Segments"
        "Refused Segments" = $row."Refused Segments"
        "Filtered Segments" = $row."Filtered Segments"
        "Field 1" = [int]$row."Not Delivered Validity Segments" + [int]$row."S M S C Unable To Send Segments"
    }
}

$PivotData = [ordered]@{
    "Delivered Segments" = "Sum"
    "Field 1" = "Sum"
    "Refused Segments" = "Sum"
    "Rejected Segments" = "Sum"
    "Unreachable Recipient Segments" = "Sum"
    "No Response From Operator Segments" = "Sum"
}

$Test = $customdata | Export-Excel -Path $excelFileOutput -WorksheetName 'PivotTable' -PivotRows Date -PivotData $PivotData -Show


