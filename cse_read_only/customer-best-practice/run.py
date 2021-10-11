#!/usr/bin/env python3
import logging
import os
import xlsxwriter
import datetime
import argparse

from config import *
from parse_results_folder_file import get_shapshot_results, \
    get_ood_vshield_edge_results, get_disabled_firewalls_results, \
    get_old_vmware_tools_results, get_contact_details_results
from estate_api import Estate_Api
from utils import Filesystem_Cache, check_lists_have_equal_lengths, \
    get_pairs_from_list

from _multithread import para


def write_workbook(company_name, list_of_pages, location=""):
    """
    :param company_name: String, Rolls Royce
    :param list_of_pages:  a list of tuples (String, 2d-list)
            each 2d list is a grid of data for each workbook page
    :param location: the folder in which to write the report
    :return:
    """
    filename = report_name + company_name + ".xlsx"

    if not os.path.exists(location):
        os.makedirs(location)

    workbook = xlsxwriter.Workbook(os.path.join(location, filename))

    for item in list_of_pages:
        name = item[0]
        page = item[1]

        # check all rows have the same number of columns
        check_lists_have_equal_lengths(page, filename=filename, name=name)

        worksheet = workbook.add_worksheet(name)

        starting_cell_y = 1
        table_size_string = 'A' + \
                            str(starting_cell_y) + \
                            ':' + \
                            chr(64 + len(page[0])) + \
                            str(len(page) + starting_cell_y - 1)

        columns_list = []
        for element in page[0]:
            columns_list.append({'header': element})

        cell_format = workbook.add_format()
        cell_format.set_bold(True)
        cell_format.set_bg_color('black')
        cell_format.set_font_color('white')

        for i, row in enumerate(page[1:]):
            worksheet.write_row('A' + str(i + starting_cell_y + 1), list(row))
            if totals_msg in row[0] or sum_pg_contact_details_message in row[0]:
                worksheet.write_row('A' + str(i + starting_cell_y + 1),
                                    list(row), cell_format)
        worksheet.add_table(table_size_string, {'columns': columns_list})

        rotated = zip(*page[::-1])  # rotate the array, so its a list of columns

        # for each column, find the longest string
        column_lengths = []
        for column in rotated:
            longest_cell_data = 0
            for cell in column:
                cell = str(cell)
                if longest_cell_data < len(cell):
                    longest_cell_data = len(cell)
            column_lengths.append(longest_cell_data)

        # adjust the column widths for the sheet
        for i, length in enumerate(column_lengths):
            if length > max_cell_width:
                length = max_cell_width
            worksheet.set_column(i, i, length)

    workbook.close()


def process_accounts(il, customer_name, company_id, account_ids,
                     estate_api, fs_cache, verbose=False):
    """
    :param il: "2" or "3"
    :param customer_name: "Skyscape"
    :param company_id: "23"
    :param account_ids: ["37","399","404"]
    :param estate_api: Estate_Api Object
    :param fs_cache: Filesystem_Cache
    :param verbose: boolean
    :return:
    """
    workbook_pages = []
    summary_page_info = []

    # Out of date VSEs results
    if report_out_of_date_vse:
        if verbose:
            print("Working on: Out of date VSEs results: " + customer_name)
        if il == "2":
            csv_data = fs_cache.load_csv(vse_filename_il2)
            domain = assured_string
        else:
            domain = elevated_string
            csv_data = fs_cache.load_csv(vse_filename_il3)
        ood_vse_results = get_ood_vshield_edge_results(
            il, company_id, account_ids, estate_api, csv_data)
        if ood_vse_results:
            summary_page_info += ood_vse_results[-1:]
            workbook_page = (ood_vse_report_name + " - " + domain,
                             ood_vse_results)
            workbook_pages.append(workbook_page)

    # Disabled firewall results
    if report_disabled_firewalls:
        if verbose:
            print("Working on: Disabled firewall results: " + customer_name)
        if il == "2":
            csv_data = fs_cache.load_csv(vse_filename_il2)
            domain = assured_string
        else:
            csv_data = fs_cache.load_csv(vse_filename_il3)
            domain = elevated_string
        no_fw_results = get_disabled_firewalls_results(
            il, company_id, account_ids, estate_api, csv_data)
        if no_fw_results:
            summary_page_info += no_fw_results[-1:]
            workbook_page = (disabled_firewalls_report_name + " - " +
                             domain, no_fw_results)
            workbook_pages.append(workbook_page)

    # Out of date snapshot results
    if report_out_of_date_snapshots:
        if verbose:
            print("Working on: Out of date snapshot results: " + customer_name)
        if il == "2":
            csv_data = fs_cache.load_csv(snapshot_filename_il2)
            domain = assured_string
        else:
            csv_data = fs_cache.load_csv(snapshot_filename_il3)
            domain = elevated_string
        snapshot_results = get_shapshot_results(
            il, company_id, account_ids, estate_api, csv_data)
        if snapshot_results:
            summary_page_info += snapshot_results[-1:]
            workbook_page = (ood_shapshot_report_name + " - " + domain,
                             snapshot_results)
            workbook_pages.append(workbook_page)

    # Out of date vmware tools results
    if report_out_of_date_vmwaretools:
        if verbose:
            print("Working on: Out of date vmware tools results: " +
                  customer_name)
        if il == "2":
            csv_data = fs_cache.load_csv(vmwaretools_filename_il2)
            domain = assured_string
        else:
            csv_data = fs_cache.load_csv(vmwaretools_filename_il3)
            domain = elevated_string
        vmwaretools_results = get_old_vmware_tools_results(
            il, company_id, account_ids, estate_api, csv_data)
        if vmwaretools_results:
            summary_page_info += vmwaretools_results[-1:]
            workbook_page = (vmware_tools_versions_report_name + " - " + domain,
                             vmwaretools_results)
            workbook_pages.append(workbook_page)

    # Write the summary page
    if make_summary_page:
        summary_headder = [['Summary for ' + customer_name, 'Total']]

        #  make summary rows
        new_summary_rows = []
        for row in summary_page_info:
            new_row = []
            cliped_row = row[1:]  # remove the totals_msg from each summary
            for item in cliped_row:
                if not (item in ['', None, ' ']):
                    new_row.append(item)
            new_summary_rows += get_pairs_from_list(new_row)

        summary_page = summary_headder + new_summary_rows
        summary_page += [['', '']]  # add a blank line

        if il == "2":
            csv_data = fs_cache.load_csv(account_contact_summary_il2)
        else:
            csv_data = fs_cache.load_csv(account_contact_summary_il3)

        account_details = get_contact_details_results(account_ids, csv_data)
        if account_details:
            for row in account_details:
                summary_page += row

        workbook_page = ("Summary", summary_page)
        workbook_pages = [workbook_page] + workbook_pages

    # Write all the information we collected to the workbook
    if workbook_pages:
        if il == "2":
            domain = assured_string
        else:
            domain = elevated_string
        date = datetime.datetime.now().strftime("%d-%m-%Y")
        customer_name = customer_name.replace(':', '').replace('/', '')
        location = os.path.join(reports_folder, date, domain, customer_name)
        filename = customer_name
        if len(account_ids) == 1:
            filename += " - " + estate_api.get_account_from_id(il, company_id,
                                                               account_ids[0])
            filename = filename.replace(':', '').replace('/', '')
        print(filename)
        try:
            write_workbook(filename, workbook_pages, location=location)
        except OSError:
            logging.info("Could not write file, possibly due to oversize"
                         "file name, or unsave filesystem characters in the "
                         "filename. Attempting different filename...")
            try:
                filename = str(company_id)
                if len(account_ids) == 1:
                    filename = filename + '-' + str(account_ids[0])
                write_workbook(filename, workbook_pages, location=location)
            except Exception as e:
                logging.warning(
                    "Error: (psc 1) Could not write workbook : " + filename)
                logging.warning(e)
    else:
        msg = "psc: Unable to get any reports for " \
              "il" + il + " company:" + company_id
        logging.info(msg)


def process_company(data):
    """
    :param data: data = (company, estate_api, fs_cache)
    :return:
    """
    company, estate_api, fs_cache = data
    print("Working on reports for " + company[1])
    accounts = estate_api.get_all_accounts_from_company_id(company[0],
                                                           company[2])
    if create_company_reports:
        process_accounts(company[0], company[1], company[2],
                         accounts, estate_api, fs_cache)
    if create_account_reports:
        for account in accounts:
            process_accounts(company[0], company[1], company[2],
                             [account], estate_api, fs_cache)


def parse_args():
    parser = argparse.ArgumentParser(description='Customer Best Practice')

    parser.add_argument(
        '--oss_pass', help='oss00001i3 internal combined password', required=False)

    return parser.parse_args()


def run():
    ARGS = parse_args()
    if ARGS.oss_pass is None:
        estate_api = Estate_Api(input("oss00001_combined_password: "))
    elif ARGS.oss_pass == "NOT_SPECIFY":
        print("You must specify the oss00001 combined password")
        exit()
    else:
        estate_api = Estate_Api(ARGS.oss_pass)
    companies = estate_api.get_customers_and_accounts()

    # Load all files
    fs_cache = Filesystem_Cache(not_in_cache_warning=not_in_cache_warning)
    fs_cache.force_load_csv_to_cache(snapshot_filename_il2)
    fs_cache.force_load_csv_to_cache(snapshot_filename_il3)
    fs_cache.force_load_csv_to_cache(vse_filename_il2)
    fs_cache.force_load_csv_to_cache(vse_filename_il3)
    fs_cache.force_load_csv_to_cache(vmwaretools_filename_il2)
    fs_cache.force_load_csv_to_cache(vmwaretools_filename_il3)
    fs_cache.force_load_csv_to_cache(account_contact_summary_il2)
    fs_cache.force_load_csv_to_cache(account_contact_summary_il3)

    import time
    st = time.time()

    dataset = []
    for company in companies:
        data = (company, estate_api, fs_cache)
        dataset.append(data)
        # this puts the data we would normaly send to process_company() in one
        # value, so that we can pass it as the input for para()
        # if we werent using para(), we could just process everything in a
        # single thread as below

        # process_company(data)

    # instead, we can just run the following line, and execute in parallel
    para(process_company, dataset, max_concurrent_threads=no_of_process_threads)
    et = time.time()
    print("Time taken to generate " + str(len(companies)) + " reports is " +
          str(et-st) + " seconds")


if __name__ == "__main__":
    run()

# TODO
# cost of snapshots
