# Please see the confluence guide for more explanation of this file
# https://confluence.il2management.local/display/PV2/Customer+Best+Practice+Scripts

# report logic/threshold variables, Can be changed
oldest_acceptable_vshield_edge_version = "6.2.7"
oldest_acceptable_vmwaretools_version = "10.0.0"

# report display page, titles and message variables, Can be changed
report_out_of_date_vse = True
ood_vse_report_name = "Old vShield Edges"
noood_vse_msg = 'Number of Out of date vShield Edges'

report_disabled_firewalls = True
disabled_firewalls_report_name = "Firewalls Disabled"
nodf_msg = 'Number of Disabled Firewalls'

report_out_of_date_snapshots = True
ood_shapshot_report_name = "Old Snapshots"
nos_msg = 'Number of Snapshots'
sos_msg = 'Size of Snapshots (GB)'

report_out_of_date_vmwaretools = True
vmware_tools_versions_report_name = "VMware tools"
nooodvmti_msg = 'Number of Out of Date vmtools installs'
nonvmti_msg = 'Number of No vmtools installs'

sum_pg_contact_details_message = 'Contact Details for '
pri_bui_contact = "Primary Business Contact"
sec_bui_contact = "Secondary Business Contact"
pri_bil_contact = "Primary Billing Contact"
sec_bil_contact = "Secondary Billing Contact"
pri_tec_contact = "Primary Technical Contact"
sec_tec_contact = "Secondary Technical Contact"

make_summary_page = True
create_company_reports = True
create_account_reports = True
totals_msg = "Totals for: "
assured_string = "Assured"
elevated_string = "Elevated"
report_name = "Customer Good Practice Report - "
max_cell_width = 50
show_account_summary_if_account_is_empty = False

# other variables, Can be changed
not_in_cache_warning = False
no_of_process_threads = 4  # WHOLE NUMBERS ONLY (1 per logical core recommended)

# filesystem variables, Can be changed
snapshot_filename_il2 = 'snap2.csv'
snapshot_filename_il3 = 'snap3.csv'
vse_filename_il2 = 'vse2.csv'
vse_filename_il3 = 'vse3.csv'
vmwaretools_filename_il2 = 'tool2.csv'
vmwaretools_filename_il3 = 'tool3.csv'
account_contact_summary_il2 = 'contact_details2.csv'
account_contact_summary_il3 = 'contact_details3.csv'
reports_folder = "reports"

# other variables, CHANGE ONLY WHEN NEEDED
estate_api_get_token_url = 'https://keycloak.combined.local/auth/realms/estate-api/protocol/openid-connect/token'
estate_api_url = 'https://estate-api.combined.local/api'
read_from_estate_api = True
