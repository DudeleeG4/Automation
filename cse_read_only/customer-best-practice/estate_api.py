#!/usr/bin/env python3

import requests
from requests.packages.urllib3.exceptions import InsecureRequestWarning
requests.packages.urllib3.disable_warnings(InsecureRequestWarning)
import json
import logging
import codecs

from config import *

class Estate_Api:

    def __init__(self, estate_api_combined_password):

        self.estate_api_combined_password = estate_api_combined_password
        # from https://sint.il3management.local/cmdb/ci/5449
        # internal-users-combined password
        self.raw_company_list = None
        self.company_list = None

    def get_all_accounts_from_company_id(self, il, company_id):
        """
        :param il: "2" or "3"
        :param company_id: "1"
        :return: ["47","48","251"]
        """
        account_list = []
        company_list = self.get_customers_and_accounts()
        for company in company_list:
            if company[0] == il:  # if in the correct domain assured/elevated
                if company[2] == company_id:  # if we have the right company_id
                    for account in company[3]:
                        account_list.append(account[1])
        if account_list:
            return account_list
        else:
            msg = "Error! (gaafci 1) no get_all_accounts_from_company_id il" \
                  + il + " org:" + company_id
            logging.warning(msg)

    def get_company_from_id(self, il, company_id):
        company_name = None
        company_list = self.get_customers_and_accounts()
        for company in company_list:
            if company[0] == il:  # if in the correct domain assured/elevated
                if company[2] == company_id:  # if we have the right company_id
                    company_name = company[1]
        if company_name:
            return company_name
        else:
            logging.warning("Error! (gcid 1) no get_company_from_id il"
                            + il + " org:" + company_id)

    def get_account_from_id(self, il, company_id, account_id):
        account_name = None
        company_list = self.get_customers_and_accounts()
        for company in company_list:
            if company[0] == il:  # if in the correct domain assured/elevated
                if company[2] == company_id:  # if we have the right company_id
                    for account in company[3]:
                        if account[1] == account_id:  # the right account_id
                            account_name = account[0]
        if account_name:
            return account_name
        else:
            logging.warning("Error! (gaid 1) no get_company_from_id il"
                            + il + " org:" + company_id + "." + account_id)

    def get_customers_and_accounts(self):
        if not self.company_list:
            self.raw_company_list, self.company_list = \
                self._get_company_and_account_data()
        return self.company_list

    def get_json_customers_and_accounts(self):
        if not self.raw_company_list:
            self.raw_company_list, self.company_list = \
                self._get_company_and_account_data()
        return self.raw_company_list

    def _get_company_and_account_data(self):
        """
        :return: (json, list of tuple)
                    tuple is (il, company_name, company_id, [account_ids])
                    tuple is ("2", "Skyscape", "1", [("prod account","1"),
                                ("test account","47")])
        """
        if read_from_estate_api or self.estate_api_combined_password:
            api_key = self.estate_api_combined_password
            print("Connecting to Estate API")
            data = [
                ('grant_type', 'client_credentials'),
                ('client_id', 'internal-users'),
                ('client_secret', api_key),
            ]
            response = requests.post(
                estate_api_get_token_url, data=data, verify=False).content
            token = ""
            try:
                token = json.loads(response)['access_token']
            except KeyError:
                print("Incorrect password!")
                exit()
    
            print("Fetching data from Estate API")
    
            headers = {
                'Authorization': 'Bearer ' + token,
            }
            query_instruction = """{
            companies {
                name
                domainIdentifier
                securityDomain
                accounts {
                    name
                    domainIdentifier
                }
            }
        }"""
            data = [
                ('query', query_instruction),
            ]
            response = requests.post(estate_api_url, headers=headers, data=data,
                                     verify=False).content
            json_data = json.loads(response)['data']['companies']
            with open('estate_api_json_data', 'w') as outfile:
                json.dump(json_data, outfile)
        else:
            with open('estate_api_json_data') as f:
                json_data = json.load(f)

        company_list = []
        for company in json_data:
            account_ids = []
            for account in company['accounts']:
                element = (account['name'], str(account['domainIdentifier']))
                account_ids.append(element)
            if account_ids:
                il = None
                if company['securityDomain'] == "ASSURED":
                    il = "2"
                if company['securityDomain'] == "ELEVATED":
                    il = "3"
                element = (il, company['name'],
                           str(company['domainIdentifier']), account_ids)
                company_list.append(element)

        print("Results Collected")
        return json_data, company_list
