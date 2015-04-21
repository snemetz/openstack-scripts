#!/bin/bash
#
# Setup so all hosts can ssh to all other hosts. Nova user required. Do system wide
# This is because to resize an instance, it needs to ssh from the host with the instance to the host with the new storage
# This is probably specific to iscsi setup

# or build hostkey db and copy it to all hosts
# ~user/known_hosts or /etc/ssh/known_hosts /etc/ssh/ssh_known_hosts
# ssh-keyscan - fetch key: -H hash -v verbose -t type

# Get both by hostname and IP address
ip_list=''
#host_list=$(cinder service-list | grep up | awk '{ print $4 }' | sort -u)
host_list=$(nova service-list | grep ' up ' | awk '{ print $4 }' | sort -u )
for H in $host_list; do
  ip_list=$(echo -e "${ip_list}\n$(grep $H /etc/hosts | awk '{ print $1 }')")
done

if [ -f /etc/ssh/ssh_known_hosts ]; then
  file_old='/etc/ssh/ssh_known_hosts'
else
  file_old=''
fi
# Comment lines go to STDERR
echo "$ip_list" | ssh-keyscan -f - -t rsa,dsa | sort -u - $file_old | sed '/127.0.0.1/ d' > /tmp/known_hosts
echo "$host_list" | ssh-keyscan -f - -t rsa,dsa | sort -u - >> /tmp/known_hosts
for H in $host_list; do
  scp /tmp/known_hosts $H:/etc/ssh/ssh_known_hosts
  ssh $H 'chmod +r /etc/ssh/ssh_known_hosts'
done
