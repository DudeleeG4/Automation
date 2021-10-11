Get-CustomerAffinityRules

The purpose of this script it to retrieve all the DRS affinity and anti-affinity rules on the customer facing vCenters of the platform. It does not retrieve host DRS rules.

To run the script, go to any jumpbox with access to the IL2 or IL3 environment and powercli installed, right-click and select "run with powershell".

This script is scheduled to run on the task scheduler box on the first day of every month at 7am.