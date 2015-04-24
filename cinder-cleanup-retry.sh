#!/bin/bash
#
# Attempt to have Cinder cleanup volumes in error states

# Status values:
#    creating, available, attaching, in-use, deleting, detaching, error, error_deleting, backing-up, restoring-backup, error_restoring, error_extending
# Verified states: creating, available, in-use, deleting, detaching, error_deleting

for Status in deleting detaching error error_deleting; do
  for Volume in $(cinder list --all-tenants 1 --status=$Status | grep $Status | awk '{ print $2 }'); do
    cinder reset-state --state available $Volume
    cinder force-delete $Volume
  done
done

