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
# Get Hypervisor Host that the instance is on
instance_host=$(echo "$instance_info" | grep OS-EXT-SRV-ATTR:host | awk '{ print $4 }')
if [ -z "$instance_host" ]; then
  echo "No host found"
  exit 2
fi
# Get associated Fixed & Floating IPs
instance_ips=$(echo "$instance_info" | grep network | awk -F\| '{ print $3 }' | tr -d ',' | tr -s ' ' | tr ' ' '|' | sed 's/|$//')
# Get instance name
instance_name=$(echo "$instance_info" | grep OS-EXT-SRV-ATTR:instance_name | awk '{ print $4 }')
# Get attached volume UUIDs
volume_UUIDs=$(echo "$instance_info" | grep 'os-extended-volumes:volumes_attached' | awk -F\| '{ print $3 }' | jq '.[].id' | sed s/\"//g)
declare -A volume_hosts
for V in $volume_UUIDs; do
  volume_info=$(cinder show $V)
  volume_hosts[$V]=$(echo "$volume_info" | grep os-vol-host-attr:host | awk '{ print $4 }' | cut -d# -f1)
done
# Start trace report
# Create report header
echo "0000-00-00 Trace for instance $instance_UUID on host $instance_host" > $trace_log
echo "0000-00-01 IP addresses: $(echo $instance_ips | tr '|' ' ')" >> $trace_log
for uuid in "${!volume_hosts[@]}"; do
  echo "0000-00-02 Volume: $uuid on host ${volume_hosts[$uuid]}" >> $trace_log
done
volume_regex=$(echo "$volume_UUIDs" | tr '\n' '|' | sed 's/|$//')
# Start capturing trace data
for H in $controllers; do
  ssh root@$H "egrep -h '$instance_UUID|${volume_regex}' /var/log/nova/nova-{api,scheduler}.log /var/log/cinder/cinder-api.log"
done >> $trace_log
# Get instance data from hypervisor node
ssh root@$instance_host "egrep -h '${instance_UUID}${instance_ips}|${volume_regex}|${instance_name}' /var/log/nova/nova-{compute,dhcpbridge,network}.log /var/log/libvirt/libvirtd.log" >> $trace_log
# Get volume data from storage nodes
for uuid in "${!volume_hosts[@]}"; do
  ssh root@${volume_hosts[$uuid]} "grep -h $uuid /var/log/cinder/cinder-volume.log" >> $trace_log
done

tmpfile=$(mktemp ${dirtmp}/trace.XXXXXXXX)
sort -k1.1,1.4n -k1.6,1.7n -k1.9n -k2.1,2.2n -k2.4,2.5n -k2.7n $trace_log > $tmpfile
mv $tmpfile $trace_log
# Remove lines without date
sed -i '/^[^0-9]/ d' $trace_log

echo "Trace is in: $trace_log"



