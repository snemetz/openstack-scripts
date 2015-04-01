#!/bin/bash 

for H in `nova hypervisor-list | awk -F \| '/node/ { print $3 }' | cut -d. -f1 | sort`; do ssh root@$H 'service nova-network restart;service nova-compute restart; service nova-api restart;service cinder-volume restart'; done
