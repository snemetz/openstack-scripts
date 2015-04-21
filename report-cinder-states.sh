#!/bin/bash
#
# Report on how many volumes are in each state
#
# Author: Steven Nemetz
# snemetz@hotmail.com

volume_states="creating available attaching in-use deleting error error_deleting backing-up restoring-backup error_restoring error_extending"
echo "Volumes status counts:"
for Status in $volume_states; do
  echo "Volume Status: $Status = $(cinder list --all-tenants 1 --status=$Status | egrep -v 'ID|[+]' | wc -l)"
done
