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

### Prompt user to enter the VRN
$VRN = Read-Host -Prompt "Enter VRN:"


### Search the RingGo_VRN_Lookup table on both sites for the specified VRN
$InitialQuery = "/****** Script for SelectTopNRows command from SSMS  ******/
SELECT TOP (1000) [VRN]
      ,[Colour]
      ,[Make]
      ,[CreatedDateTime]
      ,[TimeSec]
      ,[Model]
      ,[CO2]
      ,[EngineCC]
      ,[Fuel]
      ,[status]
      ,[keeper]
      ,[ukparse]
      ,[yearOfManufacture]
      ,[DateRegistered]
      ,[VehicleType]
      ,[KeeperName]
      ,[KeeperAddress1]
      ,[KeeperAddress2]
      ,[KeeperAddress3]
      ,[KeeperPostcode]
      ,[KeeperLastUpdated]
      ,[KeeperEventDate]
      ,[LastUpdated]
      ,[CountryCode]
      ,[DataSource]
      ,[EuroStatus]
  FROM [RingGo].[dbo].[RingGo_VRN_Lookup] WITH (nolock)
  WHERE VRN = '" + $VRN + "'"

$UxbQueryResults = Invoke-Sqlcmd -ServerInstance $UxbInstance -Database "Ringgo" -Query $InitialQuery -Credential $UxbCreds
$LonQueryResults = Invoke-Sqlcmd -ServerInstance $LonInstance -Database "Ringgo" -Query $InitialQuery -Credential $LonCreds

### Insert blank row at the top of the results to overcome the flaw with Out-Gridview where the initial row is highlighted but not selected by default
$BlankRow = [PSCustomObject]@{
    VRN = ""
    Colour = ""
    Make = ""
    CreatedDateTime = ""
    TimeSec = ""
    Model = ""
    CO2 = ""
    EngineCC = ""
    Fuel = ""
    status = ""
    keeper = ""
    ukparse = ""
    yearOfManufacture = ""
    DateRegistered = ""
    VehicleType = ""
    KeeperName = ""
    KeeperAddress1 = ""
    KeeperAddress2 = ""
    KeeperAddress3 = ""
    KeeperPostcode = ""
    KeeperLastUpdated = ""
    KeeperEventDate = ""
    LastUpdated = ""
    CountryCode = ""
    DataSource = ""
    EuroStatus = ""
}

$QueryResultsCombined = @()
$QueryResultsCombined += $BlankRow | ConvertTo-DataTable
$QueryResultsCombined += $UxbQueryResults
$QueryResultsCombined += $LonQueryResults

$ChosenEntry = $QueryResultsCombined | Out-GridView -Title "Please select the correct entry:" -PassThru

### Basic exception handling
If ($ChosenEntry.VRN -like ""){
    Write-Host "No entry selected"
    Continue
}ElseIf($ChosenEntry.count){
    Write-Host "Multiple entries selected"
    Continue
}
$Report = @()

    ### Create update query - has to be fully left aligned for formatting reasons
$UpdateQuery = @"
UPDATE RingGo_VRN_Lookup
SET VRN = '$($ChosenEntry.VRN)', Colour = '$($ChosenEntry.Colour)', Make = '$($ChosenEntry.Make)', CreatedDateTime = '$($ChosenEntry.CreatedDateTime)', TimeSec = '$($ChosenEntry.TimeSec)', Model = '$($ChosenEntry.Model)', CO2 = '$($ChosenEntry.CO2)', EngineCC = '$($ChosenEntry.EngineCC)', Fuel = '$($ChosenEntry.Fuel)', status = '$($ChosenEntry.status)', keeper = '$($ChosenEntry.keeper)', ukparse = '$($ChosenEntry.ukparse)', yearOfManufacture = '$($ChosenEntry.yearOfManufacture)', DateRegistered = '$($ChosenEntry.DateRegistered)', VehicleType = '$($ChosenEntry.VehicleType)', KeeperName = '$($ChosenEntry.KeeperName)', KeeperAddress1 = '$($ChosenEntry.KeeperAddress1)', KeeperAddress2 = '$($ChosenEntry.KeeperAddress2)', KeeperAddress3 = '$($ChosenEntry.KeeperAddress3)', KeeperPostcode = '$($ChosenEntry.KeeperPostcode)', KeeperLastUpdated = '$($ChosenEntry.KeeperLastUpdate)', KeeperEventDate = '$($ChosenEntry.KeeperEventDate)', LastUpdated = '$($ChosenEntry.LastUpdated)', CountryCode = '$($ChosenEntry.CountryCode)', DataSource = '$($ChosenEntry.DataSource)', EuroStatus = '$($ChosenEntry.EuroStatus)'
WHERE VRN = '$VRN'
"@

### Make the edits to the DB
Invoke-sqlcmd -ServerInstance $UxbInstance -Database "Ringgo" -Query $UpdateQuery -Credential $UxbCreds
Invoke-Sqlcmd -ServerInstance $LonInstance -Database "Ringgo" -Query $UpdateQuery -Credential $LonCreds

### Write update query to log
$Report += $UpdateQuery

$Date = Get-Date -Format ddMMyy-hhmm
 ### Create output path
    if ($PSScriptRoot){
    ### Filepath for running as script - same directory as script
        $Filepath = $PSScriptRoot + "\FixedVRNLookupEntry" + $Date + ".txt"
    }else{
    ### Filepath for testing from ISE:
        $Filepath = "C:\Users\dudley.andrews\Desktop" + "\FixedVRNLookupEntry-" + $Date + ".txt"
    }
$Report | Out-File $Filepath

Write-Host "Log generated at: $Filepath"
Read-Host -Prompt "Press enter to exit"