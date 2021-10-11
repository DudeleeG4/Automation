Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

$Creds = Get-Credential -Message "Username and password from dbs00003/LANDesk_readonly in SINT"
$usern = $Creds.Username
$passw = $Creds.GetNetworkCredential().Password

$TicketListArray = Get-Content "C:\Scripts\Technology\CSE\LANDesk\Closure Notes\ticketlist.csv"

Function LDQuery-ClosureNotes-ToFile($TicketNumber)
{
    $QueryString = "
SELECT TOP 1 [usr_privatenote].[usr_privatenotedetail]
FROM [ServiceDesk].[dbo].[im_incident], [ServiceDesk].[dbo].[usr_privatenote]
WHERE [im_incident].[im_id] = "+$TicketNumber+"
AND [im_incident].[pm_guid] = [usr_privatenote].[usr_incident]
ORDER BY usr_datetime desc
"
	#$QueryString
	$FilePath = "C:\Scripts\Technology\CSE\LANDesk\Closure Notes\results\INC"+$TicketNumber+".csv"
    Get-LDQuery -Query $QueryString | Export-Csv -Path $FilePath -Force -NoTypeInformation
	#$FilePath
}

Function Get-LDQuery($Query)
{  
    $Connection = new-object system.Data.SqlClient.SqlConnection(
    "Server=dbs00003i2.il2management.local;
    Database=ServiceDesk;
    User Id=$usern;
    Password=$passw;
    ")

	$DA = New-Object system.Data.SqlClient.SqlDataAdapter($Query,$Connection)
	$DS = New-Object system.Data.DataTable

	$Connection.Open() | Out-Null
	$DA.Fill($DS) | Out-Null
	$Connection.Close() | Out-Null
	$DA.Dispose() | Out-Null
	$Connection.Dispose() | Out-Null

	Return $DS
}

Foreach ($TicketNumber in $TicketListArray.split(","))
{
	LDQuery-ClosureNotes-ToFile -TicketNumber $TicketNumber
}

Read-Host -Prompt "Press Enter to exit"
