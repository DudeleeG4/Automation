Get-Module -ListAvailable | Where {$_.Name -like "VM*"} | Import-Module
Import-Module Microsoft.Powershell.Utility -ErrorAction 'silentlycontinue' -WarningAction 'silentlycontinue'
Clear
$MoveHistory = $Null
$DesktopPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
$OutPath = "$DesktopPath\vMotion Report.csv"
###########################################################################################################################

[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")

$objForm = New-Object System.Windows.Forms.Form 
$objForm.Text = "vCenter Select"
$objForm.Size = New-Object System.Drawing.Size(600,300) 
$objForm.StartPosition = "CenterScreen"

$objForm.KeyPreview = $True
	
$objForm.Add_KeyDown({if ($_.KeyCode -eq "Enter") 
    {$x=$objListBox.SelectedItem;$objForm.Close()}})
$objForm.Add_KeyDown({if ($_.KeyCode -eq "Escape") 
    {$objForm.Close()}})
	
$OKButton = New-Object System.Windows.Forms.Button
$OKButton.Location = New-Object System.Drawing.Size(425,240)
$OKButton.Size = New-Object System.Drawing.Size(75,23)
$OKButton.Text = "OK"
$OKButton.Add_Click({$x=$objListBox.SelectedItem;$objForm.Close()})
$objForm.Controls.Add($OKButton)
	
$CancelButton = New-Object System.Windows.Forms.Button
$CancelButton.Location = New-Object System.Drawing.Size(500,240)
$CancelButton.Size = New-Object System.Drawing.Size(75,23)
$CancelButton.Text = "Cancel"
$CancelButton.Add_Click({$objForm.Close()})
$objForm.Controls.Add($CancelButton)

$objLabel = New-Object System.Windows.Forms.Label
$objLabel.Location = New-Object System.Drawing.Size(10,20) 
$objLabel.Size = New-Object System.Drawing.Size(280,20) 
$objLabel.Text = "Please select one or more vCenter(s):"
$objForm.Controls.Add($objLabel)
	
$objListBox = New-Object System.Windows.Forms.ListBox 
$objListBox.Location = New-Object System.Drawing.Size(10,40) 
$objListBox.Size = New-Object System.Drawing.Size(560,350) 
$objListBox.Height = 190

$objListBox.SelectionMode = "MultiExtended"
							
[void] $objListBox.Items.Add("vcw00001i2.il2management.local")
[void] $objListBox.Items.Add("vcw00002i2.il2management.local")
[void] $objListBox.Items.Add("vcw00003i2.il2management.local")
[void] $objListBox.Items.Add("vcw00004i2.il2management.local")
[void] $objListBox.Items.Add("vcw00005i2.il2management.local")
[void] $objListBox.Items.Add("vcw00007i2.il2management.local")
[void] $objListBox.Items.Add("vcw00008i2.il2management.local")
[void] $objListBox.Items.Add("vcw00009i2.il2management.local")
[void] $objListBox.Items.Add("vcw0000ai2.il2management.local")
[void] $objListBox.Items.Add("vcv00004i2.pod00001.sys00001.il2management.local")
[void] $objListBox.Items.Add("vcv00005i2.pod00002.sys00002.il2management.local")
[void] $objListBox.Items.Add("vcv00006i2.pod00003.sys00004.il2management.local")
[void] $objListBox.Items.Add("vcv00007i2.pod00003.sys00004.il2management.local")
[void] $objListBox.Items.Add("vcv0000bi2.pod0000b.sys00005.il2management.local")
[void] $objListBox.Items.Add("vcv0000ci2.pod0000b.sys00005.il2management.local")
[void] $objListBox.Items.Add("vcv0000di2.pod0000f.sys00006.il2management.local")
[void] $objListBox.Items.Add("vcv0000ei2.pod0000f.sys00006.il2management.local")

$vCenterServers = $objListBox.SelectedItems 
	
$objForm.Controls.Add($objListBox)
$objForm.Topmost = $True

$objForm.Add_Shown({$objForm.Activate()})
[void] $objForm.ShowDialog()



#####################################################################################################################################
Function New-PercentageBar {

[CmdletBinding(DefaultParameterSetName='PERCENT')]

Param (
	[Parameter(Mandatory,Position=1,ValueFromPipeline,ParameterSetName='PERCENT')]
		[ValidateRange(0,150)]
	[int]$Percent
	,
	[Parameter(Mandatory,Position=1,ValueFromPipeline,ParameterSetName='VALUE')]
		[ValidateRange(0,[double]::MaxValue)]
	[double]$Value
	,
	[Parameter(Mandatory,Position=2,ParameterSetName='VALUE')]
		[ValidateRange(1,[double]::MaxValue)]
	[double]$MaxValue
	,
	[Parameter(Mandatory=$false,Position=3)]
		[Alias("BarSize","Length")]
		[ValidateRange(10,100)]
	[int]$BarLength = 20
	,
	[Parameter(Mandatory=$false,Position=4)]
		[ValidateSet("SimpleThin","SimpleThick1","SimpleThick2","AdvancedThin1","AdvancedThin2","AdvancedThick")]
	[string]$BarView = "SimpleThin"
	,
	[Parameter(Mandatory=$false,Position=5)]
		[ValidateRange(50,80)]
	[int]$GreenBorder = 60
	,
	[Parameter(Mandatory=$false,Position=6)]
		[ValidateRange(0,100)]
	[int]$YellowBorder = 80
	,
	[Parameter(Mandatory=$false)]
	[switch]$NoPercent
	,
	[Parameter(Mandatory=$false)]
	[switch]$DrawBar
)

Begin {

	If ($PSBoundParameters.ContainsKey('VALUE')) {$Percent = $Value/$MaxValue*100 -as [int]}
	
	
	If ($YellowBorder -le $GreenBorder) {Throw "The [-YellowBorder] value must be greater than [-GreenBorder]!"}
	
	Function Set-BarView ($View) {
		Switch -exact ($View) {
			"SimpleThin"	{$GreenChar = [char]9632; $YellowChar = [char]9632; $RedChar = [char]9632; $EmptyChar = "-"; Break}
			"SimpleThick1"	{$GreenChar = [char]9608; $YellowChar = [char]9608; $RedChar = [char]9608; $EmptyChar = "-"; Break}
			"SimpleThick2"	{$GreenChar = [char]9612; $YellowChar = [char]9612; $RedChar = [char]9612; $EmptyChar = "-"; Break}
			"AdvancedThin1"	{$GreenChar = [char]9632; $YellowChar = [char]9632; $RedChar = [char]9632; $EmptyChar = [char]0x0020; Break}
			"AdvancedThin2"	{$GreenChar = [char]9642; $YellowChar = [char]9642; $RedChar = [char]9642; $EmptyChar = [char]0x0020; Break}
			"AdvancedThick"	{$GreenChar = [char]9617; $YellowChar = [char]9618; $RedChar = [char]9608; $EmptyChar = [char]0x0020; Break}
		}
		$Properties = [ordered]@{
			Char1 = $GreenChar
			Char2 = $YellowChar
			Char3 = $RedChar
			Char4 = $EmptyChar
		}
		$Object = New-Object PSObject -Property $Properties
		$Object
	} #End Function Set-BarView
	
	$BarChars = Set-BarView -View $BarView
	$Bar = $null
	
	Function Draw-Bar {
	
		Param (
			[Parameter(Mandatory)][string]$Char
			,
			[Parameter(Mandatory=$false)][string]$Color = 'White'
			,
			[Parameter(Mandatory=$false)][boolean]$Draw
		)
		
		If ($Draw) {
			Write-Host -NoNewline -ForegroundColor ([System.ConsoleColor]$Color) $Char
		}
		Else {
			return $Char
		}
		
	} #End Function Draw-Bar
	
} #End Begin

Process {
	
	If ($NoPercent) {
		$Bar += Draw-Bar -Char "" -Draw $DrawBar
	}
	Else {
		If     ($Percent -eq 100) {$Bar += Draw-Bar -Char "$Percent% [ " -Draw $DrawBar}
		ElseIf ($Percent -ge 10)  {$Bar += Draw-Bar -Char " $Percent% [ " -Draw $DrawBar}
		Else                      {$Bar += Draw-Bar -Char "  $Percent% [ " -Draw $DrawBar}
	}
	
	For ($i=1; $i -le ($BarValue = ([Math]::Round($Percent * $BarLength / 100))); $i++) {
	
		If     ($i -le ($GreenBorder * $BarLength / 100))  {$Bar += Draw-Bar -Char ($BarChars.Char1) -Color 'DarkGreen' -Draw $DrawBar}
		ElseIf ($i -le ($YellowBorder * $BarLength / 100)) {$Bar += Draw-Bar -Char ($BarChars.Char2) -Color 'Yellow' -Draw $DrawBar}
		Else                                               {$Bar += Draw-Bar -Char ($BarChars.Char3) -Color 'Red' -Draw $DrawBar}
	}
	For ($i=1; $i -le ($EmptyValue = $BarLength - $BarValue); $i++) {$Bar += Draw-Bar -Char ($BarChars.Char4) -Draw $DrawBar}
	$Bar += Draw-Bar -Char " " -Draw $DrawBar
	
} #End Process

End {
	If (!$DrawBar) {return $Bar}
} #End End

} #EndFunction New-PercentageBar

#####################################################################################################################################
if (!$vCenterServers)
{
Write-Host "No vCenter selected!"
exit
}

$gDate = Get-Date -Format "dd-MM-yyyy"
$DesktopPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
$outPath = "$DesktopPath\vMotion Report $gDate.csv"
$cred = Get-Credential -Message 'Please enter your username@il2management.local'
if (!$cred){exit}
#####################################################################################################################################
$message  = 'Range Selection'
$question = 'Do you want to look at unhealthy clusters only?'
$MoveHistory = @()

$choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No, show me all clusters'))

$decision = $Host.UI.PromptForChoice($message, $question, $choices, 1)
#####################################################################################################################################


Connect-viserver -Server $vCenterServers -Credential $cred
Write-Host "Gathering Host information..."
Do
{
	If ($decision -eq 0)
	{
	  			$GH = Get-VMHost 
				$hostsraw = @()
				ForEach ($ESXHost in $GH)
				{
					$ESXHost | %{
					$info = "" |
					select "Cluster Name", CPU, Memory
					$info."Cluster Name" = $_.Parent
					$info.CPU = ([Math]::Round($_.CpuUsageMhz*100/$_.CpuTotalMhz,2))
					$info.Memory = ([Math]::Round($_.MemoryUsageGB*100/$_.MemoryTotalGB,2))
					
					$hostsraw += $info
								}
				}

			$ClusterRaw = $hostsraw | Where-Object {$_.Memory -gt 90 -or $_.CPU -gt 95} | 
			select "Cluster Name"

			
			if(!$ClusterRaw)
			{	
				Disconnect-VIServer * -Confirm:$false -ErrorAction Ignore
				Write-Host "There are no unhealthy clusters"
                Read-Host "Press Enter to close"
				Exit
			}
			$GH = $ClusterRaw."Cluster Name" | Get-VMHost 
	}


	Else 
	{
	$GH = Get-VMHost  
	}           


	$report = @()
	$Progress = 0
	ForEach ($ESXHost in $GH)
	{		
			$Progress += 1
			Write-Progress -Activity "Gathering Cluster performance information.." -PercentComplete ($Progress/$GH.Count*100) -Id 1
	      $ESXHost | %{
	                        $info = "" | 
	                        select VC, "Cluster Name", Host, "Host State", "% CPU Usage", "% Memory Utilization", Comment, CPU, Memory
	                        $info.VC = $_.Client.ServerUri.trim("443@")
	                        $info.Host = $ESXHost
	                        $info."Cluster Name" = $_.Parent
	                        $info."Host State" = $_.State
	                        $info."% CPU Usage" = New-PercentageBar -Value ([Math]::Round($_.CpuUsageMhz*100/$_.CpuTotalMhz,2)) -MaxValue 100 -Barlength 40 -BarView AdvancedThick -GreenBorder 75 -YellowBorder 95
	                        $info."% Memory Utilization" = New-PercentageBar -Value ([Math]::Round($_.MemoryUsageGB*100/$_.MemoryTotalGB,2)) -MaxValue 100 -Barlength 40 -BarView AdvancedThick -GreenBorder 70 -YellowBorder 90
	                        $info.CPU = ([Math]::Round($_.CpuUsageMhz*100/$_.CpuTotalMhz,2))
	                        $info.Memory = ([Math]::Round($_.MemoryUsageGB*100/$_.MemoryTotalGB,2))
	                        if($info.CPU -gt 95) 
	                              {
	                              $info.Comment = "Warning! High CPU usage! "
	                              }
	                        if ($info.Memory -gt 90)
	                              {
	                              $info.Comment += "Warning! High Memory utilization! "
	                              }
	                        if ($info."Host State" -like "Maintenance") 
	                              {
	                              $info.Comment += "Warning! Host in maintenance mode! "
	                              }
	                        if ($info."Host State" -like "Disconnected")
	                              {
	                              $info.Comment += "Warning! Host disconnected! "
	                              }
	                        if ($info."Host State" -like "NotResponding")
	                              {
	                              $info.Comment += "Warning! Host not responding! "
	                              }
	                        if ($info.Comment -like "")
	                              {
	                              $info.Comment = "All OK"
	                              }
	if($info."Cluster Name" -ne $report[-1]."Cluster Name")
	{
	     $BlankRow = "" | select VC, "Cluster Name", Host, "Host State", "% CPU Usage", "% Memory Utilization", Comment, CPU, Memory
	     $report += $BlankRow
	}
	$report += $info
	                        }
	}
	Write-Progress -Activity "Gathering Cluster performance information..." -Id 1 -Completed
	$Progress = 0
	do{
		$Report = $Report | Select VC, "Cluster Name", Host, "Host State", "% CPU Usage", "% Memory Utilization", Comment 
		$HostSelection = $Report | Out-GridView -Title "Select a Host" -PassThru -ErrorAction SilentlyContinue
		if (!$HostSelection)
		{
			Disconnect-VIServer * -Confirm:$false -ErrorAction Ignore
			$MoveHistory | Out-Gridview -Title "Select items and press okay to export to desktop" -Passthru | Export-CSV $OutPath -NoTypeInformation
			Exit
		}

		Write-Host "Calculating Cluster and Host memory information..."
		$RecommendedStats = $HostSelection."Cluster Name" | Get-VMHost
		$ClusterAverage = (($RecommendedStats.MemoryUsageGB | Measure-Object -Sum).sum)/(($RecommendedStats.MemoryTotalGB | Measure-Object -Sum).sum)*100
		$SelectionPercent = ($HostSelection.Host.MemoryUsageGB)/($HostSelection.Host.MemoryTotalGB)*100
		$HostOnePercent = ($HostSelection.Host.MemoryTotalGB)/100
		$AmountToMove = ([Math]::Round((($ClusterAverage - $SelectionPercent)*$HostOnePercent),2))*(-1)
				
		$VMReport = $null
		$VMReport = @()
		Write-Host "Gathering VMs from selected host..."
		$VMinitialSelection = Get-VM -Location $HostSelection.Host 
		$Progress = 0
		foreach ($VM in $VMinitialSelection)
		{	
			$Progress += 1
			Write-Progress -Activity "Calculating VM performance.." -PercentComplete ($progress/$VMInitialSelection.Count*100) -Id 2
		    $memoryused = get-stat -Entity $VM -Realtime -Stat "Mem.Consumed.Average" -MaxSamples 1 -ErrorAction SilentlyContinue
		    $table = "" | select VM, "Power State", "CPU Usage", "Max CPU MHz", "Memory Used %", "Memory MB", "Resource Pool", "vOrg"
		    $table.VM = $VM
		    $table."Power State" = $VM.PowerState
		    $table."CPU Usage" = get-stat -Entity $VM -Realtime -Stat "cpu.usage.average" -MaxSamples 1 -errorAction SilentlyContinue
		    $table."Max CPU MHz" = $VM.ExtensionData.Runtime.MaxCpuUsage
		    $table."Memory Used %" = New-PercentageBar -Value (($memoryused.Value/1000/1000)/($VM.MemoryGB)*100) -MaxValue 100 -Barlength 40 -BarView AdvancedThick -GreenBorder 70 -YellowBorder 90
		    $table."Memory MB" = $VM.MemoryMB
		    $table."Resource Pool" = $VM.ResourcePool
		    $table."vOrg" = $VM.Folder.Parent.Parent -split " " | select -First 1
		    $VMReport += $table
		}
		Write-Progress -Activity "Calculating VM performance.." -Completed -Id 2
		$Progress = 0
		
		$VMSelection = $VMReport | Sort "Memory MB" -Descending | sort "Power State" -Descending | Out-GridView -Title "This host is $AmountToMove GB away from being balanced" -Passthru -ErrorAction SilentlyContinue
		if(!$VMSelection)
		{	
			Disconnect-VIServer * -Confirm:$false -ErrorAction Ignore
			$MoveHistory | Out-Gridview -Title "Select items and press okay to export to desktop" -Passthru | Export-CSV $OutPath -NoTypeInformation
			exit
		}
		Write-Host "Gathering up-to-date Host stats for Cluster"
		$GH = Get-Cluster $HostSelection."Cluster Name" | Get-VMHost 
		$report2 = @()
		ForEach ($ESXHost in $GH)
		{	$Used = ([Math]::Round($ESXHost.MemoryUsageGB))
			$Total = ([Math]::Round($ESXHost.MemoryTotalGB))
	        $info = "" | select VC, "Cluster Name", Host, "Host State", "CPU Usage %", "Memory Utilization (GB)", "Balance Differential (GB)", "GB Free"
	        $info.VC = $ESXHost.Client.ServerUri.trim("443@")
	        $info.Host = $ESXHost
	        $info."Cluster Name" = $ESXHost.Parent
	        $info."Host State" = $ESXHost.State
	        $info."CPU Usage %" = [Math]::Round($ESXHost.CpuUsageMhz*100/$ESXHost.CpuTotalMhz,2)
	        $info."Memory Utilization (GB)" = (($Used),"/",($Total))
			$info."Balance Differential (GB)" = ([Math]::Round((($ClusterAverage -((($Used/$Total))*100))*($Total/100)),2))*(-1)
	        $info."GB free" = ($Total-$Used)
	     
			$report2 += $info
		}

		$DestinationHost = $Report2 | Where-Object {$_.VC -like $HostSelection.VC} | Where-Object {$_.Host -notin $HostSelection.Host} | Out-GridView -Title "Select Destination Host" -PassThru -ErrorAction SilentlyContinue
		if (!$DestinationHost)
		{
			Disconnect-VIServer * -Confirm:$false -ErrorAction Ignore
			$MoveHistory | Out-Gridview -Title "Select items and press okay to export to desktop" -Passthru | Export-CSV $OutPath -NoTypeInformation
			exit
		}
		$HostSelection = $HostSelection.Host
		$DestinationHost = $DestinationHost.Host
		$VC =  $VMSelection.VM.Client.ServerUri -split "@" | select -Index 1
		foreach ($Selection in $VMSelection)
		{
			$History = "" | Select VM, Source, Destination, vCenter, Cluster
			$History.VM = $Selection.VM.Name
			$History.Source = $HostSelection
			$History.Destination = $DestinationHost
			$History.vCenter = $VC -split "\." | select -Index 0
			$History.Cluster = $Selection.VM.VMHost.Parent
			$MoveHistory += $History
		}
		Move-VM -VM $VMSelection.VM -Destination $DestinationHost -Confirm:$false -erroraction Continue -Whatif 
		$Continue = Read-Host "Do you want to Choose another host? (Yes/No)"

		if ($Continue -like "No")
		{
			$FinalContinue = "No"
		}
		
		if ($Continue -like "Yes")
		{
			$FinalContinue = Read-Host "Do you want to refresh the cluster's list? (Yes/No)"
			if ($FinalContinue -like "Yes")
			{
				$Continue = "No"
			}
		}

	}
	Until($Continue -like "No")
	$report = $Null
	if ($FinalContinue -like "Yes")
	{
		Write-Host "Refreshing Host information from all vCenters..."
	}
}
Until($FinalContinue -like "No")
$MoveHistory | Out-Gridview -Title "Select items and press okay to export to desktop" -Passthru | Export-CSV $OutPath -NoTypeInformation
Disconnect-viserver * -Confirm:$false
