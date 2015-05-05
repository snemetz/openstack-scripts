#!/bin/bash

# Trace an instance build with no central logging

# Logs to pull data from:
#   From Controllers:
#     nova-api.log
#     nova-scheduler.log
#   From Hypervisors:
#     nova-compute.log
#     nova-network.log
# Could look at other logs too: glance api, cinder-api

# trace by instance uuid - sort on time (yyyy-mm-dd hh:mm:ss.mmm)
#
# Author: Steven Nemetz
# snemetz@hotmail.com

dirtmp=/tmp
instance_UUID=$1
if [ -z "$instance_UUID" ]; then
  echo "Usage: Instance UUID required"
  exit 1
fi
trace_log="${dirtmp}/trace-${instance_UUID}.log"
controllers='node-212 node-213 node-265 node-266 node-273'

instance_info=$(nova show $instance_UUID)
host=$(echo "$instance_info" | grep OS-EXT-SRV-ATTR:host | awk '{ print $4 }')
instance_ips=$(echo "$instance_info" | grep network | awk -F\| '{ print $3 }' | tr -d ',' | tr -s ' ' | tr ' ' '|' | sed 's/|$//')
# Get attached volume UUIDs and add to things to search for
# Get iSCSI and search for that too
for H in $controllers; do
  ssh root@$H "grep -h $instance_UUID /var/log/nova/nova-api.log /var/log/nova/nova-scheduler.log"
done > $trace_log
ssh root@$host "egrep -h '${instance_UUID}${instance_ips}' /var/log/nova/nova-compute.log /var/log/nova/nova-network.log" >> $trace_log

tmpfile=$(mktemp ${dirtmp}/trace.XXXXXXXX)
sort -k1n -k2n $trace_log > $tmpfile
mv $tmpfile $trace_log

echo "Trace is in: $trace_log"



