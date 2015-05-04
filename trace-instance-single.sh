#!/bin/bash

# Trace an instance build

# Logs to pull data from:
#   From Controllers:
#     nova-api.log
#     nova-scheduler.log
#   From Hypervisors:
#     nova-compute.log
#     nova-network.log
# Could look at other logs too: glance api, cinder-api

# trace by tenant uuid and instance uuid - sort on time (yyyy-mm-dd hh:mm:ss.mmm)
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

host=$(nova show $instance_UUID | grep OS-EXT-SRV-ATTR:host | awk '{ print $4 }')
for H in $controllers; do
  ssh root@$H "grep -h $instance_UUID /var/log/nova/nova-api.log /var/log/nova/nova-scheduler.log"
done > $trace_log
ssh root@$host "grep -h $instance_UUID /var/log/nova/nova-compute.log /var/log/nova/nova-network.log" >> $trace_log

tmpfile=$(mktemp ${dirtmp}/trace.XXXXXXXX)
sort -k1n -k2n $trace_log > $tmpfile
mv $tmpfile $trace_log

echo "Trace is in: $trace_log"



