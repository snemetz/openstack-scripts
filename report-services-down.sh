#!/bin/bash
#
# Report on services that are down and still enabled
#

# Author: Steven Nemetz
# snemetz@hotmail.com

email='snemetz@hortonworks.com'
dir_tmp='/tmp'
down_cinder="${dir_tmp}/down-service-cinder"
down_nova="${dir_tmp}/down-service-nova"

cinder_services_down=$(cinder service-list | grep down | grep enabled | tee $down_cinder | wc -l )
nova_services_down=$(nova service-list | grep down | grep enabled | tee $down_nova | wc -l)
echo "Cinder services down: $cinder_services_down"
echo "Nova services down: $nova_services_down"

if [ $cinder_services_down -ne 0 -o $nova_services_down -ne 0 ]; then
  #mail -s "OpenStack Report: Eng Services Down" $email <<MSG
  cat << MSG
OpenStack Cinder & Nova Services Report

If all 3 services are down on a host, most likely the system crashed.
	Disable the services. Then find the IPMI to verify and reboot
If 1 or 2 services are down on a host
	Restart the services and see if the log says anything useful.

Cinder Issues: $cinder_services_down
$(cat $down_cinder)

Nova Issues: $nova_services_down
$(cat $down_nova)
MSG

fi
rm -f $down_cinder $down_nova
