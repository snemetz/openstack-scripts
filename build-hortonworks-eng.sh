#!/bin/bash
#
# Build Hortonwork's Eng OpenStack env
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

# Database:
#select id,name,description,enabled,domain_id from keystone.project;
# Create tenants
keystone tenant-create --name cloudbreak --description 'CloudBreak Project'
keystone tenant-create --name hw-dev --description 'Dev Project'
keystone tenant-create --name hw-qe --description 'QE Project'
keystone tenant-create --name hw-re --description 'Release Project'

# Database:
#select flavorid,name,memory_mb,vcpus,swap,rxtx_factor,root_gb,ephemeral_gb,disabled,is_public from nova.instance_types where not deleted;
# Create Flavors
# nova flavor-create --ephemeral <ephemeral_gb> --swap <swap> --rxtx-factor <rxtx_factor> --is_public <is_public> <name> <flavorid> <ram (memory_gb)> <disk (root_gb)> <vcpus>
# Default flavors
#nova flavor-create --is-public True m1.tiny 1 512 1 1
#nova flavor-create --is-public True m1.small 2 2048 20 1
#nova flavor-create --is-public True m1.medium 3 4096 40 2
#nova flavor-create --is-public True m1.large 4 8192 80 4
#nova flavor-create --is-public True m1.xlarge 5 16384 160 8
nova flavor-create --is-public True m1.micro 6 64 0 64
nova flavor-create --is-public True m1.smaller 7 1024 5 1
nova flavor-create --is-public True hwqe.large 100 16384 16 2
nova flavor-create --is-public True hwqe.xlarge 101 16384 16 2
nova flavor-create --is-public True hwqe.large.sles 102 16384 69 2
nova flavor-create --is-public True hwqe.xlarge.sles 103 16384 69 2
nova flavor-create --is-public True hwqe.slave 104 8024 100 4
nova flavor-create --is-public True hw.perf 130 16384 12 8
nova flavor-create --is-public True re.jenkins.slave 200 16384 200 2
nova flavor-create --is-public True solr.cloud 201 32768 500 4
nova flavor-create --is-public True squid.cache 202 32768 100 4
nova flavor-create --ephemeral 500 --is-public True cloudbreak 203 8192 40 2

# Database: nova.security_groups, security_group_rules, security_group_instance_association, security_group_default_rules
#select id,name,description,user_id,project_id from nova.security_groups where not deleted;
#select id,parent_group_id,protocol,from_port,to_port,cidr from nova.security_group_rules where not deleted;
# Create Security Groups
# nova secgroup-create <name> <description>
# Only default groups are used
# Create Security Group Rules
# nova secgroup-add-rule <secgroup> <ip protocol> <from port> <to port> <cidr>
# Verify in admin
nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
# Do in each tenant
tenant_old=$OS_TENANT_NAME
tenant_id_old=$OS_TENANT_ID
export OS_TENANT_ID=
for Tenant in cloudbreak hw-dev hw-qe hw-re; do
  export OS_TENANT_NAME=$Tenant
  nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
  nova secgroup-add-rule default tcp 1 65535 0.0.0.0/0
  nova secgroup-add-rule default udp 1 65535 0.0.0.0/0
done
export OS_TENANT_NAME=$tenant_old
export OS_TENANT_ID=$tenant_id_old

# Database: keystone.user, role, assignment
#select name,password,extra,enabled,domain_id,default_project_id from keystone.user;
#select id,name from keystone.role;	# Role definitions
#select actor_id,target_id,role_id,inherited from keystone.assignment where type='UserProject';
#	actor=user, target=tenant
# Create Users
#keystone user-create --name <user name> --tenant <tenant> --email <email> [--pass <password>]
keystone user-create --name cloudbreak --tenant cloudbreak --email techops@hortonworks.com --pass 123
keystone user-create --name hw-dev --tenant hw-dev --email techops@hortonworks.com --pass 123
keystone user-create --name hw-qe --tenant hw-qe --email techops@hortonworks.com --pass 123
keystone user-create --name hw-re --tenant hw-re --email techops@hortonworks.com --pass 123
#keystone user-create --name gcooper --tenant admin --email gcooper@hortonworks.com --pass 123
keystone user-create --name raja --tenant hw-re --email raja@hortonworks.com --pass 123
keystone user-create --name sbriggs --tenant admin --email sbriggs@hortonworks.com --pass 123
keystone user-create --name sdean --tenant admin --email sdean@hortonworks.com --pass 123
keystone user-create --name sdevineni --tenant hw-re --email sdevineni@hortonworks.com --pass 123
keystone user-create --name snemetz --tenant admin --email snemetz@hortonworks.com --pass 123
keystone user-create --name srastogi --tenant admin --email srastogi@hortonworks.com --pass 123
#keystone user-role-add --user <user> --role <role> --tenant <tenant>
for User in gcooper snemetz srastogi; do
  keystone user-role-add --user $User --role admin --tenant admin
  keystone user-role-add --user $User --role admin --tenant cloudbreak
  keystone user-role-add --user $User --role admin --tenant 'hw-dev'
  keystone user-role-add --user $User --role admin --tenant 'hw-qe'
  keystone user-role-add --user $User --role admin --tenant 'hw-re'
  keystone user-role-add --user $User --role _member_ --tenant cloudbreak
  keystone user-role-add --user $User --role _member_ --tenant 'hw-dev'
  keystone user-role-add --user $User --role _member_ --tenant 'hw-qe'
  keystone user-role-add --user $User --role _member_ --tenant 'hw-re'
done
# TODO: update database with password hashes from old database

# Datbase
# select name,user_id,public_key from nova.key_pairs where not deleted;
# select id,name,extra,password,enabled,domain_id,default_project_id from keystone.user;
# select * from keystone.user join (nova.key_pairs) on (keystone.user.id=nova.key_pairs.user_id) where not nova.key_pairs.deleted;
#nova keypair-add <name> --pub-key <path to ssh public key file>
user_old=$OS_USERNAME
pass_old=$OS_PASSWORD
tenant_old=$OS_TENANT_NAME
tenant_id_old=$OS_TENANT_ID
export OS_TENANT_ID=
# Didn't do admin ones
export OS_PASSWORD=123
export OS_USERNAME=admin
nova keypair-add hw-dev-keypair --pub-key hw-dev-keypair
nova keypair-add hw-qe-keypair --pub-key hw-qe-keypair
nova keypair-add hwadmin --pub-key hwadmin
nova keypair-add hwqekeypair --pub-key hwqekeypair
export OS_PASSWORD=123
export OS_USERNAME=hw-dev
export OS_TENANT_NAME=hw-dev
nova keypair-add hw-dev-keypair --pub-key hw-dev-keypair
export OS_USERNAME=hw-qe
export OS_TENANT_NAME=hw-qe
nova keypair-add hw-qe-keypair --pub-key hw-dev-keypair
nova keypair-add qekeypair --pub-key qekeypair
export OS_USERNAME=hw-re
export OS_TENANT_NAME=hw-re
nova keypair-add hw-re-keypair --pub-key hw-re-keypair
export OS_USERNAME=raja
nova keypair-add raja --pub-key raja
export OS_USERNAME=snemetz
export OS_TENANT_NAME=admin
nova keypair-add snemetz --pub-key snemetz
# reset vars
export OS_PASSWORD=$pass_old
export OS_USERNAME=$user_old
export OS_TENANT_NAME=$tenant_old
export OS_TENANT_ID=$tenant_id_old

| name           | user_id                          | 
+----------------+----------------------------------+
| hw-dev-keypair | admin 6d630ea61e864202b9726b6e695d57da |
| hw-dev-keypair | hw-dev 575a0be8113d4109aff0f3c9aeed5cc7 |
| hw-qe-keypair  | admin 6d630ea61e864202b9726b6e695d57da |
| hw-qe-keypair  | hw-qe 1bbed270c3d84bcaac8e3b7dc9557392 |
| hw-re-keypair  | hw-re 26f19a53a7ab444e9e2abcd2ae0de38a |
| hwadmin        | admin 6d630ea61e864202b9726b6e695d57da |
| hwqekeypair    | admin 6d630ea61e864202b9726b6e695d57da |
| qekeypair      | hw-qe 1bbed270c3d84bcaac8e3b7dc9557392 |
| raja           | raja 242b63df9845465db80d422105778084 |
| snemetz        | snemetz b9f0c67b33e04732beec3bf40c6b8a9d |


# Database: 
#select id,name,size,is_public,disk_format,container_format,owner,min_disk,min_ram,protected from glance.images where not deleted;
#glance image-create --name <name> --disk_format <disk_format> --container-format <container_format> --owner <owner (tenant id)> --min-disk <min_disk> --min-ram <min_ram> --is-public <is_public> --is-protected <protected> --file <image file>
# Upload images
glance image-create --name 'CentOS 5.11' --disk_format qcow2 --container-format bare --owner admin --min-disk 5 --min-ram 512 --is-public True --file <image file>
glance image-create --name 'CentOS 6.6' --disk_format qcow2 --container-format bare --owner admin --min-disk 5 --min-ram 512 --is-public True --file <image file>
glance image-create --name 'CentOS 7.0.1' --disk_format qcow2 --container-format bare --owner admin --min-disk 5 --min-ram 512 --is-public True --file <image file>
glance image-create --name 'Debian 6.0.10' --disk_format qcow2 --container-format bare --owner admin --min-disk 5 --min-ram 512 --is-public True --file <image file>
glance image-create --name 'Debian 7.0.0' --disk_format qcow2 --container-format bare --owner admin --min-disk 5 --min-ram 512 --is-public True --file <image file>
glance image-create --name 'Oracle Linux 6.6' --disk_format qcow2 --container-format bare --owner admin --min-disk 5 --min-ram 512 --is-public True --file <image file>
glance image-create --name 'RE-TS-centos6' --disk_format qcow2 --container-format bare --owner admin --min-disk 5 --min-ram 512 --is-public True --file <image file>
glance image-create --name 'SLES 11 SP3' --disk_format qcow2 --container-format bare --owner admin --min-disk 5 --min-ram 512 --is-public True --file <image file>
glance image-create --name 'TD SLES 11 SP1' --disk_format qcow2 --container-format bare --owner admin --min-disk 5 --min-ram 512 --is-public True --file <image file>
glance image-create --name 'TestVM' --disk_format qcow2 --container-format bare --owner admin --min-disk 0 --min-ram 64 --is-public True --file <image file>
glance image-create --name 'Ubuntu 12.04' --disk_format qcow2 --container-format bare --owner admin --min-disk 16 --min-ram 1024 --is-public True --file <image file>
glance image-create --name 'Ubuntu 14.04' --disk_format qcow2 --container-format bare --owner admin --min-disk 5 --min-ram 512 --is-public True --file <image file>
glance image-create --name 'Windows Server 2012 R2 Standard Eval' --disk_format qcow2 --container-format bare --owner admin --min-disk 40 --min-ram 1000 --is-public True --file <image file>
glance image-create --name 'sdevineni-cent6-img' --disk_format qcow2 --container-format bare --owner sdevineni --min-disk 10 --min-ram 512 --is-public True --file <image file>
glance image-create --name 'sdevineni-cent7-img' --disk_format qcow2 --container-format bare --owner sdevineni --min-disk 10 --min-ram 512 --is-public True --file <image file>
glance image-create --name 'sdevineni-d6-img' --disk_format qcow2 --container-format bare --owner sdevineni --min-disk 10 --min-ram 512 --is-public True --file <image file>
glance image-create --name 'sdevineni-d7-img' --disk_format qcow2 --container-format bare --owner sdevineni --min-disk 10 --min-ram 512 --is-public True --file <image file>
glance image-create --name 'sdevineni-sp1-img' --disk_format qcow2 --container-format bare --owner sdevineni --min-disk 10 --min-ram 512 --is-public True --file <image file>
glance image-create --name 'sdevineni-sp3-img' --disk_format qcow2 --container-format bare --owner sdevineni --min-disk 10 --min-ram 512 --is-public True --file <image file>
glance image-create --name 'sdevineni-u12-img' --disk_format qcow2 --container-format bare --owner sdevineni --min-disk 10 --min-ram 512 --is-public True --file <image file>
glance image-create --name 'sdevineni-u14-img' --disk_format qcow2 --container-format bare --owner sdevineni --min-disk 10 --min-ram 512 --is-public True --file <image file>



