#!/bin/bash

# Run host-cleanup.sh on all hypervisors that are up

for H in $(nova service-list | grep nova-compute | grep ' up ' | awk '{ print $6 }' | sort -u); do
  echo "Cleaning $H..."
  scp host-cleanup.sh $H:
  ssh $H 'sed -i "/^ACTION=/ s/0/1/" host-cleanup.sh; ./host-cleanup.sh'
done
