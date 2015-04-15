#!/bin/bash

for H in `nova hypervisor-list | awk -F \| '/node/ { print $3 }' | cut -d. -f1 | sort`; do ssh $H 'echo -e "\t$HOSTNAME";for E in eth{0..2}; do ethtool $E | grep Link;done';done

