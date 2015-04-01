#!/bin/bash
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    <http://www.gnu.org/licenses/>.
#
# From: https://gist.github.com/arxcruz/3a94dee0e64f7ba25c8d
# Notes: http://blog.arxcruz.net/deleting-openstack-instances-directly-from-database
#
# 2015-02-26 Updated with 1 more command for Juno
#
# TODO:
#	Add usage
 
VMNAME=$4
MYSQL_HOST=$1
MYSQL_USER=$2
MYSQL_PASSWORD=$3
 
if [ -z "$4" ]; then echo "VM Name not given"; exit 1; fi
Q=`cat <<EOF
SELECT id FROM nova.instances WHERE instances.display_name = '$VMNAME';
SELECT uuid FROM nova.instances WHERE instances.display_name = '$VMNAME';
EOF`
RQ=`mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASSWORD --batch --skip-column-names -e "$Q"`
 
ID=`echo $RQ | cut -d' ' -f1`
UUID=`echo $RQ | cut -d' ' -f2`
 
if [ -z "$ID" ]; then echo "ID for $VNAME not found"; exit 1; fi
if [ -z "$UUID" ]; then echo "UUID for $VNAME not found"; exit 1; fi
 
echo "VMNAME: $VMNAME"
echo "ID: $ID"
echo "UUID: $UUID"
 
echo "Delete $VMNAME? (y/n)"
read -e YN
if [ "$YN" != 'y' ]; then echo "Exiting...";exit 1;fi
 
Q=`cat <<EOF
DELETE FROM nova.instance_faults WHERE instance_faults.instance_uuid = '$UUID';
DELETE FROM nova.instance_id_mappings WHERE instance_id_mappings.uuid = '$UUID';
DELETE FROM nova.instance_info_caches WHERE instance_info_caches.instance_uuid = '$UUID';
DELETE FROM nova.instance_system_metadata WHERE instance_system_metadata.instance_uuid = '$UUID';
DELETE FROM nova.instance_extra WHERE extra_instance_uuid = '$UUID';
DELETE FROM nova.security_group_instance_association WHERE security_group_instance_association.instance_uuid = '$UUID';
DELETE FROM nova.block_device_mapping WHERE block_device_mapping.instance_uuid = '$UUID';
DELETE FROM nova.fixed_ips WHERE fixed_ips.instance_uuid = '$UUID';
DELETE FROM nova.instance_actions_events WHERE instance_actions_events.action_id in (SELECT id from nova.instance_actions where instance_actions.instance_uuid = '$UUID');
DELETE FROM nova.instance_actions WHERE instance_actions.instance_uuid = '$UUID';
DELETE FROM nova.virtual_interfaces WHERE virtual_interfaces.instance_uuid = '$UUID';
DELETE FROM nova.instances WHERE instances.uuid = '$UUID';
EOF`
RQ=`mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASSWORD --batch --skip-column-names -e "$Q"`
echo "$RQ"
