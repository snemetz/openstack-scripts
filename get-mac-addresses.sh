#!/bin/bash

# Get MAC addresses for documentation
mac_list='mac_nodes'
for H in `grep node /etc/hosts`; do
  ssh root@$H 'ifconfig | grep HWaddr | egrep "eth0[^.]" | awk "{ print \$1\",\"\$5 }" | sed "s/^/$HOSTNAME,/"'
done > $mac_list
