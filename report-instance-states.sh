#!/bin/bash
#
# Report on how many instances are in each state
#
# Author: Steven Nemetz
# snemetz@hotmail.com

#volume_states="creating available attaching in-use deleting error error_deleting backing-up restoring-backup error_restoring error_extending"

instance_states="ACTIVE BUILD DELETED ERROR PAUSED RESCUED RESIZED SHELVED SHELVED_OFFLOADED SHUTOFF SOFT_DELETED STOPPED SUSPENDED"
power_states="NOSTATE Running Shutdown" # numbers ?
task_states="deleting None"
vm_states="active error"
declare -A breakout

echo "Instance status counts:"
for Status in $instance_states; do
  echo -e "\tInstance Status: $Status\t = $(nova list --all-tenants 1 --status=$Status | egrep -v 'ID|[+]' | wc -l)"
  if [ $Status == 'ACTIVE' -o $Status == 'ERROR' ]; then
    keys=$(nova list --all-tenants 1 --status=$Status --fields name,power_state,task_state,OS-EXT-STS:vm_state | egrep -v 'Power|[+]' | awk '{ print $6"-"$8"-"$10 }')
    for K in $keys; do
      ((breakout[${Status}:${K}]++))
    done
  fi
done
echo -e "\nInstance Breakout: Instance Status - Power State - Task State - VM State"
for S in "${!breakout[@]}"; do
  echo -e "\t$S\t = ${breakout[$S]}"
done | sort
exit

