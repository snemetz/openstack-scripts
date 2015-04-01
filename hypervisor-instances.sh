#!/bin/bash

# Get list of all instances on all active hypervisors


vm_list='hypervisor-vms'

hypervisors=`nova hypervisor-list | awk -F \| '/node/ { print $3 }' | cut -d. -f1`

for H in $hypervisors; do
  ssh root@$H virsh list --name 2>/dev/null
done | sort | uniq | tail -n+2 > $vm_list

