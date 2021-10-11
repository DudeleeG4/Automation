#-----------------------------------------------------------------------------
#  Program Name    : Control_VM_Script.ps1 
#  Purpose         : This Powershell / PowerCLI script controls
#                  : stopping and Starting the MFSS CNC / Payroll Project VMs
#  Version Number  : 0.1
#  Author          : Graham Hallas
#
#  Version History
#  ---------------
#  Date       Version      Changed By       Description
#  ----       -------      ----------       -----------
#  15/10/15   0.1          Graham Hallas    Initial Draft
#  10/11/15   0.2          Graham Hallas    Changed to use SSH-Sessions Modules
#  12/11/15   0.3          Graham Hallas    Changed to stop/start all VM's as one block 
#											Changed to stop/start all Server Scripts as one block
#											Previous did each script and VM change serially. 
#											Changed to speed up the complete process.
#-----------------------------------------------------------------------------
param([string]$configfile="dummy.ps1")

# ===============================================
#  Call external Configuration File
# ===============================================
#
# Path needs to match your installation of vSphere PowerCLI
& "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1"

. ((Split-Path $MyInvocation.InvocationName) + "\" + $configfile)

# ===============================================
# Define Script Functions
# ===============================================

function Usage()
{
	Write-Host ""
	Write-Host "Usage: "
	Write-Host ""
	Write-Host "     Control_VM_Script.ps1 [ Stop | Start ] "
	Write-Host ""
	exit 

}

function Log($message)
{
	$date = Get-Date -UFormat "%d-%m-%y %H:%M"
	$message = $date + " " + $message
	$message|out-file -FilePath $log -Append
	Write-Host $message
}

function NewLogFile()
{
	if (((Get-date) - (Get-ChildItem $log).LastWriteTime).TotalMinutes -gt 120 )
	{
	 $rename_date = Get-Date -UFormat "%d%m%y%H%M"
	 Get-ChildItem $log |  Rename-Item -NewName { $_.Name -replace "\.log","_$rename_date.log" }
	}
}

function Login($orgid,$creds)
{
	try
	{
		Log "Logging In: $vcloudaddress OrgId: $orgid"
		Connect-CIServer -Org $orgid -Credential $creds -Server $vcloudaddress -EA "Stop" > $null
		Log "Sleeping for 60 seconds"
	}
	catch
	{
		Log $Error[0].Exception.Message
	}

}

function SendEmail($message,$address)
{
	try
	{	
		Send-MailMessage -Body $message -From $mailfromaddress -Subject "VM Scheduler Notification" -To $address -smtpserver $mailserver
	}
	catch [System.Exception]
	{
		Log $Error[0].Exception.Message
	}

}

function ValidateTime($timeoff,$timeon)
{
	$timeon = $($timeon.replace(":","")) -as [int]
	$timeoff = $($timeoff.replace(":","")) -as [int]
	$now = $(get-date -UFormat %H%M) -as [int]
	
	# write-host "Now:$now On:$timeon Off:$timeoff"
	
	# New 24Hrs Validation Check
	#if($timeon -ge $timeoff)
	#{
	# echo "Shutdown occurs after midnight "
	# 	if (($now -ge $timeon -and $now -le 2359) -or ($now -ge 0 -and $now -le $timeoff))
	# 	{
	# 		return $True
	# 	} 
	# 	else
	# 	{
	# 		return $False
	# 	} 
	# 	elseif($now -ge $timeon -and $now -le $timeoff)
	# 		{
	# 			return $True
	# 		} 
	# 		else
	# 		{
	# 			return $False
	# 		}
	# }
	# Abover replaces the check below
	
	if($now -ge $timeon -and $now -le $timeoff)
	{
		return $True
	}
	else
	{
		return $False
	}
}

function PowerOperation($operation,$vm)
{
	$vmname = $vm.name
	try
	{
		if ($operation -eq "On")
		{
			Log " Powering On $vmname"
			Start-CIVM -vm $vm -Confirm:$false -RunAsync -EA "Stop"
		}
		elseif ($operation -eq "Off")
		{
				Log " Powering Off $vmname"
				Stop-CIVMGuest -vm $vm -Confirm:$false -RunAsync -EA "Stop"
		}
		else
		{
			Log " Invalid Power Operation For VM $vmname"
		}
	}
	catch
	{
		Log $Error[0].Exception.Message
		if ($notifyerrors)
		{
			SendEmail "Power Operation For VM $vmname Failed" $email
		}
	}
}

function GetCredentialsForOrg($orgid)
{

	# $file = "$credentialstore\$orgid.cred"
	$credFile="$credentialstore\${orgid}_$([Environment]::Username).cred"
	
	try
	{
		# $credstrings = get-content -Path $file -EA "Stop"
		$credstrings = get-content -Path $credFile -EA "Stop"
		if($credstrings.length -ne 2)
		{
			write-error "Credentials File Format Incorrect, Re-Capture Credentials And Try Again"
		}
		$username=$credstrings[1]
		$pass = ConvertTo-SecureString $credstrings[0]
		
		$creds = New-Object System.Management.Automation.PsCredential($username, $pass)
		if(!$creds)
		{
			write-error "Failed To Get Creds For Org: $orgid"
		}
		return $creds
		
	}
	catch
	{
		Log $Error[0].Exception.Message
		if ($notifyerrors)
		{
			SendEmail "Failed To Retrieve Credentials For $orgid" $email
		}
	}
	
}

function RunPowerOperationSteps($vmlist)
{
	
	$previousorgid = ""
	foreach ($vm in $vmlist)
	{
		$vmname = $vm.vmName
		$timeon = $vm.timeOn
		$timeoff = $vm.timeOff
		$email = $vm.notifyEmail
		$orgid = $vm.orgId
	
		$creds = GetCredentialsForOrg $orgid
		if ($creds -AND $orgid -ne $previousorgid)
		{
			Login $orgid $creds
		}
		
		Log "Processing Power Operation Steps VM: $vmname"
		$poweredon = $True
		try
		{
			$vm = get-civm -Name $vmname -EA "Stop"
			if($vm.status -ne "PoweredOff")
			{
				$poweredon = $True
			}
			else
			{
				$poweredon= $False
			}
			
			$expectedstatus = ValidateTime $timeoff $timeon
			if($poweredon -ne $expectedstatus)
			{
				
				if($expectedstatus)
				{
					PowerOperation "On" $vm
					Log "	Pausing to allow $vmname to Power On to complete"
				}
				else
				{
					PowerOperation "Off" $vm	
				}
			}
		}
		catch 
		{
			Log $Error[0].Exception.Message
		}

		
		
		$previousorgid = $orgid
		
	}
	
	# Log "Completed all tasks against the VM Power Status"
}

function CreateActionArrays($vmlist)
{
	$previousorgid = ""
	foreach ($vmItem in $vmlist)
	{
		$vmname = $vmItem.vmName
		$timeon = $vmItem.timeOn
		$timeoff = $vmItem.timeOff
		$email = $vmItem.notifyEmail
		$orgid = $vmItem.orgId
	
		$creds = GetCredentialsForOrg $orgid
		if ($creds -AND $orgid -ne $previousorgid)
		{
			Login $orgid $creds
		}
		
		Log "Identifying Power Action for VM: $vmname"
		$poweredon = $True
		try
		{
			$vm = get-civm -Name $vmname -EA "Stop"
			if($vm.status -ne "PoweredOff")
			{
				$poweredon = $True
				Log "	$vmname is currently Powered On"
			}
			else
			{
				$poweredon= $False
				Log "	$vmname is currently Powered Off"
			}
			
			$expectedstatus = ValidateTime $timeoff $timeon
			if($poweredon -ne $expectedstatus)
			{
				
				if($expectedstatus)
				{
					Log "	$vmname Should Be Powered On"
					$global:vmListOn+=$vmItem
				}
				else
				{
					Log "	$vmname Should Be Powered Off"
					$global:vmListOff+=$vmItem					
				}
			}
			else
			{
				Log "	$vmname is in the expected power state"
			}
		}
		catch 
		{
			Log $Error[0].Exception.Message
		}

		
		
		$previousorgid = $orgid
		
	}
}

# ===============================================
# Main Process Body
# ===============================================

if ( $($args.Count) -ne 0 )
{ 
	Usage
} 
 else
{
     NewLogFile
}
	
$global:vmListOn = @()
$global:vmListOff = @()


Log "====================================================="
Log "Running Control_VM_Script.ps1 "
Log "====================================================="

$GetvmMainList='$vmlist = import-csv $vmfile |Sort-Object -Property vSeq'

try
{
	Invoke-Expression -command $GetvmMainList
}
catch [System.Exception]
{
	Log($Error[0].Exception.Message)
}


CreateActionArrays $vmlist 

if($global:vmListOn.length -ne 0)
{
    [array]::Reverse($global:vmListOn)
	RunPowerOperationSteps $global:vmListOn
	Start-Sleep -s 370
}

if($global:vmListOff.length -ne 0)
{
	Start-Sleep -s 120		
	RunPowerOperationSteps $global:vmListOff 
}

Log "====================================================="
Log "Completed Control_VM_Script.ps1 "
Log "====================================================="
