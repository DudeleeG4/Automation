Get-StorageIOPS

This is a script that was written for Accenture, which is why it currently is hardcoded for that purpose.

In the future this will be edited to prompt the user for which vCenter and resource pool to get the Storage IOPS for.

The output is a CSV at "C:\Scripts\Technology\CSE\Accenture - Production IOPS Performance.csv" and it shows the IOPS maximum, IOPS Read & write averages.

To run the script, you will need to load PowerCLI and run it from there on the IL2 jumpbox.