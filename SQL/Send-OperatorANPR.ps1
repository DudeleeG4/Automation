$Username = Read-Host -Prompt "Username:"
ssh 192.168.178.56 -l $Username #Dudley.andrews


<#
Log on to Linux box (192.168.178.56) as yourself, then sudo su - cobalt
Enter password
cd /home/cobalt/grizzly
Run the syntax, to run for the previous day enter ../bin/sendoperatoranpr -s YYYY-MM-DD+02:00:00
If you need to run the report for just one operator, then use syntax ../bin/sendoperatoranpr -s YYYY-MM-DD+02:00:00 -j Client
If running again, please note the app might not have closed. Verify via the rolling app that the report has run.
For client names this will be the second part of the INI section name, i.e. if INI name is Operator-G24 then enter j G24 to run just this report. If you run for a single operator make sure that the operator name begins with a capital e.g Wycombe.
If you don't input the correct client name this will create a new report for the incorrect client name you have inputted.
#>