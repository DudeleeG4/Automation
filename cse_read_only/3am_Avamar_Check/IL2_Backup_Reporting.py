#!/usr/bin/env python3
# Avamar Reporting Script - IL2 Variation.

import cmdb_api
import getpass
import re
import paramiko
import datetime
import time
import csv

local_path = "/" # Change path to shared area. Needs to be changed accordingly. (Where report will be generated and temp files it needs).
report_type = input("Report type (Full/Failed/Running): ")
name = input("SU Username:")
user = (str(name) + "@il2management.local")
pwd = getpass.getpass("Password")
d42 = cmdb_api.CmdbApi(user, pwd, "https://device42.combined.local")    # https://cmdb.combined.local New domain name to be added when the D42 migration happens.
d42.disable_insecure_request_warnings()
login_creds = []
ipdict = {}

failed_servers = [] # These variables can be printed out for debugging/Logging.
Failed_Err_List = [] # These variables can be printed out for debugging/Logging.
Failed_conn_List = [] # These variables can be printed out for debugging/Logging.
User_Input_Error = [] # These variables can be printed out for debugging/Logging.


def get_creds():
    '''
    Pulling the credentials and login information to log into the vav's/bck's from Device42. Sorts through older login info an the newer format (X4 Loops).
    '''
    print("Discovering Servers")
    
    global hold_time
    global avamars
    global avamars_bck
    global login_creds
    global Failed_Creds_List
    global correct_domain

    Failed_Creds_List = []
    avamars = d42.search_for_cis('vav')
    avamars_bck = d42.search_for_cis('bck')
    avamars_bck_old = d42.search_for_cis('bck')
    avamars_bck_A = d42.search_for_cis('bck')
       
    for bcka in avamars_bck_A:
        details1 = d42.get_ci_by_name(bcka)     
        ip_details = details1['ip_addresses']
        
        try:
            ipDict = ip_details[0]
        except:
            failed_servers.append(bcka)
            pass
        
        try:
            passw = d42.get_cred_for_ci_by_label(bcka, 'admin')
        except:
            failed_servers.append(bcka)
            pass
        
        items = details1['aliases'][0]        
        item1 = items.replace('-management','')                     # These lines can be removed
        item2 = item1.replace(' - Management','')                   # when domain aliases are 
        correct_domain = item2.replace(' - management','')          # corrected on some servers...         
        
        if passw:
            login_creds.append([correct_domain, passw['username'], passw['password'], bcka])   
        else:
            Failed_Creds_List.append(bcka)
            pass    
        
    for bck in avamars_bck:
        details1 = d42.get_ci_by_name(bck)     
        ip_details = details1['ip_addresses']
        
        try:
            ipDict = ip_details[0]
        except:
            failed_servers.append(bck)
            pass        
        try:
            passw = d42.get_cred_for_ci_by_label(bck, 'Avamar OS Admin User')
        except:
            failed_servers.append(bck)
            pass
            
        items = details1['aliases'][0]        
        item1 = items.replace('-management','')                     # These lines can be removed
        item2 = item1.replace(' - Management','')                   # when domain aliases are 
        correct_domain = item2.replace(' - management','')          # corrected on some servers in D42...         
        
        if passw:
            login_creds.append([correct_domain, passw['username'], passw['password'], bck])   
        else:
            Failed_Creds_List.append(bck)
            pass
    
    for bckoa in avamars_bck_old:
        details1 = d42.get_ci_by_name(bckoa)     
        ip_details = details1['ip_addresses']
        
        try:
            ipDict = ip_details[0]
        except:
            failed_servers.append(bckoa)
            pass       
        try:
            passw = d42.get_cred_for_ci_by_label(bckoa, 'OS Admin')
        except:
            failed_servers.append(bckoa)
            pass
        
        items = details1['aliases'][0]        
        item1 = items.replace('-management','')                     # These lines can be removed
        item2 = item1.replace(' - Management','')                   # when domain aliases are 
        correct_domain = item2.replace(' - management','')          # corrected on some servers in D42...         
        
        if passw:
            login_creds.append([correct_domain, passw['username'], passw['password'], bckoa])
        else:
            Failed_Creds_List.append(bckoa)
            pass
    
    
    for avamar in avamars:
        details1 = d42.get_ci_by_name(avamar)     
        ip_details = details1['ip_addresses']
        
        try:
            ipDict = ip_details[0]
        except:
            Failed_Creds_List.append(avamar)
            pass

        passw = d42.get_cred_for_ci_by_label(avamar, 'OS Admin')
        
        if passw == 'None':
            try:
                passw = d42.get_cred_for_ci_by_label(avamar, 'Admin')
            except:
                passw = d42.get_cred_for_ci_by_label(avamar, 'Avamar OS Admin User')
            try:
                passw = d42.get_cred_for_ci_by_label(avamar, 'admin')
            except:
                Failed_Creds_List.append(avamar)

        correct_domain = details1['aliases'][0]
 
        if passw:
            login_creds.append([correct_domain, passw['username'], passw['password'], avamar])
        else:
            Failed_Creds_List.append(avamar)    
            pass

    for cred in login_creds:
        remote_conn = None
        print("\n" + cred[3])
        execute(cred)
    
    
def parse(cred): 
    '''
    The section will read the now local output files and scan each of the lines to find the work Failed. It will then be added to a Report
    including the server it is located on. It will vary in output depending on the desired report type (Full/Failed), full being a large
    mccli status report for each server on the status of all VM backups. aswell as a smaller report which sifts through the previous 
    report and will display only Failed VM backups.
    '''
    print("Creating .CSV")
    List = open(local_path + "output.txt").readlines()       

    if report_type == 'Failed':
        for row in List:
            if re.search('Failed', row):       
                Failed_Err_List.append(row)
        with open(local_path + 'il2_Fail_check.csv', 'a') as myfile:
            writer = csv.writer(myfile)
            writer.writerow([cred[3]])   
        with open(local_path + 'il2_Fail_check.csv', 'a') as myfile:
            writer = csv.writer(myfile, delimiter='\n')
            writer.writerow(Failed_Err_List)
            Failed_Err_List.clear() 
                
    elif report_type == 'Full':
        with open(local_path + 'il2_Full_check.csv', 'a') as myfile:
            writer = csv.writer(myfile)
            writer.writerow([cred[3]]) 
        with open(local_path + 'il2_Full_check.csv', 'a') as myfile:
            writer = csv.writer(myfile, delimiter='\n')
            writer.writerow(List)
    
    elif report_type == 'Running':
        with open(local_path + 'il2_Running_check.csv', 'a') as myfile:
            writer = csv.writer(myfile)
            writer.writerow([cred[3]]) 
        with open(local_path + 'il2_Running_check.csv', 'a') as myfile:
            writer = csv.writer(myfile, delimiter='\n')
            writer.writerow(List)
    else:
        User_Input_Error.append(cred)
        pass
        
    
def ftp(cred):
    '''
    The section will collect the .txt output files generated on each of the servers and bring them back to the jumpbox.
    Using Paramiko as the library to ssh to the boxes to perform sftp. te older output file will be stored on each of 
    the servers until the report is generated on the next day inwhich it will overwrite the file of the previous day.
    The file can also be generated by the report tool if it accidently deleted.
    '''
    print("Creating FTP Session")
    files = 'output.txt'
    remote_images_path = '/data01/home/admin/'
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(cred[0], username=cred[1], password=cred[2], look_for_keys=False, allow_agent=False)
    sftp = ssh.open_sftp()
    file_remote = str(remote_images_path) + str(files)
    file_local = str(local_path) + str(files)
    sftp.get(file_remote, file_local)
    sftp.close()
    ssh.close()
    parse(cred)


def execute(cred):
    '''
    The section runs the commands to pipe the output of the command into a .txt for the script to pick up later.
    Some servers have inconsitant domain names where -management is somtimes required in it's FQDN, these exceptions
    will try all found servers with this extension to double check it is a different domain.
    '''
    print("Trying SSH Command")
    remote_conn_pre = paramiko.SSHClient()
    remote_conn_pre.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    if report_type == 'Running':
        try:
            remote_conn_pre = paramiko.SSHClient()
            remote_conn_pre.set_missing_host_key_policy(paramiko.AutoAddPolicy()) 
            remote_conn_pre.connect(cred[0], username=cred[1], password=cred[2], port=22, look_for_keys=False, allow_agent=False)
            remote_conn = remote_conn_pre.invoke_shell()
            remote_conn.send("mccli activity show | head -n 3 && mccli activity show | grep Running | head -n 5 > output.txt\n")  # Command can altered here to vary it's output in the future if required (GREP/Time/Specifics).
            time.sleep(10)
            ftp(cred)
            exit()

        except:
            try:
                remote_conn_pre = paramiko.SSHClient()            
                cred[0] = str(cred[3]) + '.il2management.local'       
                remote_conn_pre = paramiko.SSHClient()
                remote_conn_pre.set_missing_host_key_policy(paramiko.AutoAddPolicy())           
                remote_conn_pre.connect(cred[0], username=cred[1], password=cred[2], look_for_keys=False, allow_agent=False)
                remote_conn = remote_conn_pre.invoke_shell()
                remote_conn.send("mccli activity show | head -n 3 && mccli activity show | grep Running | head -n 5 > output.txt\n")  # Command can altered here to vary it's output in the future if required (GREP/Time/Specifics).
                time.sleep(10)
                ftp(cred)
                exit()
            except:
                Failed_conn_List.append(cred)
    else:
        try:
            remote_conn_pre = paramiko.SSHClient()
            remote_conn_pre.set_missing_host_key_policy(paramiko.AutoAddPolicy()) 
            remote_conn_pre.connect(cred[0], username=cred[1], password=cred[2], port=22, look_for_keys=False, allow_agent=False)
            remote_conn = remote_conn_pre.invoke_shell()
            remote_conn.send("mccli activity show > output.txt\n")  # Command can altered here to vary it's output in the future if required (GREP/Time/Specifics).
            time.sleep(10)
            ftp(cred)
            exit()

        except:
            try:
                remote_conn_pre = paramiko.SSHClient()            
                cred[0] = str(cred[3]) + '.il2management.local'       
                remote_conn_pre = paramiko.SSHClient()
                remote_conn_pre.set_missing_host_key_policy(paramiko.AutoAddPolicy())           
                remote_conn_pre.connect(cred[0], username=cred[1], password=cred[2], look_for_keys=False, allow_agent=False)
                remote_conn = remote_conn_pre.invoke_shell()
                remote_conn.send("mccli activity show > output.txt\n")  # Command can altered here to vary it's output in the future if required (GREP/Time/Specifics).
                time.sleep(10)
                ftp(cred)
                exit()
            except:
                Failed_conn_List.append(cred)
        
    
get_creds()