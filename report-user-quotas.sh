#!/bin/bash
#
# Report quotas for all users or a single user in a tenant
#
# Arguments: tenant [username]
#
# Author: Steven Nemetz
# snemetz@hotmail.com

openstack_env='/root/keystonerc_admin'

tenant='89042cdec81c43d39df4a244b4a487c9' # secloud

tenant_name=$1
user_name=$2

if [ -z "$tenant_name" ]; then
  echo "Usage: $0 <Tenant name> [<user name>]"
  exit 1
fi
source $openstack_env
tenant_id=$(keystone tenant-list | grep $tenant_name | awk '{ print $2 }')

if [ -n "$user_name" ]; then
  # Get user quotas
  user_id=$(keystone user-list | grep ${user_name} | awk '{ print $2 }')
  nova quota-show --tenant $tenant_id --user $user_id
else
  # Get quotas for all users in tenant
  while read bar uuid bar2 name rest; do
    if [ -n "$(keystone user-role-list --user ${uuid} --tenant $tenant_id | grep 'Member')" ]; then
      user_quota=$(nova quota-show --user ${uuid} --tenant $tenant_id)
      cores=$(echo "$user_quota" | grep cores | awk '{print $4}')
      ram=$(echo "$user_quota" | grep ram | awk '{print $4}')
      instances=$(echo "$user_quota" | grep instances | awk '{print $4}')
      echo "User ${name} is setup with the following quotas (cores=${cores}, ram=${ram}, instances=${instances} )"
    fi
  done < <(keystone user-list --tenant-id $tenant_id | sort -k4 -u | grep 'True')
fi

