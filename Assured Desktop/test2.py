
import atexit
import csv
import math
import os
import ssl
from datetime import datetime, timedelta

from pyVim import connect
from pyVmomi import vmodl, vim
import pyVmomi


def connect_viserver(vCenter, user, password):
    """
    Creates a service_instance connection to a vcenter using
    the pyVmomi API.

    connect.SmartConnect can raise a socket.error, that the calling
    code is responsible for catching.

    NOTE: Py3 and >=2.7.9 will need an SSLContext with CERT_NONE here.

    :param host: hostname of vCenter to connect to
    :param user: username to connect with
    :param password: password to connect with
    :param port: port number for connection (defaults to 443)
    :return: a service_instance, as returned by pyVim.connect.SmartConnect
    """
    #ssl_context = ssl.SSLContext(ssl.PROTOCOL_TLSv1)
    #ssl_context.verify_mode = ssl.CERT_NONE

    service_instance = connect.SmartConnect(host=vCenter, port=int(443),
                                            user=user, pwd=password,
                                          #  sslContext=ssl_context
                                            )

    atexit.register(connect.Disconnect, service_instance)

    return service_instance

def Get_View(service_instance, viewtypes):
    """
    Find the number of VMs on this vCenter

    :param service_instance:
    :return: (int) the number of VMs found
    """
    # Seems to return the same as service_instance.content
    content = service_instance.RetrieveContent()

    container = content.rootFolder  # starting point to look into
    recursive = True  # whether we should look into it recursively

    # see http://pubs.vmware.com/vsphere-60/index.jsp#com.vmware.wssdk.apiref.doc/vim.view.ContainerView.html
    container_view = content.viewManager.CreateContainerView(container, viewtypes, recursive)
    children = container_view.view

    return children

vCenterServer = connect_viserver("vcw00005i2","sudandrews","Noalcslat1")
VMs = Get_View(vCenterServer, [vim.VirtualMachine])
#print dir(VMs[1])
report = []
for i,VM in enumerate(VMs):
    Name = VM.name#, VM.resourcePool
    for storage in VM.storage.perDatastoreUsage:
        datastore_id = storage.datastore
        DSs = Get_View(vCenterServer, [vim.Datastore])
        #report.append({"VM" : Name, "Datastore" : "", "Used Space in GB" : ""})
        for datastore in DSs:
            dir(datastore)
            if datastore == datastore_id :
                DS = datastore.name
                
        
        Used_Space_GB = storage.committed/1024.0/1024.0/1024.0
        report.append({"VM" : Name, "Datastore" : DS, "Used Space in GB" : Used_Space_GB})
    print ".",
            

    if i > 99 :
        break
print ""

today = datetime.now().strftime('%Y-%m-%d')

filename = os.path.join(os.path.expanduser('~'),  "Desktop", "VMs-Storage-Report-%s.csv" % (today))
#file = open('VMs-Storage-Report-%s.csv' % (today), "wb")
# use a context manager to automatically close the file after we've finished.
print filename
with open(filename, "w") as file:
    headers = "VM,Datastore,Used Space in GB\n"

    file.write(headers)
    for item in report:
        file.write("%s, %s, %s\n" % (item["VM"], item["Datastore"], item["Used Space in GB"]))

    #print "%r" % file.closed

#print "%r" % file.closed
