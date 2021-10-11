=============================
Read Me - GetOrgVMsResources.ps1
=============================

Overview:
=============================
This script will export a list of all VMs within a specified organisation along with specific allocated resources:
- VM Name
- Power Status
- CPU
- RAM


=============================
How to Use:
=============================

1) Run script from command line
> powershell .\GetOrgVMsResources.ps1 -Org <Org_ID>
E.g. powershell .\GetOrgVMsResources.ps1 -Org 1-82-23-207827

2) Enter the relevant vCloud
PV1 = vCloud 
PV2: vcd.<pod0000X>.<sys0000X>.il2management.local

3) Enter IL2 Client credentials when prompted

4) Check the script directory for a CSV called <Org_ID>_VmList.csv containing your output.
