# Import the ImportExcel module
Import-Module ImportExcel

# Define the path to the Excel file
$excelFile = "C:\Users\dudley.andrews\Desktop\Message delivery January 2023 - Copy.xlsx"

$excel = New-Object -ComObject Excel.Application

# open the workbook
$workbook = $excel.Workbooks.Open($excelFile)

# Create a new worksheet in the workbook
$newSheet = $workbook.Worksheets.Add()
$newSheet.Name = "PivotTable"
$newSheet.Activate()

# Create a pivot table
$pivotData = $excelData |
    Group-Object -Property "Date" |
    Select-Object @{n="Date";e={$_.Name}}, 
        @{n="Delivered Segments";e={($_.Group | Measure-Object -Property "Delivered Segments" -Sum).Sum}},
        @{n="Refused Segments";e={($_.Group | Measure-Object -Property "Refused Segments" -Sum).Sum}},
        @{n="Rejected Segments";e={($_.Group | Measure-Object -Property "Rejected Segments" -Sum).Sum}},
        @{n="Unreachable Recipient Segments";e={($_.Group | Measure-Object -Property "Unreachable Recipient Segments" -Sum).Sum}},
        @{n="No Response From Operator Segments";e={($_.Group | Measure-Object -Property "No Response From Operator Segments" -Sum).Sum}},
        @{n="Not Delivered Validity Segments + SMSC Unable To Send Segments";e={$_.Group.'Not Delivered Validity Segments'.Sum + $_.Group.'SMSC Unable To Send Segments'.Sum}}

# Write pivot data to worksheet
$pivotData | Export-Excel -Worksheet $newSheet

# Format the pivot table
$range = $newSheet.UsedRange
$pivotTable = $newSheet.PivotTables.Add($range, "PivotTable")
$pivotTable.PivotFields("Date").Orientation = 1
$pivotTable.PivotFields("Date").Position = 1
$pivotTable.AddDataField($pivotTable.PivotFields("Delivered Segments"), "Sum of Delivered Segments", 1)
$pivotTable.AddDataField($pivotTable.PivotFields("Refused Segments"), "Sum of Refused Segments", 2)
$pivotTable.AddDataField($pivotTable.PivotFields("Rejected Segments"), "Sum of Rejected Segments", 3)
$pivotTable.AddDataField($pivotTable.PivotFields("Unreachable Recipient Segments"), "Sum of Unreachable Recipient Segments", 4)
$pivotTable.AddDataField($pivotTable.PivotFields("No Response From Operator Segments"), "Sum of No Response From Operator Segments", 5)
$pivotTable.AddDataField($pivotTable.PivotFields("Not Delivered Validity Segments + SMSC Unable To Send Segments"), "Sum of Not Delivered Validity Segments + SMSC Unable To Send Segments", 6)

# Reorder the pivot table values
$pivotTable.PivotFields("Not Delivered Validity Segments + SMSC Unable To Send Segments").Position = 2
