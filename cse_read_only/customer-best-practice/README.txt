version: 1.1

https://confluence.il2management.local/display/BAC/Customer+Best+Practice+Scripts

The above contains all information for installing and using

To run the tests, simply run tests.py with python.
If the tests all pass, it will show "Success"

The test coverage is only partial, so running the full script with real-data is a good idea, and verifying the output.
There are tests in place to prevent the wrong data entering the reports as a result of a code change.

To add more pages to the report, take a look at process_accounts() in run.py
Inside this function, there is a call to a function to create each page in the report, and then the summary page at the
end. Copy one of the already existing code blocks, such as # Out of date VSEs results, which is coppied below...

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


Replace the variable names, file names, and then write a new function to replace the get_ood_vshield_edge_results() in
parse_results_folder_file.py. This will be the function that gets the data for the page.
Make tests for your new function!
