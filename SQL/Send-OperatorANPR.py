import paramiko
import getpass

# SSH connection details
host = "192.168.178.56"
port = 22
username = input("Enter your username: ")
password = getpass.getpass("Enter your password: ")

# Code to execute on the remote Linux VM
remote_code = """
cd /home/cobalt/grizzly
pwd
"""

# Create SSH client
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    # Connect to the remote host
    ssh.connect(host, port=port, username=username, password=password)

    # Execute the remote code
    stdin, stdout, stderr = ssh.exec_command(remote_code)

    # Print the output
    print(stdout.read().decode())
    print(stderr.read().decode())

finally:
    # Close the SSH connection
    ssh.close()
