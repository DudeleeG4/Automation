# Check if user is running powershell as admin and if not, elevate to admin
#TODO need to better pipeline//function this

Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")){   
	$arguments = "& '" + $myinvocation.mycommand.definition + "'"
	Start-Process powershell -Verb runAs -ArgumentList $arguments
	Break
}

# Load the vmware PowerCLI modules
Get-Module -ListAvailable | Where-Object {$_.Name -like "VM*"} | Import-Module

#FUNCTIONS############################################################################################################

# This function will connect to all vCenters currently listed in IAS (just customer facing vCenters)
#TODO this function needs extracting//refactoring.

Function Connect-CustomerVIServers{
	Param(
		$Credential
	)
	Process{
		if (!$Credential){
			$Credential = Get-Credential -Message "Please provide credentials to log in to the vCenters:"
		}

		if($env:USERDOMAIN -match "IL2"){ 
		    $url = 'http://10.8.81.45/providers'
		}
		elseif($env:USERDOMAIN -match "IL3"){
			$url = 'http://10.72.81.42/providers'
		}
		else{
			$urls = @("http://10.8.81.45/providers", "http://10.72.81.42/providers")
			$url = $urls | Out-GridView -Title "Choose which Impact Level IAS to connect to:" -Passthru
		}
		$Data = (Invoke-WebRequest -Uri $url).Content
		$enc = [System.Text.Encoding]::ASCII
		$Json = $enc.GetString($Data) | ConvertFrom-Json

		$VCList = @()
		ForEach($Item in ($Json.Data | Select-Object -expandproperty attributes)){

		                $VCList += $Item
        }


        $VCList = $VCList |Out-GridView -Title "Select vCentres to connect to" -PassThru

		ForEach ($vCenterServer in $VCList){
		Connect-VIServer $vCenterServer.providerMetadata[1].MetadataValue -Credential $Credential
		}
	}
}

Function LogWrite
{
   Param (
   [string]$logstring,
   [Parameter(Mandatory=$True)]$file
   )

   Add-content $file -value $logstring
}

################################################################################################################

Clear-Host

$Logfile = "C:\Scripts\Technology\CSE\Triage Scripts\Triage Logging\TriageLog.log"
$Date =  Get-Date -format ($culture.DateTimeFormat.ShortDatePattern)
$User = $env:UserName
$ScriptName = "Get-VMStats"
$Location = "$env:ComputerName@$env:UserDomain"
LogWrite -LogString "Script $ScriptName run at $Date by $User from $Location" -file $logfile

# Connect to all customer vCenters using function
Connect-CustomerVIServers

#Ask user which resource pool but this is related to customer compute names  #TODO need to better rationalise and/or extend w/ SINT
$Resourcepools = Get-ResourcePool | Out-GridView -Title "Choose which VDC(s) // Resource Group(s) to review:" -Passthru

# Gather all VM names for selected resourcce pool(s)
$FoundVMs = $Resourcepools | Get-VM | Out-GridView -Title "Choose which VM to review:" -Passthru

# list of Required stats -  TODO Dynamically Generate this on user interface. add remove options.
$ReqStats = "cpu.usage.average" , "mem.usage.average" , "net.usage.average" , "disk.used.latest"

# Build report of the VM's listing their name, version/build and vCenter
$Progress = 0

foreach ($VM in $FoundVMs){

    Write-Progress -Activity "Gathering Information.." -Status "$VM" -PercentComplete ($Progress/$FoundVMs.Count*100)

    $AvailStats = $VM | Get-StatType | Where-object { $_ -in $ReqStats}

    foreach ($AStat in $AvailStats){

		# todo - need to refactor the following line to allow dynamic setting of start date and interval. when set to 300 gets all availible stats.
        $StatsResult = $VM | Get-Stat -Stat $AStat -IntervalSecs 300 -Start (Get-Date).AddHours(-24)

        $ResReport = foreach ($RStat in $StatsResult){
            Try{
                [PSCustomObject]@{
                Name = $VM.Name
                MetricId = $RStat.MetricId
                Timestamp = $RStat.Timestamp
                Value = $RStat.Value
                Unit = $RStat.Unit
                Instance = $RStat.Instance

                }

            }
            Catch{
            }
        }

        $AvailReport += $ResReport

    }

    $Report += $AvailReport
	$Progress ++
}

# Disconnect from the vCenters
Disconnect-VIServer * -Confirm:$false

# Output report to file
$path = "C:\Scripts\Technology\CSE\Get-VMStats.csv"

# todo add idempotent file location check
#if(!(Test-Path $path))
#{
#      New-Item -ItemType Directory -Force -Path $path | Out-Null
#}

$Report | Export-Csv "$path" -NoTypeInformation

# Tell the user that the script is complete and where to find the output
Write-Host "Complete!"
Write-Host "Output can be found at - $path"

# Prompt the user for input before exiting, this stops the script from immediately exiting upon completion so that the user has time to read where the output is
Read-Host -Prompt "Press enter to exit"


