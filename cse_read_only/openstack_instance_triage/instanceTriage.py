#!/usr/bin/env python
import re
import click
import openstack


@click.command()
@click.option('--instance_id', default="", help="the ID for the instance youre looking to run the triage script against.")
@click.option('--with_router_info', is_flag=True, default=False, help="boolean, if true then the script returns further networking information.")
def main(instance_id, with_router_info=False):
    """ Triage script for OpenStack.

    Args:
        instance_id (str): the ID for the instance youre looking to run the triage script against.
        with_router_info (bool) : with_router_info

    Returns:
        None

    """

    while (not (re.match('^(.{8})(-)(.{4})(-)(.{4})(-)(.{4})(-)(.{12})$', instance_id))):
        print("A valid instance ID like 'a1b2c3d4-a1b2-a1b2-a1b2-a1b2c3d4e5f6' is required")
        instance_id = str(input("Enter instance ID: "))

    connections = [conn_cor5(), conn_frn6(), conn_cor5_2()] # future pods need to be added here.
    vol_ids = []

    for conn in connections:
        try:
            server = conn.compute.get_server(instance_id)
        except:
            continue #If it's not in the current region; keep moving.
        
        if server:
            for vol in conn.compute.volume_attachments(instance_id):
                vol_ids.append(vol['id'])
            for project in conn.identity.projects():
                if server['location']['project']['id'] == project['id']:
                    instance_project = project

        print_server_info(server,instance_project)
        print_server_network_info(conn,server,with_router_info)
        print_server_volume_info(conn,server,vol_ids)


def conn_cor5():
    return openstack.connect(cloud='cor00005')


def conn_frn6():
    return openstack.connect(cloud='frn00006')


def conn_cor5_2():
    return openstack.connect(cloud='cor000052')


def print_server_info(server,instance_project):
    print("===INSTANCE INFORMATION===")
    print("LOCATION: " + server['location']['cloud'])
    print("PROJECT NAME: " + instance_project['name'])
    print("PROJECT ID: " + server['location']['project']['id'])
    print("\nINSTANCE NAME: " + server['name'])
    print("INSTANCE ID: " + server['id'])
    print("INSTANCE STATUS: " + server['status'])
    print("INSTANCE HOST: " + server['hypervisor_hostname'])


def print_server_network_info(conn,server,with_router_info):
    network_count=0
    for internal_network_name in server['addresses']:
        network_count = network_count + 1

        print("\n===INTERFACE " + str(network_count) + "===")
        print("NETWORK NAME: " + internal_network_name)
        for network in conn.network.networks():
            if server['location']['project']['id'] == network['location']['project']['id'] and internal_network_name == network['name']:
                print("NETWORK ID: " + network['id'])

                if with_router_info:
                    for subnet in conn.network.subnets():
                        if network['id'] == subnet['network_id'] and internal_network_name == network['name']:
                            for port in conn.network.ports():
                                if port['fixed_ips'] != []:
                                    if subnet['id'] == port['fixed_ips'][0]['subnet_id']:
                                        for router in conn.network.routers():
                                            if port['device_id'] == router['id']:
                                                print("NETWORK CONNECTED TO: " + router['name'] + " (" + router['id'] + ")")
                                                print("ROUTER STATE: " + router['status'])
                                                print("PORT STATE: " + port['status'])

        print("INTERNAL IP: " + server['addresses'][internal_network_name][0]['addr'])
        try:
            print("INTERFACE FLOATING IP: " + server['addresses'][internal_network_name][1]['addr'])
        except:
            print("INTERFACE FLOATING IP: NONE")
    if network_count == 0:
        print("\nNO NETWORKS ATTACHED")


def print_server_volume_info(conn,server,vol_ids):
    volume_count=0
    for volume_id in vol_ids:

        volume_count = volume_count + 1

        print("\n===VOLUME " + str(volume_count) + "===")
        print("VOLUME ID: " + volume_id)
        print("VOLUME STATUS: " + conn.volume.get_volume(volume_id)['status'])
            
    if volume_count == 0:
        print("\nNO VOLUMES ATTACHED")



main()
