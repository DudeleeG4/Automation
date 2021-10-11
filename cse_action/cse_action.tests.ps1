$here = Split-Path -Parent $MyInvocation.MyCommand.Path 

$folder = "cse_action"

$ExcludeFolders = ("ExampleExcludeFolder", ".vscode")

$Subfolders = Get-ChildItem -Path "$here" -Directory | Where-Object Name -NotIn $ExcludeFolders


Describe "$Folder Subfolder Checks" -Tags "Unit" {

    Context "Folder Contents" {

        foreach ($Subfolder in $Subfolders){

            Context "$Subfolder :" {

                It "has a README file"{

                    #$Files = Get-ChildItem -Path "$here\$Subfolder"
                    #$FileNames = $Files | Select-Object Name |% $_.ToUpper()

                        
                    "$here\$subfolder\README.*" | Should Exist
        
                }


                It "has its own .tests file"{

                    "$here\$subfolder\$subfolder.tests.ps1"  | Should Exist

                }

            }
            
        }


    }


} 