#!/bin/bash
#
# Create a new user in OpenStack and add to all tenants
#
# Author: Steven Nemetz
# snemetz@hotmail.com

user_name=$1
user_email=$2
user_passwd=$3

if [ -z "$user_passwd" ]; then
  user_passwd='PassWord'
fi

tenant_ids=$(keystone tenant-list | grep ' True ' | awk '{ print $2 }')
#tenant_names=$(keystone tenant-list | grep ' True ' | awk '{ print $4 }')
# keystone role-list | awk '{ print $2 }'	# ID
# keystone role-list | awk '{ print $4 }'	# Name

keystone user-create --name $user_name --tenant admin --email $user_email --pass $user_passwd
for tenant in $tenant_ids; do
  keystone user-role-add --user $user_name --role '_member_' --tenant-id "$tenant"
  #keystone user-role-list --user $user_name --tenant-id "$tenant"
done
