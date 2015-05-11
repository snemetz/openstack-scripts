#!/bin/bash

# Cleanup in prep for dismantling part of cluster for rebuild

hypervisors=$(nova service-list | egrep -v 'disabl|down' | grep nova-compute | awk '{ print $6 }' | sort -u)
leave_up=$(for I in $(nova list --all-tenants 1 --name jenkins | grep jenkins | awk '{ print $2 }'); do nova show $I | grep ':host' | awk '{ print $4 }'; done | sort -u | tr '\n' '|' | sed 's/|$//')
for H in $hypervisors; do
  if ! [[ $H =~ $leave_up ]]; then
    #echo "Disable: $H"
    ./disable-host-services-down.sh $H 'Prep for Rackspace rebuild'
  #else
  #  echo "Leave Up: $H"
  fi
done

