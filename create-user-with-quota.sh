#!/bin/bash
#
# Create an OpenStack user with quotas
#
# Author: Steven Nemetz
# snemetz@hotmail.com

email_domain='hortonworks.com'
openstack_env='/root/keystonerc_admin'
dir_pub_keys='/opt'
quota_cores=40
#quota_cores=${quota_cores:-40}
quota_instances=$quota_cores
quota_ram=$(( quota_cores * 3840 ))

tenant_name=$1
user_name=$2
user_password=$3

#secloud_tenant=89042cdec81c43d39df4a244b4a487c9
#pscloud_tenant=eebcecb02093429b8ba35e6a31f8de84

if [ $# -ne 3 ]; then
  echo "Usage: $0 Tenant User_Name User_Password"
  exit
fi

source $openstack_env
if [ -n "$(keystone user-list | grep ${user_name})" ]; then
  echo "ERROR: Cannot add user $user_name, already exists."
  exit
fi
user_email="${user_name}@${email_domain}"

# Lookup tenant ID
tenant_id=$(keystone tenant-get "$tenant_name" | grep ' id ' | awk '{ print $4 }')
if [ -z "$tenant_id" ]; then
  echo "ERROR: OpenStack tenant $tenant_name not found"
  exit 1
fi
user_pubkey="${dir_pub_keys}/${tenant_name}.pub"

user_id=$(keystone user-create --name ${user_name} --tenant ${tenant_id} --pass "$user_password" --email "${user_email}" | grep ' id ' | awk '{ print $4 }')
#user_id=$(keystone user-list | grep ${user_name} | awk '{ print $2 }')
if [ -z "$user_id" ]; then
  echo "ERROR: user creation failed!"
  exit 2
fi
keystone user-role-add --user ${user_id} --role 'Member' --tenant ${tenant_id}
nova --os-username=${user_name} --os-password="$user_password" --os-tenant-name=${tenant_name} keypair-add --pub-key=${user_pubkey} ${tenant_name}
nova --os-tenant-name ${tenant_name} quota-update --user ${user_id} --instances ${quota_instances} --cores ${quota_cores} --ram ${quota_ram} ${tenant_id}
if [ "${tenant_name}" == 'secloud' ]; then
	keystone user-role-add --user ${user_id} --role 'SwiftOperator' --tenant ${tenant_id}
fi

echo -e "\n"
echo "Account created in OpenStack tenant: ${tenant_name}"
echo "You can access the environment at http://openstack.cloud.hortonworks.com"
echo "Username: ${user_name}"
echo "Password: ${user_password}"
echo "EMail: ${user_email}"
echo ""
echo -e "Please change your password immediately.\n"
echo "Your quotas are:"
nova quota-show --tenant $tenant_id --user $user_id

exit

