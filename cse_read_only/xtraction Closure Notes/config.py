fields = ['Triage information was correct',
          'Technology',
          'Confirmed Fault Region/Zone',
          'Related Internal/3rd Party Ticket',
          'Failure Location',
          'Cause of Failure',]
# Order Does not matter, feel free to add more here whenever you need

ticket_statuses = ['Closed','Resolved'] # These are the statuses found in the xtraction reports in Column A
xtraction_filename = "xtraction_assured.csv" # change this to xtraction_elevated.csv for elevated
remove_engineer_name = False

### CONSTANTS
# Powershell Code changes will be required if this is to change
ticket_list_filename = "ticketlist.csv"
sql_results_location = "results/"+"INC"
