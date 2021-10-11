#!/usr/bin/env python3

import logging
from config import *
from utils import get_company_id_from_org, get_account_id_from_org, \
    convert_version_to_int


def get_shapshot_results(il, company, accounts, estate_api, csv_data):
    """
    :param il: string: "2" or "3"
    :param company: stirng '27'
    :param accounts: list of string ['321','543']
    :param estate_api: Estate_Api Object
    :param csv_data: 2d list of csv data
    :return: 2d array for the workbook
    """
    if csv_data:
        results = []
        titles = [("Company", "Account", "VM", "OrgVDC", "vAPP", "Created",
                  "Size (GB)")]
        no_of_issues = 0
        size_of_snapshots_in_company = 0
        for account in accounts:
            size_of_snapshots_in_account = 0
            account_results = []
            for row in csv_data:
                org = row[10]
                if get_company_id_from_org(org) == company and \
                        get_account_id_from_org(org) == account:
                    #  account must match if account is specified
                    size = int(row[6].split(".")[0])  # round down to 1GB
                    result = (row[0], row[1], row[4], row[2], row[3],
                              row[5], size)
                    account_results.append(result)
                    no_of_issues += 1
                    size_of_snapshots_in_company += size
                    size_of_snapshots_in_account += size

            results += account_results

            # make total row for the account
            if account_results or show_account_summary_if_account_is_empty:
                account_name = \
                    estate_api.get_account_from_id(il, company, account)
                row = [(totals_msg + account_name,
                        nos_msg, len(account_results),
                        '', '',
                        sos_msg, size_of_snapshots_in_account)]
                results += row

        # make final totals rows
        company_name = estate_api.get_company_from_id(il, company)
        row = [(totals_msg + company_name,
                nos_msg, no_of_issues,
                '', '',
                sos_msg, size_of_snapshots_in_company)]
        results += row

        results = titles + results
        return results


def get_ood_vshield_edge_results(il, company, accounts, estate_api, csv_data):
    """
    :param il: string: "2" or "3"
    :param company: stirng '27'
    :param accounts: list of string ['321','543']
    :param estate_api: Estate_Api Object
    :param csv_data: 2d list of csv data
    :return: 2d array for the workbook
    """
    if csv_data:
        results = []
        titles = [("Company", "Account", "vShield Edge Name", "OrgVDC",
                   "Version")]
        no_of_issues = 0
        company_name = estate_api.get_company_from_id(il, company)
        for account in accounts:
            account_name = estate_api.get_account_from_id(il, company, account)
            account_results = []
            for row in csv_data:
                org = row[15]
                if get_company_id_from_org(org) == company and \
                        account == get_account_id_from_org(org):

                    vse_version_limit = convert_version_to_int(
                        oldest_acceptable_vshield_edge_version)
                    vse_version = convert_version_to_int(row[23])
                    if vse_version_limit > vse_version:  # VSE out of date
                        result = (company_name, account_name,
                                  row[0], row[17], row[23])
                        account_results.append(result)
                        no_of_issues += 1

            results += account_results

            if account_results or show_account_summary_if_account_is_empty:
                # make total row for the account
                row = [(totals_msg + account_name,
                        noood_vse_msg, len(account_results),
                        '', '')]
                results += row

        # make final totals rows
        row = [(totals_msg + company_name,
                noood_vse_msg, no_of_issues,
                '', '')]
        results += row

        results = titles + results
        return results


def get_disabled_firewalls_results(il, company, accounts, estate_api, csv_data):
    """
    :param il: string: "2" or "3"
    :param company: stirng '27'
    :param accounts: list of string ['321','543']
    :param estate_api: Estate_Api Object
    :param csv_data: 2d list of csv data
    :return: 2d array for the workbook
    """
    if csv_data:
        results = []
        titles = [("Company", "Account", "OrgVDC", "vShield Edge Name")]
        no_of_issues = 0
        company_name = estate_api.get_company_from_id(il, company)
        for account in accounts:
            account_results = []
            for row in csv_data:
                org = row[15]
                if get_company_id_from_org(org) == company and \
                        account == get_account_id_from_org(org):
                    if row[3] in ["FALSE", "false"]:  # Firewall is disabled
                        account_name = \
                            estate_api.get_account_from_id(il, company, account)
                        result = (company_name, account_name,
                                  row[17], row[0])
                        account_results.append(result)
                        no_of_issues += 1

            results += account_results

            if account_results or show_account_summary_if_account_is_empty:
                # make total row for the account
                account_name = estate_api.get_account_from_id(il, company,
                                                              account)
                row = [(totals_msg + account_name,
                        nodf_msg, len(account_results),
                        '')]
                results += row

        # make final totals rows
        row = [(totals_msg + company_name,
                nodf_msg, no_of_issues,
                '')]
        results += row

        results = titles + results
        return results


def get_old_vmware_tools_results(il, company, accounts, estate_api, csv_data):
    """
    :param il: string: "2" or "3"
    :param company: stirng '27'
    :param accounts: list of string ['321','543']
    :param estate_api: Estate_Api Object
    :param csv_data: 2d list of csv data
    :return: 2d array for the workbook
    """
    if csv_data:
        results = []
        titles = [("Company", "Account", "OrgVDC", "vApp", "VM", "Version")]
        com_no_of_ood_issues = 0
        com_no_of_no_install_issues = 0
        for account in accounts:
            acc_no_of_ood_issues = 0
            acc_no_of_no_install_issues = 0
            account_results = []
            for row in csv_data:
                org = row[7]
                if get_company_id_from_org(org) == company and \
                        account == get_account_id_from_org(org):
                    vmwaretools_version_limit = convert_version_to_int(
                        oldest_acceptable_vmwaretools_version)
                    vmwaretools_version = convert_version_to_int(row[6])
                    vmwaretools_is_up_to_date = \
                        vmwaretools_version_limit <= vmwaretools_version
                    vmwaretools_is_installed = \
                        not (row[5] == 'toolsNotInstalled')
                    if not vmwaretools_is_up_to_date or \
                            not vmwaretools_is_installed:
                        if vmwaretools_is_installed:
                            vmwaretools_version_message = row[6]
                            com_no_of_ood_issues += 1
                            acc_no_of_ood_issues += 1
                        else:
                            vmwaretools_version_message = "None"
                            com_no_of_no_install_issues += 1
                            acc_no_of_no_install_issues += 1

                        result = (row[0], row[1], row[2],
                                  row[3], row[4],
                                  vmwaretools_version_message)
                        account_results.append(result)

            results += account_results

            if account_results or show_account_summary_if_account_is_empty:
                # make total row for the account
                account_name = estate_api.get_account_from_id(il, company,
                                                              account)
                row = [(totals_msg + account_name,
                        nooodvmti_msg, acc_no_of_ood_issues,
                        nonvmti_msg, acc_no_of_no_install_issues,
                        '')]
                results += row

        # make final totals rows
        company_name = estate_api.get_company_from_id(il, company)
        row = [(totals_msg + company_name,
                nooodvmti_msg, com_no_of_ood_issues,
                nonvmti_msg, com_no_of_no_install_issues,
                '')]
        results += row

        results = titles + results
        return results


def get_contact_details_results(accounts, csv_data):
    """
    :param accounts: list of string ['321','543']
    :param csv_data: 2d list of csv data
    :return: 2d array for the workbook
    """
    if 'email' in csv_data[0]:
        # Checking we have the summary file not the details file from sint
        logging.warning("Error: (gcd 1)")
        logging.warning("Incorrect customer contacts file from SINT")
        logging.warning("Can't continue, exiting")
        exit()
    else:
        contact_details_results = []
        for account in accounts:
            account_table = None
            for row in csv_data:
                if row[0] == account:
                    account_table = [[sum_pg_contact_details_message, row[1]]]
                    account_table += [[pri_bui_contact, (row[3])]]
                    account_table += [[sec_bui_contact, (row[4])]]
                    account_table += [[pri_bil_contact, (row[5])]]
                    account_table += [[sec_bil_contact, (row[6])]]
                    account_table += [[pri_tec_contact, (row[7])]]
                    account_table += [[sec_tec_contact, (row[8])]]
            if account_table:
                contact_details_results.append(account_table)
        return contact_details_results
