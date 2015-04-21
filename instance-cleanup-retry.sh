#!/bin/bash
#
# Attempt to have nova cleanup instances in error states

for uuid in $(nova list --all-tenants 1 | egrep  'ERROR.*-.*(NOSTATE|Running)' | awk '{ print $2 }'); do
  nova reset-state --active $uuid;
  nova force-delete $uuid;
done
