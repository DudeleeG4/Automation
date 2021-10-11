#!/usr/bin/env python3


from parse_results_folder_file import get_shapshot_results, \
    get_ood_vshield_edge_results, get_disabled_firewalls_results, \
    get_old_vmware_tools_results, get_contact_details_results
from utils import get_company_or_account_id_from_name, check_orgstring_ok, \
    convert_version_to_int, get_account_id_from_org, \
    get_company_id_from_org, \
    Filesystem_Cache, get_pairs_from_list
from estate_api import Estate_Api
from config import *

test_live_api = True


def test_load_csv():
    data = fs.load_csv("test_data/test.csv", load_from_results_folder=False)
    assert (data is not None) and (data is not False)


def test_get_company_or_account_id_from_name():
    num1 = get_company_or_account_id_from_name("Skyscape (1)")
    num2 = get_company_or_account_id_from_name("Company 41 (42)")
    num3 = get_company_or_account_id_from_name("Not valid")
    num4 = get_company_or_account_id_from_name("Company (Sales) (3)")
    assert num1 == "1"
    assert num2 == "42"
    assert num3 is None
    assert num4 == "3"


def test_get_company_id_from_org():
    id1 = get_company_id_from_org("1-47-321-d23a4bc")  # good
    id2 = get_company_id_from_org("23-456-876")  # good
    id3 = get_company_id_from_org("not-a-valid-thing")  # bad
    id4 = get_company_id_from_org("not-valid-thing")  # bad
    id5 = get_company_id_from_org("not-ok-23")  # bad
    id6 = get_company_id_from_org("23-34-bad")  # bad
    assert id1 == "1"
    assert id2 == "23"
    assert id3 is id4 is id5 is id6 is None


def test_get_account_id_from_org():
    id1 = get_account_id_from_org("1-47-321-d23a4bc")  # good
    id2 = get_account_id_from_org("23-456-876")  # good
    id3 = get_account_id_from_org("not-a-valid-thing")  # bad
    id4 = get_account_id_from_org("not-valid-thing")  # bad
    id5 = get_account_id_from_org("not-ok-23")  # bad
    id6 = get_account_id_from_org("23-34-bad")  # bad
    assert id1 == "47"
    assert id2 == "456"
    assert id3 is id4 is id5 is id6 is None


def test_convert_version_to_int():
    ver0 = convert_version_to_int("6.2.7-crap")
    ver1 = convert_version_to_int("6.2.7")
    ver2 = convert_version_to_int("5.5.4")
    ver3 = convert_version_to_int("not.a.version")
    ver4 = convert_version_to_int("5.5")
    ver5 = convert_version_to_int("12.2.7")
    ver6 = convert_version_to_int("6.2.731")
    assert ver0 == 6002007
    assert ver1 == 6002007
    assert ver2 == 5005004
    assert ver3 is None
    assert ver4 is None
    assert ver5 == 12002007
    assert ver6 == 6002731


def test_check_orgstring_ok():
    org1 = check_orgstring_ok("1-47-321-d23a4bc")  # good
    org2 = check_orgstring_ok("23-456-876")  # good
    org3 = check_orgstring_ok("not-a-valid-thing")  # bad
    org4 = check_orgstring_ok("not-valid-thing")  # bad
    org5 = check_orgstring_ok("not-ok-23")  # bad
    org6 = check_orgstring_ok("23-34-bad")  # bad
    assert org1 is org2 is True
    assert org3 is org4 is org5 is org6 is False


def test_get_company_from_id():
    com = estate_api.get_company_from_id("2", "1")
    assert com == "Skyscape (1)"


def test_get_account_from_id():
    acc = estate_api.get_account_from_id("2", "1", "47")
    assert acc == "Skyscape Technology (47)"


def test_get_all_accounts_from_company_id():
    acc = sorted(estate_api.get_all_accounts_from_company_id("2", "1"))
    exp = sorted(['729', '730', '732', '728', '109', '314', '311', '330', '1',
                  '397', '8', '734', '401', '398', '395', '721', '622', '56',
                  '643', '892', '475', '48', '366', '572', '32', '82', '613',
                  '47', '497', '422', '778', '530'])
    assert acc == exp


def test_get_shapshot_results_contain_only_company_data():
    csv_data = fs.load_csv("test_data/snap2_example.csv",
                           load_from_results_folder=False)
    items_not_related_to_company_and_account = [
        'vm4', 'vm5',
        'vapp4', 'vapp5',
        'vdc4', 'vdc5',
        'snapshot name4', 'snapshot name5',
        'description4', 'description5',
        'Not Skyscape (2)', 'Not Skyscape Team 1 (48)', 'Other Company (3)',
        'Some other team (399)',
    ]
    acc = get_shapshot_results("2", "1", ["48", "47", "56"], estate_api,
                               csv_data=csv_data)

    # key row, data row x4, account summary x3, company summary
    assert len(acc) == 9

    # check that no other company data appears in this report
    for row in acc:
        for element in row:
            for item in items_not_related_to_company_and_account:
                assert not item == element


def test_get_shapshot_results_contain_only_account_data():
    csv_data = fs.load_csv("test_data/snap2_example.csv",
                           load_from_results_folder=False)
    items_not_related_to_company_and_account = [
        'vm2', 'vm3', 'vm4', 'vm5',
        'vapp2', 'vapp3', 'vapp4', 'vapp5',
        'vdc2', 'vdc3', 'vdc4', 'vdc5',
        'snapshot name2', 'snapshot name3', 'snapshot name4', 'snapshot name5',
        'description2', 'description3', 'description4', 'description5',
        'Not Skyscape (2)', 'Not Skyscape Team 1 (48)', 'Other Company (3)',
        'Some other team (399)',
    ]
    acc = get_shapshot_results("2", "1", ["48"], estate_api, csv_data=csv_data)

    # key row, data row x2, account summary, company summary
    assert len(acc) == 5

    # check that no other company data appears in this report
    for row in acc:
        for element in row:
            for item in items_not_related_to_company_and_account:
                assert not item == element


def test_get_shapshot_results_maths_totals():
    csv_data = fs.load_csv("test_data/snap2_example.csv",
                           load_from_results_folder=False)
    acc = get_shapshot_results("2", "1", ["48", "47"], estate_api,
                               csv_data=csv_data)

    # key row, data row x3, account summary x2, company summary
    assert len(acc) == 7

    # no of vms
    assert acc[3][2] == 2
    assert acc[5][2] == 1
    assert acc[6][2] == 3
    # size in GB
    assert acc[3][6] == 116
    assert acc[5][6] == 99
    assert acc[6][6] == 215


def test_get_ood_vshield_edge_results_no_of_edges_correct():
    # Testing where all edges are out of date!
    csv_data = fs.load_csv("test_data/vse2_example2.csv",
                           load_from_results_folder=False)
    acc = get_ood_vshield_edge_results("2", "1", ["48", "47"], estate_api,
                                       csv_data=csv_data)
    # key row, data row x3, account summary x2, company summary
    assert len(acc) == 7

    acc = get_ood_vshield_edge_results("2", "1", ["47"], estate_api,
                                       csv_data=csv_data)
    # key row, data row x2, account summary, company summary
    assert len(acc) == 5

    csv_data = fs.load_csv("test_data/vse2_example.csv",
                           load_from_results_folder=False)

    # Testing where all only 1 edge is out of date!
    acc = get_ood_vshield_edge_results("2", "1", ["48", "47"], estate_api,
                                       csv_data=csv_data)
    # key row, data row, account summary, company summary
    assert len(acc) == 4


def test_get_ood_vshield_edge_results_contain_only_company_data():
    # Testing where all firewalls are disabled!
    csv_data = fs.load_csv("test_data/vse2_example2.csv",
                           load_from_results_folder=False)
    acc = get_ood_vshield_edge_results("2", "1", ["48", "47"], estate_api,
                                         csv_data=csv_data)
    items_not_related_to_company_and_account = [
        'nft0015ai2 - 1', 'nft002a8i2-1',
        'Adapt C (IL2-PROD-STANDARD)',
        'MDS - Portal Development (IL2-DEVTEST-BASIC)',
    ]
    # check that no other company data appears in this report
    for row in acc:
        for element in row:
            for item in items_not_related_to_company_and_account:
                assert not item == element


def test_get_ood_vshield_edge_results_contain_only_account_data():
    # Testing where all firewalls are disabled!
    csv_data = fs.load_csv("test_data/vse2_example2.csv",
                           load_from_results_folder=False)
    acc = get_ood_vshield_edge_results("2", "1", ["48"], estate_api,
                                         csv_data=csv_data)
    items_not_related_to_company_and_account = [
        'nft0015ai2 - 1', 'nft002a8i2-1',
        'Adapt C (IL2-PROD-STANDARD)',
        'MDS - Portal Development (IL2-DEVTEST-BASIC)',
        'DWP-CDS-Connected (IL2-PROD-STANDARD)', 'nft0023fi2-3',
        'Management1 (IL2-PROD-STANDARD)', 'nft002b4i2-23'
    ]
    # check that no other company data appears in this report
    for row in acc:
        for element in row:
            for item in items_not_related_to_company_and_account:
                assert not item == element


def test_get_disabled_firewalls_results_no_of_edges_correct():
    # Testing where all firewalls are disabled!
    csv_data = fs.load_csv("test_data/vse2_example2.csv",
                           load_from_results_folder=False)
    acc = get_disabled_firewalls_results("2", "1", ["48", "47"], estate_api,
                                         csv_data=csv_data)
    # key row, data row x3, account summary x2, company summary
    assert len(acc) == 7

    acc = get_disabled_firewalls_results("2", "1", ["47"], estate_api,
                                         csv_data=csv_data)
    # key row, data row x2, account summary, company summary
    assert len(acc) == 5

    csv_data = fs.load_csv("test_data/vse2_example.csv",
                           load_from_results_folder=False)

    # Testing where all only 1 firewall is disabled!
    acc = get_disabled_firewalls_results("2", "1", ["48", "47"], estate_api,
                                         csv_data=csv_data)
    # key row, data row, account summary, company summary
    assert len(acc) == 4


def test_get_disabled_firewalls_results_contain_only_company_data():
    # Testing where all firewalls are disabled!
    csv_data = fs.load_csv("test_data/vse2_example2.csv",
                           load_from_results_folder=False)
    acc = get_disabled_firewalls_results("2", "1", ["48", "47"], estate_api,
                                         csv_data=csv_data)
    items_not_related_to_company_and_account = [
        'nft0015ai2 - 1', 'nft002a8i2-1',
        'Adapt C (IL2-PROD-STANDARD)',
        'MDS - Portal Development (IL2-DEVTEST-BASIC)',
    ]
    # check that no other company data appears in this report
    for row in acc:
        for element in row:
            for item in items_not_related_to_company_and_account:
                assert not item == element


def test_get_disabled_firewalls_results_contain_only_account_data():
    # Testing where all firewalls are disabled!
    csv_data = fs.load_csv("test_data/vse2_example2.csv",
                           load_from_results_folder=False)
    acc = get_disabled_firewalls_results("2", "1", ["48"], estate_api,
                                         csv_data=csv_data)
    items_not_related_to_company_and_account = [
        'nft0015ai2 - 1', 'nft002a8i2-1',
        'Adapt C (IL2-PROD-STANDARD)',
        'MDS - Portal Development (IL2-DEVTEST-BASIC)',
        'DWP-CDS-Connected (IL2-PROD-STANDARD)', 'nft0023fi2-3',
        'Management1 (IL2-PROD-STANDARD)', 'nft002b4i2-23'
    ]
    # check that no other company data appears in this report
    for row in acc:
        for element in row:
            for item in items_not_related_to_company_and_account:
                assert not item == element


def test_get_old_vmware_tools_results_contain_only_company_data():
    csv_data = fs.load_csv("test_data/tool2_example.csv",
                           load_from_results_folder=False)
    items_not_related_to_company_and_account = [
        'vm4', 'vm5',
        'vapp4', 'vapp5',
        'vdc4', 'vdc5',
        'Not Skyscape (2)', 'Not Technology (47)', 'Another Company (3)',
        'Something Else (399)',
    ]
    acc = get_old_vmware_tools_results("2", "1", ["48", "47", "56"], estate_api,
                                       csv_data)

    # key row, data row x3, account summary x2, company summary
    assert len(acc) == 7

    # check that no other company data appears in this report
    for row in acc:
        for element in row:
            for item in items_not_related_to_company_and_account:
                assert not item == element


def test_get_old_vmware_tools_results_contain_only_account_data():
    csv_data = fs.load_csv("test_data/tool2_example.csv",
                           load_from_results_folder=False)
    items_not_related_to_company_and_account = [
        'vm3', 'vm4', 'vm5',
        'vapp3', 'vapp4', 'vapp5',
        'vdc3', 'vdc4', 'vdc5',
        'Not Skyscape (2)', 'Not Technology (47)', 'Another Company (3)',
        'Something Else (399)',
    ]
    acc = get_old_vmware_tools_results("2", "1", ["47"], estate_api, csv_data)

    # key row, data row x2, account summary, company summary
    assert len(acc) == 5

    # check that no other company data appears in this report
    for row in acc:
        for element in row:
            for item in items_not_related_to_company_and_account:
                assert not item == element


def test_get_old_vmware_tools_results_no_of_vms_correct():
    # Testing where all vmtools are out of date or not installed!
    csv_data = fs.load_csv("test_data/tool2_example.csv",
                           load_from_results_folder=False)

    acc = get_old_vmware_tools_results("2", "1", ["48"], estate_api, csv_data)
    # key row, data row, account summary, company summary
    assert len(acc) == 4

    acc = get_old_vmware_tools_results("2", "1", ["48", "47"], estate_api,
                                       csv_data)
    # key row, data row x3, account summary x2, company summary
    assert len(acc) == 7

    # Testing where only 1 are out of date!
    csv_data = fs.load_csv("test_data/tool2_example2.csv",
                           load_from_results_folder=False)

    acc = get_old_vmware_tools_results("2", "1", ["47"], estate_api, csv_data)
    # key row, data row x1, account summary, company summary
    assert len(acc) == 4

    acc = get_old_vmware_tools_results("2", "1", ["48", "47"], estate_api,
                                       csv_data)
    # key row, data row x1, account summary x1, company summary
    assert len(acc) == 4


def test_get_pairs_from_list():
    dataset1 = [1, 2, 3, 4]
    dataset2 = [3, 4]
    dataset3 = [1, 2, 3]
    expected1 = [[1, 2], [3, 4]]
    expected2 = [[3, 4]]
    expected3 = [[1, 2], [3, None]]
    actual1 = get_pairs_from_list(dataset1)
    actual2 = get_pairs_from_list(dataset2)
    actual3 = get_pairs_from_list(dataset3)
    assert actual1 == expected1
    assert actual2 == expected2
    assert actual3 == expected3


def test_get_contact_details_results():
    csv_data = fs.load_csv("test_data/contact_details2_example.csv",
                           load_from_results_folder=False)
    actual = get_contact_details_results(["47", "48"], csv_data)
    expected = [[[sum_pg_contact_details_message, 'DEV'],
                [pri_bui_contact, 'name1'],
                [sec_bui_contact, 'name2'],
                [pri_bil_contact, 'name3'],
                [sec_bil_contact, 'name4'],
                [pri_tec_contact, 'name5'],
                [sec_tec_contact, 'name6']],
                [[sum_pg_contact_details_message, 'Test'],
                [pri_bui_contact, 'name7'],
                [sec_bui_contact, 'name8'],
                [pri_bil_contact, 'name9'],
                [sec_bil_contact, 'name10'],
                [pri_tec_contact, 'name11'],
                [sec_tec_contact, 'name12']]]
    assert expected == actual


fs = Filesystem_Cache(not_in_cache_warning=False)
test_load_csv()
test_get_company_or_account_id_from_name()
test_get_company_id_from_org()
test_get_account_id_from_org()
test_convert_version_to_int()
test_check_orgstring_ok()
if test_live_api:
    estate_api = Estate_Api(input("oss00001_combined_password: "))
    test_get_company_from_id()
    test_get_account_from_id()
    test_get_all_accounts_from_company_id()
    test_get_shapshot_results_contain_only_company_data()
    test_get_shapshot_results_contain_only_account_data()
    test_get_shapshot_results_maths_totals()
    test_get_ood_vshield_edge_results_no_of_edges_correct()
    test_get_ood_vshield_edge_results_contain_only_company_data()
    test_get_ood_vshield_edge_results_contain_only_account_data()
    test_get_disabled_firewalls_results_no_of_edges_correct()
    test_get_disabled_firewalls_results_contain_only_company_data()
    test_get_disabled_firewalls_results_contain_only_account_data()
    test_get_old_vmware_tools_results_contain_only_company_data()
    test_get_old_vmware_tools_results_contain_only_account_data()
    test_get_old_vmware_tools_results_no_of_vms_correct()
test_get_contact_details_results()
test_get_pairs_from_list()
print("Success")
a = input("Done:")
