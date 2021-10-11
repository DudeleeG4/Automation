
#Get-HostVersionBuild.ps1

This script is designed to allow us to check the Version and Build of Hosts for the selected VDCs (Resource Groups).

the script

* Ensures that Powershell has the necessary PowerCLI modules included.

* Asks for user credentials and connects to all vCentres (Assured or Elevated)

* Pulls all Resource Groups (Closely linked to Org VDCs) and allows you to searcha and select one or more of these.

* Based upon choice, pulls all VMs in the Resource Groups, and then compiles the folliwing into a CSV for each VM

	 -  VM name
	 - vCentre
	 - Host Name
	 - Host Version
	 - Host Build


###Output can be found at - C:\Scripts\Technology\CSE\Get-HostVersionBuild.csv