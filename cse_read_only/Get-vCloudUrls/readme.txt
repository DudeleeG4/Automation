Get-vCloudUrls

Assembles a vCloud URL that can be used to navigate to a VM in the vCloud GUI. The only required input is a VM name.

It will mainly be checking against a list of VMs contained within "C:\Scripts\Technology\CSE\Triage\VMStore.xml". This VMstore file gets updated from the EstateAPI by the script
if it finds that the age of the file is greater than 1 day.
First time run is the slowest as it has to load the information from the VMstore file into memory, but it can be left open and run repeatedly. Each subsequent run will be more or less instant.

Currently, this script is designed only to be run from "C:\Scripts\Technology\CSE\Triage" Scripts on either main jump box.

