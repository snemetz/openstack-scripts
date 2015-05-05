#!/bin/bash

# Run host-cleanup.sh on all hypervisors that are up

for H in $(nova service-list | grep nova-compute | grep ' up ' | awk '{ print $6 }' | sort -u); do
  scp host-cleanup.sh $H:
  ssh $H 'hostname; sed -i "/^ACTION=/ s/0/1/" host-cleanup.sh; ./host-cleanup.sh'
done
