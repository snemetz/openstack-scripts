#!/bin/bash 
#
# Restart agent services that are down
#
# Author: Steven Nemetz
# snemetz@hotmail.com

delay=5
regex_state='enable.*down'

# Restart down Nova agent services
hypervisors=$(nova service-list | egrep 'nova-(compute|network)' | egrep -i "$regex_state" | awk '{ print $6 }' | sort -u)
for H in $hypervisors; do
  ssh root@$H 'hostname;service nova-network restart;service nova-compute restart; service nova-api restart'
  if [ $delay -gt 0 ]; then
    sleep $delay
  fi
done

# Restart down Cinder agent services
hypervisors=$(cinder service-list | grep 'cinder-volume' | egrep -i "$regex_state" | awk '{ print $6 }' | sort -u)
for H in $hypervisors; do
  ssh root@$H 'hostname;service cinder-volume restart'
  if [ $delay -gt 0 ]; then
    sleep $delay
  fi
done
