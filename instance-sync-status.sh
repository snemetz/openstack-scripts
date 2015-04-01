#!/bin/bash

hypervisors=`nova hypervisor-list | awk -F \| '/node/ { print $3 }' | cut -d. -f1`

for H in $hypervisors; do
  ssh $H virsh list --name 2>/dev/null
done | sort | uniq | tail -n+2 > vms-hypervisors

nova list --all-tenants 1 --fields name,host,instance_name | awk -F \| '/instance/ { print $5 }' | tr -d ' ' |sort | uniq > vms-openstack

diff vms-hypervisors vms-openstack
