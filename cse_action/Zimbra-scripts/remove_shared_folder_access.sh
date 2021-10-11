#!/bin/bash
# USAGE: ./remove_shared_mailbox_access.sh email@domain folder_name
#   eg: ./remove_shared_mailbox_access.sh me@mydomain /
#       ./remove_shared_mailbox_access.sh me@mydomain /inbox
#       ./remove_shared_mailbox_access.sh me@mydomain /junk
#       ./remove_shared_mailbox_access.sh me@mydomain /sent
# README:
# This script is to help save time manually removing shared mailbox access. 

if [[ $# -eq 0 ]]; then
    echo "Insufficient arguments: $0 email@domain.name folder_name"
    exit 1
fi

for ZIMBRAUSERNAME in $(zmmailbox -z -m "$1" gfg $2 | grep account | awk '{print $NF}'); do
        echo $ZIMBRAUSERNAME
        zmmailbox -z -m $1 mfg $2 account $ZIMBRAUSERNAME none
done

exit 0
