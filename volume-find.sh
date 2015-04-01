#!/bin/bash
#
# Find where a cinder volume is
#
instance=$1

vm_UUID=$(nova list --all-tenants 1 | grep $instance | awk '{ print $2 }')
echo "VM UUID: $vm_UUID"
vol_UUIDs=$(nova volume-list --all-tenants 1 | grep $vm_UUID | awk '{ print $2 }')
for V in $vol_UUIDs; do
  host=$(cinder show $V | grep os-vol-host-attr:host | awk '{ print $4 }' | cut -d# -f1)
  echo "Volume UUID: $V on Host: $host"
done
