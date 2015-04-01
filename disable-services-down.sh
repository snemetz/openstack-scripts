#!/bin/bash
#
# Disable services that are down and still enabled
#

services_down='services_down'

cinder service-list | grep down | grep enabled | awk '{ print $4 }' | xargs -n1 -I XXX cinder service-disable --reason "Down nodes" XXX cinder-volume
nova service-list | grep down | grep enabled | awk '{ print $ }' | tee $services_down | xargs -n1 -I XXX nova service-disable --reason "Down nodes" XXX nova-compute
for H in `cat $services_down`; do
  nova service-disable --reason "Down nodes" $H nova-network
done

