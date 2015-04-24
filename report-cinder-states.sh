#!/bin/bash
#
# Report on how many volumes are in each state
#
# Author: Steven Nemetz
# snemetz@hotmail.com

volume_states="attaching available backing-up creating deleting detaching error error_deleting error_extending error_restoring in-use restoring-backup"
# Verified: available, creating, error_deleting, in-use
volume_count=0
echo "Volumes status counts:"
for Status in $volume_states; do
  volume_status_count=$(cinder list --all-tenants 1 --status=$Status | grep $Status | wc -l)
  ((volume_count+=$volume_status_count))
  echo "Volume Status: $Status = $volume_status_count"
done | sort
echo "Total volumes reported: $volume_count"
