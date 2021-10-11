<#
.SYNOPSIS
    Gets the folder info for selected data stores

.DESCRIPTION
	Gets the folder info for selected data stores, 
	will run interactively as default, asking to 
	confirm the vCentres and Datastores. this can 
	be overridden with -AllvCenters
.NOTES
    Authors: James McCormick 
.PARAMETER Filter
    sets a Filter for use on return data
.PARAMETER AllvCenters
    for non interactive review of all vCenters

.EXAMPLE
    Via Commandline
    ####
    powershell -command ".\Get-DatastoreFolderInfo.ps1 -AllvCenters -AllDatastores -Filter "Zerto-Preseed"
    ####

#>

[CmdletBinding()]
param (
	[Parameter(
        Mandatory=$false,
        HelpMessage="Include all availible vCenters"
    )]
    [Switch]
	$AllvCenters,

	[Parameter(
        Mandatory=$false,
        HelpMessage="Include all availible Datastores"
    )]
    [Switch]
	$AllDatastores,
	
	[Parameter(
        Mandatory=$false,
        HelpMessage="set filter value used when searching datastores"
    )]
    [String]
	$Filter,
	
	[Parameter(
        Mandatory=$false,
        HelpMessage="include SU Credentials"
    )]
    [securestring]
	$SuCred

)
	
begin {
	If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")){   
		$arguments = "& '" + $myinvocation.mycommand.definition + "'"
		Start-Process powershell -Verb runAs -ArgumentList $arguments
		Break
	}
	
	# Load the vmware PowerCLI modules
	Get-Module -ListAvailable | Where-Object {$_.Name -like "VM*"} | Import-Module
	
	Import-Module UKCloud.Logging -errorAction silentlyContinue
	if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}
	
	#This function will connect to all vCenters currently listed in IAS (just customer facing vCenters)
	#TODO: this function needs extracting//refactoring.
	Function Connect-CustomerVIServers{
		Param(
			$Credential,
			$AllVC
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
			
			#Reduce list if not all vCenters
			if(!$AllVC){$VCList = $VCList |Out-GridView -Title "Select vCentres to connect to" -PassThru}	
			
			ForEach ($vCenterServer in $VCList){
			Connect-VIServer $vCenterServer.providerMetadata[1].MetadataValue -Credential $Credential
			}
		}
	}
	
	
	#TODO: Make non-interactive ?
	if (!$SuCred){
		$SuCred = Get-Credential -Message "Please provide SU credentials"
	}

	#connecto to specific vcentre
	Connect-CustomerVIServers -AllVC $AllvCenters -Credential $SuCred
		
}
	
process {

	$datastores = Get-Datastore 
	
	if(!$AllDatastores){ $datastores = $datastores |  out-gridview -passthru -Title "Select Datastores" }

	$Progress = 0
	foreach($ds in $datastores){

		New-PSDrive -Location $ds -Name DS -PSProvider VimDatastore -Root "\" > $null

		$Report = Get-ChildItem -Path DS: | Where-Object{$_.ItemType -eq 'Folder' -and $_.Name -notmatch '^\.|^vmk|^esxconsole|tmp'} |ForEach-Object {
			Write-Progress -Activity "Gathering Information.." -Status "Running for $_" -PercentComplete ($Progress/$datastores.Count*100)
			Try{
				[PSCustomObject]@{

					vCentre =  $ds.ExtensionData.Client.ServiceUrl.Split('/')[2]

					Datastore = $ds.Name

					Folder = $_.Name

					Modified = $_.LastWriteTime

					SizeKB = (Get-ChildItem -Path "DS:\$($_.Name)" -Recurse -Attributes !Directory | Measure-Object -Property Length -Sum | Select-Object -ExpandProperty Sum)/1KB

				}

			}
			Catch{
				#TODO: add further error handling
			}
			
		}
		
		$Progress ++
		$FolderInfo += $Report

		Remove-PSDrive -Name DS -Confirm:$false

	}

	If ($Filter) {
		$FolderInfo = $FolderInfo | Where-Object { $_.Folder -like "*$($Filter)*"}
	}
	else{
		$FolderInfo = $FolderInfo | Out-gridview -passthru -Title "Select information to include in report"
	}
	

}
	
end {

	# Disconnect from the vCenters
	Disconnect-VIServer * -Confirm:$false

	# Output report to file
	$FolderInfo | Export-Csv "C:\Scripts\Technology\CSE\FolderInfo.csv" -NoTypeInformation

	# Tell the user that the script is complete and where to find the output
	Write-Host "Complete!"
	$FinalMessage = "Output can be found at - C:\Scripts\Technology\CSE\FolderInfo.csv"
	Write-Host $FinalMessage

	[void](Read-Host = "Press Enter to continue")

	Return $FinalMessage

}