Show-StorageThreshold.ps1

The Purpose of this script is to determine weather or not adding additional space to a customer vDC will put the datastore cluster over the 85% threshold.

Example: .\Show-StorageThreshold.ps1 -vCenter vcw00009i2 -vDCName test-vdc -VMName test-vm -StorageGB 5000

In this example, we are adding 5TB to the vDC. the -VMName parameter is not essential, if not used it will go through all VMs in the VDC and find the storage relating to those VMs.