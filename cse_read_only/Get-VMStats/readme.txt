Get-VMStats.ps1

Version 1.0.0

Author(s) -  James McCormick

This Script will get the following stats for the selected subset of VMs

- CPU.Usage.Average
- MEM.Usage.Average
- NET.Usage.Average
- Disk.used.latest






TODOs
2	TODO need to better pipeline//function this
16	TODO this function needs extracting//refactoring.
80	Ask user which resource pool but this is related to customer compute names  #TODO need to better rationalise and/or extend w/ SINT
86	list of Required stats -  TODO Dynamically Generate this on user interface. add remove options.
100	todo - need to refactor the following line to allow dynamic setting of start date and interval. when set to 300 gets all availible stats.
136	todo add idempotent file location check