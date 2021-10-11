clear

Import-Module UKCloud.Logging -errorAction silentlyContinue
if (Get-Module UKCloud.Logging){UKC_Write-LogEntry}

$cred = Get-Credential
$vCenterServers = @("vcw00001i2", "vcw00002i2", "vcw00003i2", "vcw00004i2", "vcw00005i2", "vcw00007i2", "vcw00008i2", "vcw00009i2", "vcw0000ai2")
$report = @()
foreach ($vCenterServer in $vCenterServers){
Connect-VIServer $vCenterServer -Credential $cred

##$alarmmanager = $serviceinstance.Content.AlarmManager
#$alarmmanager.GetType()

# Get the service instance for the vCenter(s)
$serviceinstance = Get-View serviceinstance

# Get the alarms for the service instant
$rootfolderviewalarms = (Get-View -Id $serviceinstance.Content.RootFolder).TriggeredAlarmState | Where-Object {$_.Alarm -match "Alarm-alarm-8"}
#$rootfolderviewalarms[1]
#$am = Get-View -Id $serviceinstance.Content.AlarmManager
#$alarmdefinitions = Get-View -Id "Alarm-alarm-8"
#$alarmids = $am.GetAlarm($serviceinstance.Content.RootFolder)
#$alarmids2 = $rootfolderviewalarms.Alarm


#$final = $alarmdefinitions | Where-Object {$_.Info.Name -like "*Datastore*"}
#Disconnect-VIServer * -Confirm:$false

# Create report from alarms
foreach ($alarm in $rootfolderviewalarms){

$info = "" | select vCenter, Alarm, Acknowledged, AcknowledgedBy, AcknowledgedDate
$info.vCenter = $vCenterServer
# Get the actual View object for the alarm by it's ID
$info.Alarm = Get-View -Id $alarm.Alarm
$info.Acknowledged = $alarm.Acknowledged
$info.AcknowledgedBy = $alarm.AcknowledgedByUser
$info.AcknowledgedDate = $alarm.AcknowledgedTime

$report += $info
}
}

$report | Out-GridView -PassThru
