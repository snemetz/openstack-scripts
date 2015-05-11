#!/bin/bash
#
# Download Openstack config info for rebuilding OpenStack
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

# Get Flavors
echo "Flavors:"
flavors=$(nova flavor-list --all | egrep -v '[+]|Memory_MB' | awk '{ print $2 }')
for F in $flavors; do
  nova flavor-show $F
done

# Get Tenants
echo -e "\nTenants:"
tenants=$(keystone tenant-list | egrep -v '[+]|enabled' | awk '{ print $2 }')
for T in $tenants; do
  keystone tenant-get $T
done

# Get SecGroups
# nova secgroup-list --all-tenants 1
# nova secgroup-list-rules <ID>

# Get Users
# TODO: get user data per tenant
users=$(keystone user-list | egrep -v '[+]|enabled' | awk '{ print $2 }')
for U in $users; do
  keystone user-get $U
done

# Get keypairs
# Better to pull from database
#echo -e "\nKeypairs:"
# this is per user
#keypairs=$(nova keypair-list | egrep -v '[+]|Fingerprint' | awk '{ print $2 }')
#for K in $keypairs; do
#  nova keypair-show $K
#done

