#!/bin/bash

Nova_Instance_Errors='issues-instance-errors'

nova list --all-tenants 1 --fields name,host,instance_name,status,OS-EXT-STS:vm_state,task_state,power_state,created | grep -i error | awk '{ print $2":"$6":"$8 }' | sort -t: -k2 > $Nova_Instance_Errors

