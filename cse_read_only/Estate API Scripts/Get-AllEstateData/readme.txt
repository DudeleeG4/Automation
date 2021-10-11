Get-AllEstateData.ps1

The purpose of this script is to retrieve all of the VMs for a given impact level (IL2, IL3 or both)

It will display information about the company and account for each VM, and runs very quickly.

Running it from the IL2Management domain will show only IL2 results. You will then be prompted to enter your IL2 SINT API Key.

Running it from the IL3Management domain will show only IL3 results. You will then be prompted to enter your IL3 SINT API Key.

Running it from your local machine will prompt the user to select IL2, IL3 or Combined.
You will then be prompted to enter the relevant SINT API Key. 
If you select IL2, you will be prompted to enter your IL2 SINT API Key.
If you select IL3, you will be prompted to enter your IL3 SINT API Key.
If you select Combined, you will be prompted to enter your IL3 SINT API Key.

The results are output to the Desktop of the current user as a .CSV file.