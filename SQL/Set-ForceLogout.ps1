### https://confluence.parkmobile.com/pages/viewpage.action?spaceKey=UKOPS&title=Forcing+a+user+to+log+out+of+Apps

$Log = @()

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


$UserID = Read-Host -Prompt "Enter the User ID:"

$CustomQuery = "SELECT TOP (200)
RefreshToken
,rt.AccessToken
,rt.ExpireTime
,s.OwnerId
FROM SSORefreshTokens rt with (nolock)
LEFT JOIN SSOAccessTokens at on rt.AccessToken = at.AccessToken
LEFT JOIN SSOSessions s on s.ID = at.SessionID
WHERE s.OwnerId = " + "'$($UserID)'"


$CustomQueryResults = Invoke-Sqlcmd -ServerInstance $UxbInstance -Database "RingGo_Access" -Query $CustomQuery -Credential $UxbCreds

### Find the entries to be deleted from the SSORefreshTokens table

Foreach ($Result in $CustomQueryResults){ 
    $DeleteRefreshTokenQuery = @"
DELETE from SSORefreshTokens
WHERE (RefreshToken = '$($Result.RefreshToken)')
"@
    ### Write delete statement to log
    $Log += $DeleteRefreshTokenQuery

    ### Delete entries
    Invoke-Sqlcmd -ServerInstance $UxbInstance -Database "RingGo_Access" -Query $DeleteRefreshTokenQuery -Credential $UxbCreds
}


### Find the SSOAccessToken for the UserID
$AccessTokenQuery = "
SELECT TOP (200)
AccessToken
,SessionID
,ExpireTime
,s.OwnerId
FROM SSOAccessTokens at with (nolock)
LEFT JOIN SSOSessions s on s.ID = at.SessionID
WHERE s.OwnerType = 'user' AND s.OwnerId = '$($UserID)'"


$AccessTokens = Invoke-Sqlcmd -ServerInstance $UxbInstance -Database "RingGo_Access" -Query $AccessTokenQuery -Credential $UxbCreds

Foreach ($AccessToken in $AccessTokens){
    $UpdateAccessTokenBody = @"
UPDATE SSOAccessTokens
SET ExpireTime = '0'
WHERE (AccessToken = '$($AccessToken.AccessToken)')
"@
    ### Write update statement to log
    $Log += $UpdateAccessTokenBody
    
    ### Update entries
    Invoke-sqlcmd -ServerInstance $UxbInstance -Database "RingGo_Access" -Query $UpdateAccessTokenBody -Credential $UxbCreds
}

$Date = Get-Date -Format ddMMyy-hhmm
 ### Create output path
    if ($PSScriptRoot){
    ### Filepath for running as script - same directory as script
        $Filepath = $PSScriptRoot + "\ForceLogoutLog-" + $Date + ".txt"
    }else{
    ### Filepath for testing from ISE:
        $Filepath = "C:\Users\dudley.andrews\Desktop" + "\ForceLogoutLog-" + $Date + ".txt"
    }
$Log | Out-File $Filepath

Write-Host "Log generated at $filepath"
Read-Host -Prompt "Press Enter to exit"