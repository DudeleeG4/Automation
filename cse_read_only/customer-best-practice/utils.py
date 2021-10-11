#!/usr/bin/env python3
import logging
import csv
import codecs
import os

load_csv_cache = {}

class Filesystem_Cache:

    def __init__(self, not_in_cache_warning=True):
        self.locations = []
        self.data = {}
        self.not_in_cache_warning = not_in_cache_warning

    def force_load_csv_to_cache(self, filename, load_from_results_folder=True):
        try:
            if load_from_results_folder:
                location = os.path.join("results", filename)
            else:
                location = filename
            f = codecs.open(location, encoding='utf-8')
            csv_data = list(csv.reader(f))
            self.locations.append(location)
            self.data[hash(location)] = csv_data
        except IOError:
            logging.warning("Error: (lc 1) IOError : " + filename)
            logging.warning("Perhaps a mis-spelled filename?")
            logging.warning("Can't continue, exiting")
            exit()
        except Exception as e:
            logging.warning("Error: (lc 2) Could not load_csv : " + filename)
            logging.warning("Can't continue, exiting")
            logging.warning(e)
            exit()

    def load_csv(self, filename, load_from_results_folder=True):
        try:
            if load_from_results_folder:
                location = os.path.join("results", filename)
            else:
                location = filename

            if location in self.locations:
                return self.data[hash(location)]
            else:
                # get from filesystem
                f = open(location, 'r')
                csv_data = list(csv.reader(f))
                if self.not_in_cache_warning:
                    logging.warning(
                        location + " was not in cache, fetched manualy")
                # dont save to cache, as this is a shared object when using
                # multithreadding. changing this in multithreadding could cause
                # incorrect keys and a corrupted datastructure
                key = "key" + str(len(self.locations))
                self.data[key] = csv_data
            return csv_data
        except IOError:
            logging.warning("Error: (lc 1) IOError : " + filename)
            logging.warning("Perhaps a mis-spelled filename?")
            logging.warning("Can't continue, exiting")
            exit()
        except Exception as e:
            logging.warning("Error: (lc 2) Could not load_csv : " + filename)
            logging.warning(str(e))
            logging.warning("Can't continue, exiting")
            exit()


def get_pairs_from_list(data):
    no_of_items = len(data)
    if no_of_items > 2:
        return [[data[0], data[1]]] + get_pairs_from_list(data[2:])
    if no_of_items == 2:
        return [[data[0], data[1]]]
    if no_of_items == 1:
        return [[data[0], None]]
    else:
        return None


def check_lists_have_equal_lengths(lists, filename="", name=""):
    row_length = None  # Unknown at the moment
    for row in lists:
        if row_length is None:
            row_length = len(row)
        else:
            if not len(row) == row_length:
                msg = filename + " " + name + " has error! Not all rows" \
                                              " in the page have the same" \
                                              " length! The table may" \
                                              " have been rendered" \
                                              " incorrectly!"
                logging.warning(msg)


def convert_version_to_int(version):
    """
    :param version: string, '3.4.5' or '3.2.1-anything'
            # version must have 3 parts separated by a full stop, and be at
            # the start of the string
    :return: 345 or 321
    """
    if version == '':
        return 0
    try:
        new_version_string = ""
        new_version = version.split("-")[0]  # clip everything after '-'
        if len(new_version.split(".")) >= 3:  # if version has 3 pats
            for subversion in new_version.split("."):
                new_subversion_string = subversion
                while not len(new_subversion_string) >= 3:
                    new_subversion_string = "0" + new_subversion_string
                new_version_string += new_subversion_string
            return int(new_version_string)

        msg = "(cvti 1) Could not convert_version_to_int " + str(version)
        logging.info(msg)
    except ValueError:
        msg = "(cvti 2) Could not convert_version_to_int " + str(version)
        logging.info(msg)
    except Exception as e:
        msg = "(cvti 3) Could not convert_version_to_int " + str(version)
        logging.info(msg)
        logging.info(e)
    return None


def get_company_or_account_id_from_name(name):
    """
    :param name: String, 'Skyscape (1)'
    :return: "1"
    """
    name = name.split(" ")
    if len(name) > 1:
        name = name[-1:][0]
        if '(' in name and ')' in name:
            name = name.replace('(', "").replace(')', "")
            return name
        msg = "(gcoaifn 1) Could not get_company_or_account_id_from_name:" + \
              str(name)
        logging.info(msg)
    return None


def check_orgstring_ok(org):
    org = org.split("-")
    valid_string = True
    for element in org[:3]:
        try:
            int(element)
        except ValueError:
            valid_string = False
    if not (len(org) in [3, 4]):  # proving that the org id is full
        valid_string = False
    return valid_string


def get_company_id_from_org(org):
    """
    :param org: String, '1-47-321-d23a4bc'
    :return: "1"
    """
    if check_orgstring_ok(org):
        rcn = org.split("-")
        return rcn[0]
    elif org in ["Org", "OrgNumber", "Catalogue", "vm", ""]:
        pass
    else:
        msg = "gcifo 1: Could not get_company_id_from_org:" + str(org)
        logging.info(msg)
    return None


def get_account_id_from_org(org):
    """
    :param org: String, '1-47-321-d23a4bc'
    :return: "1"
    """
    if check_orgstring_ok(org):
        rcn = org.split("-")
        return rcn[1]
    elif org in ["Org", "OrgNumber", "Catalogue", "vm", ""]:
        pass
    else:
        msg = "gaifo 1: Could not get_account_id_from_org:" + str(org)
        logging.info(msg)
    return None
