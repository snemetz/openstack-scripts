#!/bin/bash
#
# Report on how many instances are in each state
#
# Author: Steven Nemetz
# snemetz@hotmail.com

# TODO:
#	option for csv output

#volume_states="creating available attaching in-use deleting error error_deleting backing-up restoring-backup error_restoring error_extending"

instance_states="ACTIVE BUILD DELETED ERROR PAUSED RESCUED RESIZED SHELVED SHELVED_OFFLOADED SHUTOFF SOFT_DELETED STOPPED SUSPENDED"
# Verify states
# Verified instance states: ACTIVE, BUILD, DELETED, ERROR, SHUTOFF
# Find rest of states for below
power_states="NOSTATE Running Shutdown" # numbers ?
task_states="block_device_mapping deleting None scheduling spawning"
vm_states="active building error"

declare -A breakout
pad=$(printf '%0.1s' " "{1..50})

echo "Instance status counts:"
for Status in $instance_states; do
  #echo -e "\tInstance Status: $Status\t = $(nova list --all-tenants 1 --status=$Status | egrep -v 'ID|[+]' | wc -l)"
  padding=$(printf '%*.*s' 0 $((18 - ${#Status})) "$pad")
  # status_count=$(nova list --all-tenants 1 --status=$Status | grep $Status | wc -l)
  # printf "\tInstance Status: %s %s = %s\n" $Status "$padding" "$status_count"
  printf "\tInstance Status: %s %s = %s\n" $Status "$padding" "$(nova list --all-tenants 1 --status=$Status | grep $Status | wc -l)"
  # Todo: and status_count > 0
  if [ $Status == 'ACTIVE' -o $Status == 'BUILD' -o $Status == 'ERROR' ]; then
    keys=$(nova list --all-tenants 1 --status=$Status --fields status,power_state,task_state,OS-EXT-STS:vm_state,name | grep $Status | awk '{ print $6"-"$8"-"$10 }')
    for K in $keys; do
      ((breakout[${Status}:${K}]++))
    done
  fi
done
echo -e "\nInstance Breakout: Instance Status - Power State - Task State - VM State"
for S in "${!breakout[@]}"; do
  #echo -e "\t$S\t = ${breakout[$S]}"
  padding=$(printf '%*.*s' 0 $((35 - ${#S})) "$pad")
  printf "\t%s %s = %s\n" $S "$padding" ${breakout[$S]}
done | sort
exit

