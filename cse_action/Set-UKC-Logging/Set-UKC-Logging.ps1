
<#
.SYNOPSIS
    Sets Logging for Powershell Scripts in a Directory

.DESCRIPTION
    This script will -Add or -Remove the lines required for UK Cloud logging the use of powershell scripts, 
    it does this recurively for all files in -FileLoc unless -NoRecurse is set. a -Reason should be added 
    to give better tracking of this addition ( i.e. added due to CH 1010101 )
.NOTES
    Authors: Olive Nock & James McCormick 
.PARAMETER Add
    uses the Set to Add logging
.PARAMETER Remove
    uses the Set to Remove logging
.PARAMETER FilesLoc
    sets the location for the file search (Default as recursive search, include -NoRecurse for single level folder search.)
.PARAMETER NoRecurse
    the file search is non-recursive
.PARAMETER Reason
    adds extended context to the #comment
.PARAMETER Verify
    allows you to verify the number of scripts with or without logging
.EXAMPLE
    Via Commandline
    ####
    powershell -command ".\Set-UKC-Logging.ps1 -Add -Reason 'added due to CH 1010101' -FilesLoc C:\Scripts"
    ####

#>

[CmdletBinding()]

Param(
    [Parameter(
        Mandatory=$false,
        HelpMessage="include if you want the script to Add Logging Rules"
    )]
    [Switch]
    $Add,

    [Parameter(
        Mandatory=$false,
        HelpMessage="include if you want the script to Remove Logging Rules"
    )]
    [Switch]
    $Remove,

    [Parameter(
        Mandatory=$true,
        HelpMessage="Enter the Location you wish to search for files - recursive"
    )]
    [String]
    $FilesLoc,

    [Parameter(
        Mandatory=$false,
        HelpMessage="remove recursive searching of the folder selected, single level only."
    )]
    [Switch]
    $NoRecurse,

    [Parameter(
        Mandatory=$false,
        HelpMessage="run -AsAdmin"
    )]
    [Switch]
    $AsAdmin,

    [Parameter(
        Mandatory=$false,
        HelpMessage="Verify number of scripts with//without logging"
    )]
    [Switch]
    $Verify, 
    
    [Parameter(
        Mandatory=$false,
        HelpMessage="include if you want the script to run as an Update"
    )]
    [Switch]
    $Update, 

    [Parameter(
        Mandatory=$false,
        HelpMessage="Enter Reason for addition"
    )]
    [String]
    $Reason

)
   

Begin {
    
    #Ensure running in powershell admin

    if($AsAdmin){
        If ( -NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")){   
            $arguments = "& '" + $myinvocation.mycommand.definition + "'"
            Start-Process powershell -Verb runAs -ArgumentList $arguments
            Break
        }
    }
    function Add-Logging {
        param (
            $AFilesLoc,
            $ANoRecurse,
            $AReason
        )

        if($ANoRecurse){$isRec = "Non-Recursively"}
        else {$isRec = "Recursively"}
        
        While ($AReason.Length -le 4){$AReason = Read-Host -Prompt "Please provide Reason for addition, e.g. CH 1010101"}

        Write-Host "Adding Rules to files in $AFilesLoc $isRec due to $AReason"

        $AFileList = Find-Files -FFilesLoc $AFilesLoc -FNoRecurse $ANoRecurse

        $AAddedCount = Add-lines -ALFileList $AFileList -ALReason $AReason

        Write-Host "Added Logging to $AAddedCount files"

    }
    function Remove-Logging {
        param (
            $RFilesLoc,
            $RNoRecurse            
        )

        if($RNoRecurse){$isRec = "Non-Recursively"}
        else {$isRec = "Recursively"}

        Write-Host "Removing Rules from files in $RFilesLoc $isRec"
        
        $RFileList = Find-Files -FFilesLoc $RFilesLoc -FNoRecurse $RNoRecurse

        $RRemovedCount = Remove-lines($RFileList)

        Write-Host "Removed Logging from $RRemovedCount files"

    }
    function Find-Files {
        param (
           $FFilesLoc,
           $FNoRecurse
        )
    
        if (Test-Path $FFilesLoc){

            if(!$FNoRecurse){ 
                $files = Get-ChildItem -Path "$FFilesLoc" -Exclude "*ps1xml*" -Filter "*.ps1" -Recurse -ErrorAction Ignore 
            }
            elseif($FNoRecurse){ 
                $files = Get-ChildItem -Path "$FFilesLoc" -Exclude "*ps1xml*" -Filter "*.ps1" -ErrorAction Ignore 
            }
            $files =  $files | Where-Object name -notlike "*Set-UKC-Logging*"
            Return $files
        }   

        else{
           write-host "File location not found"; Start-Sleep -seconds 5; exit "File location not found"
        }

    
    }
    function Add-lines {
        param (
            $ALFileList,
            $ALReason
        )

        $CompleteCount = 0

        foreach ($File in $ALFileList){


            if (-not (Find-IfLoggingExist($File))){

                [int]$LineLoc = Find-AddLocation -ALFile $File
                
                $FileContent = Get-content $File
                $BefContent = $FileContent | Select-Object -First ($LineLoc)
                $AftContent = $FileContent | Select-Object -Last ($FileContent.Length - $LineLoc)

                if ($null -eq $AddContent){
                    $CommentLine = "# This is to enable logging and auditing for the use of these scripts. PLEASE DO NOT DELETE. Reason for addition : $($ALReason)"
                    $FirstLine = "Import-Module UKCloud.Logging -errorAction silentlyContinue"
                    $SecondLine = "if (Get-Module UKCloud.Logging){Write-UKCloudLogEntry}"
                    $AddContent = $CommentLine, $FirstLine, $SecondLine
                }

                Set-Content $File -Value $BefContent,$AddContent,$AftContent
            
                $CompleteCount++
            }

        }
       
        Return $CompleteCount
    }
    function Find-IfLoggingExist {
        param (
            $FFile,
            $FLine
        )

        $Line = "*if (Get-Module UKCloud.Logging){Write-UKCloudLogEntry}*"

        if($FLine){$Line = $FLine}
        
        $containsWord = Get-Content $FFile | ForEach-Object {$_ -like $Line}

        if ($containsWord -contains $true){Return $true}
        Else {Return $false}
    }
    function Find-AddLocation {
        param (
            $ALFile
        )

        $ALContent = Get-Content $ALFile

        for ($i=0; $i -lt $ALContent.Length; $i++){
                    
            if ($ALContent[$i] -like "*function*"){

                #Function first found - no params or "Advanced Function" 
                Return 0
            }
            elseif ($ALContent[$i] -like "*param*(*"){

                
                $BCount = Get-BSum($ALContent[$i])
                if ($BCount -eq 0){Return ($i + 1)}
                $LCount = ($i + 1)

                for ($l=$LCount; $l -lt $ALContent.Length; $l++){

                    if ($BCount -ne 0){
                        
                        $BCount = $Bcount + (Get-BSum($ALContent[$l]))

                        if ($BCount -eq 0){$BFinish = $l}
                    }

                    $FuncNext = ($ALContent[$l] -like "*function*")
                    $BeginNext = ($ALContent[$l] -like "*Begin*{*")
                    $ProcNext = ($ALContent[$l] -like "*Process*{*")


                    if($FuncNext -and ($BCount -eq 0)){Return ($BFinish + 1)}
                    if($BeginNext -and ($BCount -eq 0)){Return ( $l + 1 )}
                    if($ProcNext -and ($BCount -eq 0)){Return ( $l + 1 )}
                    if($ALContent.length -eq ($l + 1)){Return ($BFinish + 1)}

                }
               
            }
            elseif ($ALContent[$i] -like "*Begin*{*") {
                Return ( $i + 1 )
            }
            elseif ($ALContent[$i] -like "*Process*{*") {
                Return ( $i + 1 )                
            }
                   
        }
           
    }
    function Get-BSum {
        param (
            $Content
        )
        
        $BPlus = ($Content.ToCharArray() | Where-Object {$_ -eq '('} | Measure-Object).Count
        $BMinus = ($Content.ToCharArray() | Where-Object {$_ -eq ')'} | Measure-Object).Count

        Return($BPlus - $BMinus)

    }
    function Remove-lines {
        param (
            $RLFileList
        )
        
        $CompleteCount = 0

        $RCommentLine = "*This is to enable logging and auditing for the use of these scripts. PLEASE DO NOT DELETE.*"
        $RFirstLine = "*Import-Module UKCloud.Logging*"
        $RSecondLine = "*if (Get-Module UKCloud.Logging){Write-UKCloudLogEntry}*"
        $RBlanketSecondLine = "*if (Get-Module UKCloud.Logging){*UKC*}*" #see JIRA CSE-197 for context
        
        foreach ($File in $RLFileList){

            if (Find-IfLoggingExist -FFile $File -FLine $RBlanketSecondLine){

                $Content = Get-Content $File | Where-Object { ($_ -notlike $RCommentLine -and $_ -notlike $RFirstLine -and $_ -notlike $RSecondLine -and $_ -notlike $RBlanketSecondLine) }
                Set-Content $File -Value $Content
            
                $CompleteCount++
            }

        }
       
        Return $CompleteCount

    }
    function Show-VerifyLogging {
        param (
            $VFilesLoc,
            $VNoRecurse
        )

        $VFileList = Find-Files -FFilesLoc $VFilesLoc -FNoRecurse $VNoRecurse

        $VWithCount = 0
        $VWithoutCount = 0

        foreach ($File in $VFileList){

            $VResult = Find-IfLoggingExist -FFile $File

            If($VResult){$VWithCount++}
            ElseIf(!$VResult){$VWithoutCount++}

        }

        if($VNoRecurse){$isRec = "Non-Recursively"}
        else {$isRec = "Recursively"}

        Write-Output "Verify Logging: Files in $VFilesLoc searching $isRec"
        Write-Output "Files with logging:       $VWithCount"
        Write-Output "Files without logging:    $VWithoutCount"
    }

    function Update-Logging { 
        param (
            $UFilesLoc,
            $UNoRecurse,
            $UReason            
        )

        # Update =  Remove + Re-Add

        Remove-Logging -RFilesLoc $UFilesLoc -RNoRecurse $UNoRecurse

        Add-Logging -AFilesLoc $UFilesLoc -ANoRecurse $UNoRecurse -AReason $UReason


    }

}

Process {

    # Check if Adding or Removing

    if (!$Add -and !$Remove -and !$Verify) { Return "You MUST include -Add, -Remove or -Verify " }
    if ($Add -and $Remove) { Return "You can only include EITHER -Add OR -Remove" }

    if ($Add) { Add-Logging -AFilesLoc $FilesLoc -ANoRecurse $NoRecurse -AReason $Reason }

    if ($Remove) { Remove-Logging -RFilesLoc $FilesLoc -RNoRecurse $NoRecurse }

    if ($Update) { Update-Logging -UFilesLoc $FilesLoc -UNoRecurse $NoRecurse -UReason $Reason }

}

End {

    if($Verify){
        
        Show-VerifyLogging -VFilesLoc $FilesLoc -VNoRecurse $NoRecurse

    }

}