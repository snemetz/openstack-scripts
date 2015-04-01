#!/bin/bash

# Get list of all cinder volumes on all active hypervisors


vol_list='hypervisor-cinder-volumes'

hypervisors=`nova hypervisor-list | awk -F \| '/node/ { print $3 }' | cut -d. -f1 | sort`

for H in $hypervisors; do
  ssh root@$H ls -1 /var/lib/cinder/volumes/
done | sort > $vol_list

