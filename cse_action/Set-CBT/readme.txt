Warning - This script will cause all of the VMs specified to have a snapshot taken and then immediately removed, please bear that in mind.

Set-CBT

The purpose of this script is to enable people to automate the process of changing the CBT setting of one or more VMs, to either enabled or disabled.

To run the script, the user will need to create a .txt file with "VM" at the top, and then each VM name on subsequent new lines after this, e.g:

"
VM
vmname1 (aweo23q-0a8ef-aegf0h-awef0aw-awehf0)
vmname2 (21r098h-10438-128903-vbh2u4j-3120rh)
vmname3 (fh83q9k-1h489-fh8fbh-fh210fh-fh1gh8)
vmname4 (fg430q8-fh529-hf139g-f1bh346-nvc31c)
"

The script will start by asking the user for the filepath to this list, e.g:
"C:\Scripts\VMlist.txt"

Then it will ask whether you want to "Enable" or "Disable" CBT. Upon selection, the script will then proceed to enable or disable CBT for the 
specified VMs, based on the user's choice.