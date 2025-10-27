function Get-AlphaNumericString{
Param(
    [Parameter(Mandatory=$true)]$Length
)
    $GUID = [guid]::NewGuid()
    $GUIDSTRING = [string]$GUID
    $GUIDSTRING = $GUIDSTRING.Replace("-", "")
    return $GUIDSTRING.substring(0, $Length)
}

Function Get-RNG{
Param(
    [Parameter(Mandatory=$true)]$Length
)
    $Numerals = @()
    Do{
        $Numerals += Get-Random -Maximum 9
    }Until($Numerals.count -like $Length)
    $Numerals -join ""
}

Function Get-ArwenID{
    $RawIDs = @()
    $RawIDs += Get-AlphaNumericString -Length 8
    $RawIDs += Get-RNG -Length 4
    $RawIDs += Get-AlphaNumericString -Length 13
    $RawIDs -join "-"
}
