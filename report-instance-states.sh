#!/bin/bash
#
# Report on how many instances are in each state
#
# Author: Steven Nemetz
# snemetz@hotmail.com

#volume_states="creating available attaching in-use deleting error error_deleting backing-up restoring-backup error_restoring error_extending"

instance_states="ACTIVE BUILD DELETED ERROR PAUSED RESCUED RESIZED SHELVED SHELVED_OFFLOADED SHUTOFF SOFT_DELETED STOPPED SUSPENDED"
power_states="NOSTATE Running" # numbers ?
task_states="deleting None"
vm_states="active"
declare -A active_breakdown

echo "Instance status counts:"
for Status in $instance_states; do
  echo "Instance Status: $Status = $(nova list --all-tenants 1 --status=$Status | egrep -v 'ID|[+]' | wc -l)"
  if [ $Status == 'ACTIVE' ]; then
    keys=$(nova list --all-tenants 1 --status=$Status --fields name,power_state,task_state,OS-EXT-STS:vm_state | egrep -v 'Power|[+]' | awk '{ print $6"-"$8"-"$10 }')
    for K in $keys; do
      ((active_breakdown[$K]++))
    done
  fi
done
echo "Active Instance Breakout:"
for S in "${!active_breakdown[@]}"; do
  echo "$S = ${active_breakdown[$S]}"
done

# Need to break down ACTIVE
#--fields name,power_state,task_state,OS-EXT-STS:vm_state
