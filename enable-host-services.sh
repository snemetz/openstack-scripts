#!/bin/bash
#
# Enable services on a hypervisor node
#

host=$1

nova service-enable $host nova-compute
nova service-enable $host nova-network
cinder service-enable $host cinder-volume

