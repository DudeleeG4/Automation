#This function brings up a GUI interface for multiple or single selection of objects
function Invoke-MultiSelectForm
{
	Param 
	(
		[Parameter(Mandatory=$true,ValueFromPipeline=$true)]$Objects,
		$Title,
		$Message
	)
	Begin{
		If (!$Title){
			$Title = "Item Selection"
		}
		If (!$Message){
			$Message = "Please select an item:"
		}
				[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
		[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")

		$objForm = New-Object System.Windows.Forms.Form 
		$objForm.Text = $title
		$objForm.Size = New-Object System.Drawing.Size(600,300) 
		$objForm.StartPosition = "CenterScreen"

		$objForm.KeyPreview = $True
		
		$objForm.Add_KeyDown({if ($_.KeyCode -eq "Enter") 
	    {$x=$objListBox.SelectedItem;$objForm.Close()}})
		$objForm.Add_KeyDown({if ($_.KeyCode -eq "Escape") 
	    {$objForm.Close()}})
		
		$OKButton = New-Object System.Windows.Forms.Button
		$OKButton.Location = New-Object System.Drawing.Size(425,240)
		$OKButton.Size = New-Object System.Drawing.Size(75,23)
		$OKButton.Text = "OK"
		$OKButton.Add_Click({$x=$objListBox.SelectedItem;$objForm.Close()})
		$objForm.Controls.Add($OKButton)
		
		$CancelButton = New-Object System.Windows.Forms.Button
		$CancelButton.Location = New-Object System.Drawing.Size(500,240)
		$CancelButton.Size = New-Object System.Drawing.Size(75,23)
		$CancelButton.Text = "Cancel"
		$CancelButton.Add_Click({$objForm.Close()})
		$objForm.Controls.Add($CancelButton)

		$objLabel = New-Object System.Windows.Forms.Label
		$objLabel.Location = New-Object System.Drawing.Size(10,20) 
		$objLabel.Size = New-Object System.Drawing.Size(280,20) 
		$objLabel.Text = $message
		$objForm.Controls.Add($objLabel)
		
		$objListBox = New-Object System.Windows.Forms.ListBox 
		$objListBox.Location = New-Object System.Drawing.Size(10,40) 
		$objListBox.Size = New-Object System.Drawing.Size(560,350) 
		$objListBox.Height = 190

		$objListBox.SelectionMode = "MultiExtended"
	}
	Process{
		foreach ($Object in $Objects){
		[void] $objListBox.Items.Add($Object)
		}
	}
	End{
		$output = $objListBox.SelectedItems 

		$objForm.Controls.Add($objListBox)
		$objForm.Topmost = $True

		$objForm.Add_Shown({$objForm.Activate()})
		[void] $objForm.ShowDialog()
		
		$output
	}
}

################################################################################################################

### Gather user's credentials for Lon and Uxb DB 6
##$UxbCreds = Get-Credential -Message "Enter your Uxb Insight DB creds"
$LonCreds = Get-Credential -Message "Enter your Insight DB creds"

### Get the SQL instances used by the script and store then in variables
##$UxbInstance = Get-SQLInstance -ServerInstance 192.168.166.206 -Credential $UxbCreds
$LonInstance = Get-SQLInstance -ServerInstance pr-db-ls-02.cobalt-lon1.ctt.co.uk -Credential $LonCreds #10.208.5.59

### Begin Do loop to allow user to process more than one EOD/EOM ticket or loop back around on the same ticket without having to re-run script and re-enter creds
Do{
    ### Create filepath
        if ($PSScriptRoot){
            ### Create filepath variable for the ticket data file from the directory the script is run from
            $Filepath = $PSScriptRoot + "\TicketBody.txt"
        }Else{
            ### Filepath variable for testing script in ISE
            $Filepath = "C:\Users\dudley.andrews\Desktop\EoDs" + "\TicketBody.txt"
        }
    ### Import ticket data from "TicketBody.txt" file contained in the same directory as the script
    $TicketBody = Get-Content -Path $Filepath

    ### Pull the Frefs out of the ticket data
    $Frefs = $TicketBody | Select-String "\[" |%{($_ -Split " " | Select -Index 4).TrimStart("[")}

    ### Check for web basket Frefs and create separate array for them
    $ParentFrefs = $Frefs | Where {$_ -match "ringgobasket"}

    ### Pull the Frefs out of ticket data and create one string for use in a SQL "in" statement - not used currently
    #$Frefs = "(" + ((($TicketBody | Select-String "\[" |%{($_ -Split " " | Select -Index 4).TrimStart("[")}) |% {"'$_'"}) -Join(",")) + ")"

    ### Create progress counter variable for use with write-progress (the progress bar)
    $Progress = 0
    ### Loop through the Frefs and build the report
    $Report = Foreach ($Fref in $Frefs){

        ### Create progress bar - helps with when there are lots of Frefs so that it doesn't appear to have frozen
        Write-Progress -Activity "Querying Frefs:" -CurrentOperation ("Fref: " + $Fref) -PercentComplete ($Progress/$Frefs.count*100) -Id 0

        ### Create all the SQL queries for counting how many results are returned from each table - needs to be functionised
        $SessionsQueryCount = "SELECT TOP (1000) count(*) AS count
            FROM [Ringgo].[dbo].[Sessions] WITH (nolock)
            WHERE Fref = " + "'$FREF'" + "
            AND ((session_quantity = 1 AND primaryAuditLink = '') OR (primaryAuditLink > ''))"

        $PaymentAppAuditQueryCount = "SELECT TOP (1000) count(*) AS count
            FROM [Cobalt_Payments].[dbo].[PaymentAppAudit] WITH (nolock)
            WHERE Fref = " + "'$FREF'"

        $RefundQueryCount = "SELECT TOP (1000) count(*) AS count
            FROM [Ringgo].[dbo].[Refunds] WITH (nolock)
            WHERE Fref = " + "'$FREF'"

        $PCNQueryCount = "SELECT TOP (1000) count(*) AS count
            FROM [PCN].[dbo].[Payment] WITH (nolock)
            WHERE Fref = " + "'$FREF'"

        $PCNRefundQueryCount = "SELECT TOP (1000) count(*) AS count
            FROM [PCN].[dbo].[Refunds] WITH (nolock)
            WHERE Fref = " + "'$FREF'"
      
        ### Run SQL Count queries against various tables to determine how many entries there are in each table for the current Fref in the loop - store result in variable
        #$UxbSessEntry = Invoke-Sqlcmd -ServerInstance $UxbInstance -Database "Ringgo" -Query $SessionsQueryCount -Credential $UxbCreds
        #if ($UxbSessEntry){$UxbridgeSess = $UxbSessEntry.count}else{$UxbridgeSess = "0"}
        #$UxbPAAEntry = Invoke-Sqlcmd -ServerInstance $UxbInstance -Database "Cobalt_Payments" -Query $PaymentAppAuditQueryCount -Credential $UxbCreds
        #if ($UxbPAAEntry){$UxbridgePAA = $UxbPAAEntry.count}else{$UxbridgePAA = "0"}
        $LonSessEntry = Invoke-Sqlcmd -ServerInstance $LonInstance -Database "Ringgo" -Query $SessionsQueryCount -Credential $LonCreds
        if ($LonSessEntry){$LondonSess = $LonSessEntry.count}else{$LondonSess = "0"}
        $LonPAAEntry = Invoke-Sqlcmd -ServerInstance $LonInstance -Database "Cobalt_Payments" -Query $PaymentAppAuditQueryCount -Credential $LonCreds
        if ($LonPAAEntry){$LondonPAA = $LonPAAEntry.count}else{$LondonPAA = "0"}
        #$UxbRefundEntry = Invoke-Sqlcmd -ServerInstance $UxbInstance -Database "Ringgo" -Query $RefundQueryCount -Credential $UxbCreds
        #if ($UxbRefundEntry){$UxbridgeRefund = $UxbRefundEntry.count}else{$UxbridgeRefund = "0"}
        $LonRefundEntry = Invoke-Sqlcmd -ServerInstance $LonInstance -Database "Ringgo" -Query $RefundQueryCount -Credential $LonCreds
        if ($LonRefundEntry){$LondonRefund = $LonRefundEntry.count}else{$LondonRefund = "0"}
        $PCNPaymentEntry = Invoke-Sqlcmd -ServerInstance $LonInstance -Database "PCN" -Query $PCNQueryCount -Credential $LonCreds
        if ($PCNPaymentEntry){$PCNPayment = $PCNPaymentEntry.count}else{$PCNPayment = "0"}
        $PCNRefundEntry = Invoke-Sqlcmd -ServerInstance $LonInstance -Database "PCN" -Query $PCNRefundQueryCount -Credential $LonCreds
        if ($PCNRefundEntry){$PCNRefund = $PCNRefundEntry.count}else{$PCNRefund = "0"}

        ### Build report from results
        [PSCustomObject]@{
            Fref = $Fref
            #"Uxb Sessions" = $UxbridgeSess
            "Sessions" = $LondonSess
            #"Uxb PaymentAppAudit" = $UxbridgePAA
            "PaymentAppAudit" = $LondonPAA
            #"Uxb Refunds" = $UxbridgeRefund
            "Refunds" = $LondonRefund
            "PCN Payments" = $PCNPayment
            "PCN Refunds" = $PCNRefund
        }

        ### Update progress counter variable for Write-Progress
        $Progress ++
    }
    ### Final update to progress bar
    Write-Progress -Activity "Querying Frefs:" -Completed -Id 0


    ### If the user clicks on a result and presses "Ok", store the selection in a variable
    $UserSelections = $Report | Out-Gridview -PassThru -Title "Report"

    ### Reset progress counter variable for use with Write-Progress (the progress bar)
    $Progress = 0

    ### Loop through each of the selections and throw out a gridview showing all the entries for the selected Fref in each table it appears
    Foreach ($UserSelection in $UserSelections){
        
        ### Create progress bar - helps with when there are lots of Frefs so that it doesn't appear to have frozen
        Write-Progress -Activity "Querying Frefs:" -CurrentOperation ("Fref: " + $Fref) -PercentComplete ($Progress/$Frefs.count*100) -Id 1

        ### Strip Fref out of Userselection for use with new queries
        $FREF = $UserSelection.Fref

        ### New queries so that the $FREF variable can be updated with the user selection - this also needs to be replaced by functions
        $SessionsQuery = "SELECT TOP (1000) *
            FROM [Ringgo].[dbo].[Sessions] WITH (nolock)
            WHERE Fref = " + "'$FREF'" + "
            AND ((session_quantity = 1 AND primaryAuditLink = '') OR (primaryAuditLink > ''))"

        $PaymentAppAuditQuery = "SELECT TOP (1000) *
            FROM [Cobalt_Payments].[dbo].[PaymentAppAudit] WITH (nolock)
            WHERE Fref = " + "'$FREF'"

        $RefundQuery = "SELECT TOP (1000) *
            FROM [Ringgo].[dbo].[Refunds] WITH (nolock)
            WHERE Fref = " + "'$FREF'"

        $PCNQuery = "SELECT TOP (1000) *
            FROM [PCN].[dbo].[Payment] WITH (nolock)
            WHERE Fref = " + "'$FREF'"

        $PCNRefundQuery = "SELECT TOP (1000) *
            FROM [PCN].[dbo].[Refunds] WITH (nolock)
            WHERE Fref = " + "'$FREF'"

        #Invoke-Sqlcmd -ServerInstance $UxbInstance -Database "Ringgo" -Query $SessionsQuery -Credential $UxbCreds | Out-GridView -Title "Uxb Sessions: $Fref"
        #Invoke-Sqlcmd -ServerInstance $UxbInstance -Database "Cobalt_Payments" -Query $PaymentAppAuditQuery -Credential $UxbCreds | Out-Gridview -Title "Uxb Payment App Audit: $Fref"
        Invoke-Sqlcmd -ServerInstance $LonInstance -Database "Ringgo" -Query $SessionsQuery -Credential $LonCreds | Out-GridView -Title "Lon Sessions: $Fref"
        Invoke-Sqlcmd -ServerInstance $LonInstance -Database "Cobalt_Payments" -Query $PaymentAppAuditQuery -Credential $LonCreds | Out-Gridview -Title "Lon Payment App Audit: $Fref"
        #Invoke-Sqlcmd -ServerInstance $UxbInstance -Database "Ringgo" -Query $RefundQuery -Credential $UxbCreds | Out-GridView -Title "Lon Refunds: $Fref"
        Invoke-Sqlcmd -ServerInstance $LonInstance -Database "Ringgo" -Query $RefundQuery -Credential $LonCreds | Out-Gridview -Title "Uxb Refunds: $Fref"
        Invoke-Sqlcmd -ServerInstance $LonInstance -Database "PCN" -Query $PCNQuery -Credential $LonCreds | Out-Gridview -Title "Uxb PCN Payments: $Fref"
        Invoke-Sqlcmd -ServerInstance $LonInstance -Database "PCN" -Query $PCNRefundQuery -Credential $LonCreds | Out-GridView -Title "Uxb PCN Refunds: $Fref"
        
        ### Update progress counter variable for Write-Progress
        $Progress ++
    }
    Write-Progress -Activity "Querying Frefs:" -Completed -Id 1

    If ($ParentFrefs){
        $WebBasketDecision = Invoke-MultiSelectForm -Objects "Yes", "No" -Title "Please select an option" -Message "Basket Frefs detected. Search for missing sessions?"
        If ($WebBasketDecision -like "Yes"){
            Foreach ($ParentFref in $ParentFrefs){

                Write-Host "Querying PaymentAppAudit table for $ParentFref"
                ### Search PaymentAppAudit tables for the web basket Fref and pull out the BasketID
                $Query = "SELECT TOP (1000) *
                    FROM [Cobalt_Payments].[dbo].[PaymentAppAudit] WITH (nolock)
                    WHERE Fref = " + "'$ParentFref'"

                $QueryResults = @()
                #$QueryResults += Invoke-Sqlcmd -ServerInstance $UxbInstance -Database "Cobalt_Payments" -Query $Query -Credential $UxbCreds
                $QueryResults += Invoke-Sqlcmd -ServerInstance $LonInstance -Database "Cobalt_Payments" -Query $Query -Credential $LonCreds
                $BasketID = $QueryResults.AddData -split " " | Select -Index 9

                Write-Host "Querying PaymentAppAudit for multiple web basket Frefs - this can take a while (potentially multiple minutes)"

                ### Search PaymentAppAudit tables for any payments that match the BasketID and pull out the Frefs
                $BasketIDQuery = "SELECT TOP (1000) *
                    FROM [Cobalt_Payments].[dbo].[PaymentAppAudit] WITH (nolock)
                    WHERE Fref = " + "'$ParentFref'" + "
                    or AddData LIKE " + "'%$BasketID%'" + "
                    AND NOT rc = 433"

                $BasketIDQueryResults = @()
                #$BasketIDQueryResults += Invoke-Sqlcmd -ServerInstance $UxbInstance -Database "Cobalt_Payments" -Query $BasketIDQuery -Credential $UxbCreds
                $BasketIDQueryResults += Invoke-Sqlcmd -ServerInstance $LonInstance -Database "Cobalt_Payments" -Query $BasketIDQuery -Credential $LonCreds
                $Frefs = $BasketIDQueryResults.Fref

                ### Search the WebBasketItems tables for any items the BasketIDs and pull out the SessionAuditLinks
                $WebBasketQuery = "SELECT TOP (1000) *
                    FROM [Ringgo].[dbo].[WebBasketItems] WITH (nolock)
                    WHERE BasketID LIKE " + "'$BasketID'" + "
                    AND IsRemoved = 0"

                $WebBasketQueryResults = @()
                #$WebBasketQueryResults = Invoke-Sqlcmd -ServerInstance $UxbInstance -Database "Ringgo" -Query $WebBasketQuery -Credential $UxbCreds
                $WebBasketQueryResults = Invoke-Sqlcmd -ServerInstance $LonInstance -Database "Ringgo" -Query $WebBasketQuery -Credential $LonCreds

                $SessionAuditlinks = $WebBasketQueryResults.reference

                ### Format the Frefs and SessionAuditlinks and create SQL query to search the sessions table for them all at once
                $FrefsSQLString = "(" + (($Frefs |% {"'$_'"}) -Join(",")) + ")"
                $SALSQLString = "(" + (($SessionAuditlinks |% {"'$_'"}) -Join(",")) + ")"
                $SessionsBasketQuery = "SELECT TOP (1000) *
                    FROM [Ringgo].[dbo].[Sessions] WITH (nolock)
                    WHERE Fref IN " + $FrefsSQLString + "
                    OR Session_Auditlink IN " + $SALSQLString

                ### Search both DBs and report back with any Frefs that are missing from either site's session table
                #$UxbSessionsBasketResults = Invoke-Sqlcmd -ServerInstance $UxbInstance -Database "Ringgo" -Query $SessionsBasketQuery -Credential $UxbCreds
                $LonSessionsBasketResults = Invoke-Sqlcmd -ServerInstance $LonInstance -Database "Ringgo" -Query $SessionsBasketQuery -Credential $LonCreds

                "For $ParentFref" + ":"
                $BasketReport = @()
                Foreach ($Fref in $Frefs){
        
                    #If ($Fref -notin $UxbSessionsBasketResults.Fref){$BasketReport += "    $Fref missing from Uxb Sessions table"}
                    If ($Fref -notin $LonSessionsBasketResults.Fref){$BasketReport += "    $Fref missing from Lon Sessions table"}
                }
                If (!$BasketReport){"    No missing sessions"}Else{$BasketReport}
            }       
        }
    }

    ### Ask the user if they would like to reload from the data file and start again - if they select "No", the script will end and the Powershell session will close
    $Continue = Invoke-MultiSelectForm -Objects "Yes", "No" -Title "Please select an option" -Message "Reload and continue?"
    Clear
}While(
    $Continue -like "Yes"
)
