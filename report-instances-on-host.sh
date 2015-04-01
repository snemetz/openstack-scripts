#!/bin/bash

host=$1

nova list --all-tenants 1 --fields name,host,instance_name,status,OS-EXT-STS:vm_state,task_state,power_state,created | grep $host

