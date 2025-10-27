
$Date = Get-Date -Format ddMMyy-hhmm
 ### Create output path
if ($PSScriptRoot){
### Filepath for running as script - same directory as script
    $Filepath = $PSScriptRoot + "\DeleteCLILog-" + $Date + ".txt"
}else{
### Filepath for testing from ISE:
    $Filepath = "C:\Users\dudley.andrews\Desktop" + "\DeleteCLILog-" + $Date + ".txt"
}


### Gather user's credentials for Lon and Uxb DB 6
$UxbCreds = Get-Credential -Message "Enter your Uxb Insight DB creds"
$LonCreds = Get-Credential -Message "Enter your Lon Insight DB creds"

### Get the SQL instances used by the script and store then in variables
$UxbInstance = Get-SQLInstance -ServerInstance 192.168.166.206 -Credential $UxbCreds
if (!$UxbInstance){
    Write-Host "Uxbridge Insight DB creds invalid or connection failure - please re-run the script"
    Read-Host -Prompt "Press enter to exit"
    Exit
}
$LonInstance = Get-SQLInstance -ServerInstance 192.168.178.206 -Credential $LonCreds
if (!$LonInstance){
    Write-Host "London Insight DB creds invalid or connection failure - please re-run the script"
    Read-Host -Prompt "Press enter to exit"
    Exit
}
### Open array variable to write log data in
$Log = @()

$CLI = Read-Host -Prompt "Enter CLI:"

### Create log variable
$Log += "CLI: $($CLI)"

$MembersQuery = "SELECT TOP (1000) *
  FROM [RingGo].[dbo].[RingGo_Members] WITH (nolock)
  Where Member_CLI = '$($CLI)'"

$UxbMembers = Invoke-Sqlcmd -ServerInstance $UxbInstance -Database "Ringgo" -Query $MembersQuery -Credential $UxbCreds
$LonMembers = Invoke-Sqlcmd -ServerInstance $LonInstance -Database "Ringgo" -Query $MembersQuery -Credential $LonCreds
If (($UxbMembers.count) -or ($LonMembers.count)){
    Write-Host "Unable to remove CLI - Please raise with Service Operations"

    $Log += "Multiple entries found for $($CLI) in RingGo_Members - aborting operation"
    $Log += [PSCustomObject]@{
        "UxB RingGo.dbo.RingGo_Members Entries" = $UxbMembers.count
        "Lon RingGo.dbo.RingGo_Members Entries" = $LonMembers.count
    }
    
    ### Create log file
    $Log | Out-File $Filepath
    Write-Host "Log output to $($Filepath)"
    Read-Host -Prompt "Press enter to Exit"
    Exit
}

If ($UxbMembers){$1 = "True"}Else{$1 = "False"}
If ($LonMembers){$2 = "True"}Else{$2 = "False"}
If (($1 -like "True") -or ($2 -like "True")){$MembersPresent = "True"}Else{$MembersPresent = "False"}


$MemberCLIs = "SELECT TOP (1000) *
  FROM [RingGo].[dbo].[MemberCLIs] WITH (nolock)
  WHERE CLI = '$($CLI)'"

$UxbMemberCLIs = Invoke-Sqlcmd -ServerInstance $UxbInstance -Database "Ringgo" -Query $MemberCLIs -Credential $UxbCreds
$LonMemberCLIs = Invoke-Sqlcmd -ServerInstance $LonInstance -Database "Ringgo" -Query $MemberCLIs -Credential $LonCreds
If ($UxbMemberCLIs){$3 = "True"}Else{$3 = "False"}
If ($LonMemberCLIs){$4 = "True"}Else{$4 = "False"}
If (($3 -like "True") -or ($4 -like "True")){$MemberCLIsPresent = "True"}Else{$MemberCLIsPresent = "False"}


If ($MembersPresent = "True"){
    Write-Host "Unable to remove CLI - Please raise with Service Operations"
    $Log += "Entry present in at least one RinGo_Members table - aborting operation"
    $Log += [PSCustomObject]@{
        "Uxb RingGo.dbo.RingGo_Members" = $1
        "Lon RingGo.dbo.RingGo_Members" = $2
        "Uxb RingGo.dbo.MemberCLIs" = $3
        "Lon RingGo.dbo.MemberCLIs" = $4
    }
}
ElseIf ($MembersPresent = "False"){
    If ($MemberCLIsPresent = "True"){
        Write-Host "Found entry in [Ringgo].[dbo].[MemberCLIs] - Deleting"

### Delete query - must be left aligned to work
$DeleteMemberCLIs = @"
DELETE from MemberCLIs
WHERE (CLI = '$($CLI)')
"@
    ### Write delete statement to log
    $Log += $DeleteMemberCLIs

    ### Delete entries
    #Invoke-Sqlcmd -ServerInstance $UxbInstance -Database "RingGo" -Query $DeleteMemberCLIs -Credential $UxbCreds
    #Invoke-Sqlcmd -ServerInstance $LonInstance -Database "RingGo" -Query $DeleteMemberCLIs -Credential $LonCreds
    }
}

### Create log file
$Log | Out-File $Filepath
Write-Host "Log output to $($Filepath)"
Read-Host -Prompt "Press enter to Exit"