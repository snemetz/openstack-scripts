#!/bin/bash

# Pull the list of all users
# Check to see which users have Member role assigned for the secloud tenant
# Check to see which users do not have the correct quotas set for cores,instances,ram
# Update only those users.

# Arguments: tenant

tenant='89042cdec81c43d39df4a244b4a487c9' # secloud

# Get tenant ID
#	awk = id=$2 name=$4
tenant_name=$1
tenant_id=$(keystone tenant-list | grep $tenant_name | awk '{ print $2 }')

# Pull the list of all users
while read bar uuid bar2 name rest; do
  if [ -n "$(keystone user-role-list --user ${uuid} --tenant $tenant_id | grep 'Member')" ]; then
    user_quota=$(nova quota-show --user ${uuid} --tenant $tenant_id)
    cores=$(echo "$user_quota" | grep cores | awk '{print $4}')
    ram=$(echo "$user_quota" | grep ram | awk '{print $4}')
    instances=$(echo "$user_quota" | grep instances | awk '{print $4}')
    echo "User ${name} is setup with the following quotas (cores=${cores}, ram=${ram}, instances=${instances} )"
  fi
done < <(keystone user-list --tenant-id $tenant_id | sort -k4 -u | grep 'True')
