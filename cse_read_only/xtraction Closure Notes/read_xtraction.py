from config import ticket_statuses, ticket_list_filename, xtraction_filename
from fs_functions import *

def get_ticket_numbers(xtraction_csv):
    ticket_numbers = []
    for line in xtraction_csv.split("\n"):
        if line.split(",")[0] in ticket_statuses:
            # Line is a ticket line (rather than a title or something)
            ticket_number = line.split(",")[1]
            try:
                # can we convert the ticket number to an integer?
                ticket_number = str(int(ticket_number))
            except:
                # not a number! errorr!!!!!
                print(str(ticket_number))
                print("Script or xtraction csv broken!")
                print("Will not continue")
                exit()
            ticket_numbers.append(ticket_number)
    return ticket_numbers

xtraction_csv = readfile(xtraction_filename)
ticket_numbers = get_ticket_numbers(xtraction_csv)
writefile(ticket_list_filename,",".join(ticket_numbers))
