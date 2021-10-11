#!/usr/bin/env python3

import argparse
import csv
import json

import requests

"""
Grabs the sint account summary data from admin_api via the admin portal.
Converts this data which is retrieved from the API as a JSON format and converts 
it to a data structure that is writable to a csv file.
"""


def authenticate(user, password, url):
    """Authenticates against the admin_api for the admin portal.

    Args:
        user: (str) The account to access the API.
        password: (str) The password to authenticate the account.
        url: (url) The URL that points to the domain on which the admin API is
              on. e.g. https://admin.portal.staging.internal.local

    Returns:
        s: (session object)

    """
    requests.packages.urllib3.disable_warnings()
    url += '/admin_api/authenticate'
    s = requests.Session()
    s.headers.update({'Content-Type': 'application/x-www-form-urlencoded'})
    authentication = s.post(url, data={'username': user, 'password': password},
                            verify=False)
    print(authentication.text)
    return s


def get_json(session, url):
    """Queries the admin api on the admin portal at the contacts_summary
    endpoint.  It then formats the data returned into a json format.

    Args:
        session: (Requests session object)
        url: (str) The URL to to find the contact's summary endpoint.

    Returns:
        formatted_data: (list) A list of dict values via the Json module.
    """

    summary_url = url + '/admin_api/contacts_summary'

    data = session.get(summary_url)
    formatted_data = json.loads(data.text)
    return formatted_data


def write_to_csv(formatted_data, file_name):
    """Writes a json formatted object to a csv file.

    Args:
        file_name : (str) The name of the file that will be produced.
        formatted_data: (list) A list of dict values via the Json module.

    Returns:
        Nothing
    """
    try:
        with open(file_name, "w", newline="") as outfile:
            writer = csv.writer(outfile)
            # Write Header Row
            writer.writerow(["account_id", "account", "company",
                             "primary_business_contact",
                             "secondary_business_contact",
                             "primary_billing_contact",
                             "secondary_billing_contact",
                             "primary_technical_contact",
                             "secondary_technical_contact"])

            # Write Data to CSV File
            for item in formatted_data[1:]:
                writer.writerow([item["account_id"], item["account"],
                                 item["company"],
                                 item["primary_business_contact"],
                                 item["secondary_business_contact"],
                                 item["primary_billing_contact"],
                                 item["secondary_billing_contact"],
                                 item["primary_technical_contact"],
                                 item["secondary_technical_contact"]])

    except FileNotFoundError as exception:
        print("ERROR: File not Found.")
        print(exception)


def parse_args():
    """parse command-line arguments

    Returns:
        Arguments as Namespace Objects.
    """
    parser = argparse.ArgumentParser(description='Credentials and Endpoint for '
                                                 'authenticating against the '
                                                 'Admin API')
    parser.add_argument('-u', '--user', type=str, required=True,
                        help='Admin_API User.')
    parser.add_argument('-p', '--password', type=str, required=True,
                        help='Admin API Password for User')
    parser.add_argument('--url', type=str, required=True,
                        help='URL to specify the Endpoint to authenticate '
                             'against.')
    parser.add_argument('-o', '--output_file', type=str, required=True,
                        help='The name of the output file with the extension.')
    args = parser.parse_args()
    return args


if __name__ == '__main__':
    ARGS = parse_args()
    SESSION = authenticate(ARGS.user, ARGS.password, ARGS.url)
    JSON_DATA = get_json(SESSION, ARGS.url)
    write_to_csv(JSON_DATA, ARGS.output_file)
