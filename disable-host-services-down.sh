#!/bin/bash
#
# Disable services on a hypervisor node
#

host=$1
reason=$2

cinder service-disable --reason "$reason" $host cinder-volume
nova service-disable --reason "$reason" $host nova-compute
nova service-disable --reason "$reason" $host nova-network

