Get-DatastoreFolderInfo.ps1

this script will pull the information of the folders within a certain subset of datastores

this can be filtered by vCentre (at connection) and then Datastores.

OR

if -AllvCenters and -AllCustomers are added (as switches) then this will run for all.




it returns;

vCentre							Datastore			Folder
vcv0000ci2.pod0000b.sys00005.il2management.local	pod0000b-cc01-ssd01-vol014	zerto-preseed-cr-testing



Origin;
this script was created by JMcCormick following a request by GSohal. The use case was a need to find all zerto folders in specific 
vCentres/Datastores so we can then review date last modified as there could be orphaned. initial scripting lead to 2TB or orphaned
files to be found and space reclaimed. 
Extended with additional functionality on 18/09/2018


On-going improvement;
the script would benefit from extra information returned. firstly, the size of the folder and subdirectories. secondly, the east oldest
modified date of all end files, i.e. if the folder hasn't had any updates in 3 months then this would show as that specific date, or 
conversely, if only one file is still being written to daily, it should be the date last written to of this file.

This Script is written in a non-de-duplicated form and will need to be included in the de-duplication tasks.
