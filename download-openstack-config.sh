#!/bin/bash
#
# Download Openstack config info for rebuilding OpenStack
#
#  This is a work in progress
#
# Gather data:
#	flavors, tenants, users, keypairs,
#	Future: quotas, secgroups, networks, 
#
# TODO:
#	Decide what format to put data in
#
# Author: Steven Nemetz
# snemetz@hotmail.com

# Get Tenants
echo -e "\nTenants:"
tenants=$(keystone tenant-list | egrep -v '[+]|enabled')
header="Name,Enabled,Description"
echo "$header"
for T in $(echo "$tenants" | awk '{ print $2 }'); do
  info_tenant=$(keystone tenant-get $T)
  name=$(echo "$info_tenant" | grep name | awk -F\| '{ print $3 }' | sed 's/^\s*\(.*\S\)\s*$/\1/')
  enable=$(echo "$info_tenant" | grep enabled | awk -F\| '{ print $3 }' | sed 's/^\s*\(\S*\)\s*$/\1/')
  desc=$(echo "$info_tenant" | grep description | awk -F\| '{ print $3 }' | sed 's/^\s*\(.*\S\)\s*$/\1/')
  echo "$name,$enable,$desc"
done
# Database:
#select id,name,description,enabled,domain_id from keystone.project;
#keystone tenant-create --name <name> --description <desc>

# Get Flavors
echo "Flavors:"
flavors=$(nova flavor-list --all | egrep -v '[+]|Memory_MB' | awk '{ print $2 }')
for F in $flavors; do
  header=''
  line=''
  info_flavor=$(nova flavor-show $F | egrep -v '[+]|Property')
  for property in $(echo "$info_flavor" | awk -F\| '{ print $2 }' | sed 's/^\s*\(.*\S\)\s*$/\1/'); do
    header="$header,$property"
    item=$(echo "$info_flavor" | egrep "^\| $property" | awk -F\| '{ print $3 }' | sed 's/^\s*\(.*\S\)\s*$/\1/' | sed 's/^\s*$//')
    line="$line,$item"
  done
  line=$(echo "$line" | cut -c 2-)
  header=$(echo "$header" | cut -c 2-)
  echo "$header"
  echo "$line"
done
echo "$header"
# Database:
#select flavorid,name,memory_mb,vcpus,swap,vcpu_weight,rxtx_factor,root_gb,ephemeral_gb,disabled,is_public from nova.instance_types where not deleted;
# nova flavor-create --ephemeral <ephemeral_gb> --swap <swap> --rxtx-factor <rxtx_factor> --is_public <is_public> <name> <flavorid> <ram (memory_gb)> <disk (root_gb)> <vcpus>

# Get SecGroups
secgroups=$(nova secgroup-list --all-tenants 1 | egrep -v '[+]|Tenant_ID')
# Capture: Name, Description, Tenant_ID
header="name,description,tenant"
echo "$header"
for id in $(echo "$secgroups" | awk -F\| '{ print $2 }'); do
  echo -e "\nDEBUG: secgroup id: $id"
  name=$(echo "$secgroups" | grep "^| $id " | awk -F\| '{ print $3 }' | sed 's/^\s*\(.*\S\)\s*$/\1/' )
  desc=$(echo "$secgroups" | grep "^| $id " | awk -F\| '{ print $4 }' | sed 's/^\s*\(.*\S\)\s*$/\1/' )
  tenant_id=$(echo "$secgroups" | grep "^| $id " | awk -F\| '{ print $5 }' | sed 's/^\s*\(.*\S\)\s*$/\1/' )
  tenant=$(echo "$tenants" | grep $tenant_id | awk -F\| '{ print $3 }' | sed 's/^\s*\(.*\S\)\s*$/\1/')
  if [ -n "$tenant" ]; then
    echo "$name,$desc,$tenant"
    # Can be no rules
    rules=$(nova secgroup-list-rules $id | egrep -v '[+]|Protocol')
    # Capture: IP Protocol, From Port, To Port, IP Range, Source Group
    rules_csv=$(echo "$rules" | sed 's/\(\s*|\s*\)/,/g' | cut -c 2- | rev | cut -c 2- | rev)
    echo "$rules_csv"
    #echo "$rules"
  fi
done
# Database: nova.security_groups, security_group_rules, security_group_instance_association, security_group_default_rules
#select from nova.
# nova secgroup-create <name> <description>
# nova secgroup-add-rule <secgroup> <ip protocol> <from port> <to port> <cidr>

# Get Users
# Better pull from database - get more data
users=$(keystone user-list | egrep -v '[+]|enabled' | awk '{ print $2 }')
for user in $users; do
  info_user=$(keystone user-get $user | egrep -v '[+]|Property')
  username=$(echo "$info_user" | grep '^| username ' | awk -F\| '{ print $3 }' | sed 's/^\s*\(.*\S\)\s*$/\1/')
  # Capture: email, enabled name, tenant (map ID to name), username
  # TODO: map tenant id
  echo -e "\nUser: $username\n$info_user"
  for tenant_id in $(echo "$tenants" | awk '{ print $2 }'); do
    tenant_name=$(echo "$tenants" | grep $tenant_id | awk -F\| '{ print $3 }' | sed 's/^\s*\(.*\S\)\s*$/\1/')
    info_roles=$(keystone user-role-list --user $user --tenant $tenant_id | egrep -v '[+]|tenant_id')
    # Capture: name, user_id, tenant_id
    if [ -n "$info_roles" ]; then
      roles=$(echo "$info_roles" | awk -F\| '{ print $3 }' | sed 's/^\s*\(.*\S\)\s*$/\1/' | sed "s/$/,$username,$tenant_name/")
      echo -e "Roles CSV for $username in $tenant_name:\n$roles"
      echo -e "info_roles\n$info_roles"
    fi 
  done
done
# Database: keystone.user, role, assignment
#select name,password,enabled,domain_id,default_project_id from keystone.user;
#select id,name from keystone.role;	# Role definitions
#select actor_id,target_id,role_id,inherited from keystone.assignment where type='UserProject';
#	actor=user, target=tenant
#keystone user-create --name <user name> --tenant <tenant> --email <email> [--pass <password>]
#keystone user-role-add --user <user> --role <role> --tenant <tenant>

# Get keypairs
# Better to pull from database
#echo -e "\nKeypairs:"
# this is per user
#keypairs=$(nova keypair-list | egrep -v '[+]|Fingerprint' | awk '{ print $2 }')
#for K in $keypairs; do
#  nova keypair-show $K
#done
# Datbase
# select name,user_id,public_key from nova.key_pairs where not deleted;
# select id,name,extra,password,enabled,domain_id,default_project_id from keystone.user;
# select * from keystone.user join (nova.key_pairs) on (keystone.user.id=nova.key_pairs.user_id) where not nova.key_pairs.deleted;
#nova keypair-add

# Get Images & metadata
# Get all formats, then loop on. This is for naming the files correctly
if [ 1 -eq 2 ]; then
formats=$(glance image-list --all-tenants | egrep -v '[+]|Disk Format' | awk -F\| '{ print $4 }' | sed 's/ //g' | sort -u)
# Has: id, name, disk format, container format, size, status
for F in $formats; do
  images=$(glance image-list --all-tenants --disk-format $F | grep $F | awk '{ print $2 }')
  for I in $images; do
    info_image=$(glance image-show $I | egrep -v '[+]|Property')
    name=$(echo "$info_image" | grep ' name ' | awk -F\| '{ print $3 }' | tr -s ' ' | cut -c2- | sed 's/ $//')
    # image-show has: contain format, disk format, is public, min disk, min ram, name, owner id, protected
    # capture: contain format, disk format, is public, min disk, min ram, name, owner (map to name), protected
    # save metadata to ${name}.meta
    echo "Downloading: $I..."
    echo "Creating ${name}.$F"
    glance image-download --file "${name}.$F" $I
  done
done
fi
# Database: 
#select id,name,size,is_public,disk_format,container_format,owner,min_disk,min_ram,protected from glance.images where not deleted;
#glance image-create --name <name> --disk_format <disk_format> --container-format <container_format> --owner <owner (tenant id)> --min-disk <min_disk> --min-ram <min_ram> --is-public <is_public> --is-protected <protected> --file <image file>



