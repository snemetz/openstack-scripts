#!/bin/bash
#
# Cleanup instances in OpenStack
#
# Author: Steven Nemetz

# TODO:
#	script to verify resources and OpenStack DB are in sync. Report on differences
#	  On Hypervisor: instances, nwfilter, nat, ip
#	Cleanup all other references in DB: floating_ip, detach volumes, ...

Nova_Issues_File='issues-nova-instances'
error_pattern='ERROR|BUILD|building|DELETED|deleting|NOSTATE'
MYSQL_HOST='172.22.192.2'
MYSQL_USER='nova'
MYSQL_PASSWORD='xSuJDU6b'

db_validate_uuid () {
  UUID=$1
  Q=`cat <<EOF
select * from nova.instances WHERE instances.uuid = '$UUID';
EOF`
  RQ=`mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASSWORD --batch --skip-column-names -e "$Q" 2>/dev/null`
  echo "$RQ" | grep -q $UUID
  if [ $? -ne 0 ]; then
    return 1
  else
    return 0
  fi
}

db_delete_uuid () {
  UUID=$1
  # 2015-02-26 Updated for Juno - But should be verified that nothing is missing
  # Set instance as deleted, without deleting from database
  # update instances set deleted='1', vm_state='deleted', deleted_at='now()'' where uuid='$vm_uuid' and project_id='$project_uuid';
  # TODO:
  # 	Change to set deleted instead of removing from database
  #	ADD: cleanup floating ip
  # 	ADD: detach volumes
  #	Check for anything else
  #
#set FOREIGN_KEY_CHECKS=0;
  Q=`cat <<EOF
DELETE FROM nova.instance_extra WHERE instance_extra.instance_uuid = '$UUID';
DELETE FROM nova.instance_faults WHERE instance_faults.instance_uuid = '$UUID';
DELETE FROM nova.instance_id_mappings WHERE instance_id_mappings.uuid = '$UUID';
DELETE FROM nova.instance_info_caches WHERE instance_info_caches.instance_uuid = '$UUID';
DELETE FROM nova.instance_metadata WHERE instance_metadata.instance_uuid = '$UUID';
DELETE FROM nova.instance_system_metadata WHERE instance_system_metadata.instance_uuid = '$UUID';
DELETE FROM nova.security_group_instance_association WHERE security_group_instance_association.instance_uuid = '$UUID';
DELETE FROM nova.block_device_mapping WHERE block_device_mapping.instance_uuid = '$UUID';
DELETE FROM nova.fixed_ips WHERE fixed_ips.instance_uuid = '$UUID';
DELETE FROM nova.instance_actions_events WHERE instance_actions_events.action_id in (SELECT id from nova.instance_actions where instance_actions.instance_uuid = '$UUID');
DELETE FROM nova.instance_actions WHERE instance_actions.instance_uuid = '$UUID';
DELETE FROM nova.virtual_interfaces WHERE virtual_interfaces.instance_uuid = '$UUID';
DELETE FROM nova.instances WHERE instances.uuid = '$UUID';
EOF`
#set FOREIGN_KEY_CHECKS=1;
  RQ=`mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASSWORD --batch --skip-column-names -e "$Q" 2>/dev/null`
  # How to determine if success or failure ??
  #echo $?
  #echo "$RQ"
}

nova_cleanup () {
  ### Cleanup nova instances via nova (ones that openstack can still manage)
  #	Also look at SHUTOFF|stopped
  #nova list --all-tenants 1 | egrep 'ERROR|BUILD|building|DELETED|deleting|NOSTATE' | awk '{ print $2 }' | tee $Nova_Issues_File | xargs -n1 nova reset-state --active
  nova list --all-tenants 1 | egrep -i 'delet|error' | awk '{ print $2 }' | tee $Nova_Issues_File | xargs -n1 nova reset-state --active
  #nova list --all-tenants 1 | awk '{ print $2 }' | tee $Nova_Issues_File | xargs -n1 nova reset-state --active
  for I in `cat $Nova_Issues_File`; do nova delete $I; done
}

db_cleanup () {
  ### Cleanup nova instances from database that nova cannot delete
  # Verify that the VM does not exist and if it doesn't remove it from the database
  # List hosts that problem instances are on
  # Generate list: id, host, instance
  #  --status DELETED
  nova list --all-tenants 1 --fields name,host,instance_name,status,OS-EXT-STS:vm_state,task_state,power_state,created | egrep -v '\---|Name' | sort -k6 | egrep -i 'ERROR|BUILD|building|DELETED|deleting|NOSTATE' | awk '{ print $2":"$6":"$8 }' > $Nova_Issues_File
  #nova list --all-tenants 1 --fields name,host,instance_name,status,OS-EXT-STS:vm_state,task_state,power_state,created --status DELETED | egrep -v '\---|Name' | sort -k6 | awk '{ print $2":"$6":"$8 }' > $Nova_Issues_File
  # TODO: improve speed by checking all on a given host at once
  # Could remove :s and read into an array
  for I in `cat $Nova_Issues_File`; do
    vm_uuid=`echo $I | cut -d: -f1`
    host=`echo $I | cut -d: -f2`
    instance=`echo $I | cut -d: -f3`
    ssh $host virsh list --name | grep -q $instance
    if [ $? -ne 0 ]; then
      # VM instance does not exit - clean the database
      # look at using nova user - info on compute nodes
      db_validate_uuid $vm_uuid
      if [ $? -eq 0 ]; then
        echo "Clean DB for $I"
        db_delete_uuid $vm_uuid
      else
        echo "ERROR: VM instance not found: $I"
      fi
    else
      # VM exists - need to determine why can't be deleted
      echo "VM exists: $I"
    fi
  done
}

if [ 1 -eq 1 ]; then 
  echo "Starting instance error cleanup via CLI..."
  nova_cleanup
  echo "Finished cleaning via nova"
  echo -n "Instance issues before: "
  wc -l $Nova_Issues_File
  echo -n "Instance issues after: "
  sleep 1
  #nova list --all-tenants 1 | egrep 'ERROR|BUILD|building|DELETED|deleting|NOSTATE' | wc -l
  nova list --all-tenants 1 | egrep -i 'delet|error' | wc -l
  #nova list --all-tenants 1 | wc -l
fi
if [ 1 -eq 2 ]; then
echo "Starting database cleaning of remaining issues..."
db_cleanup
  echo -n "Instance issues before: "
  wc -l $Nova_Issues_File
  echo -n "Instance issues after: "
  nova list --all-tenants 1 | egrep 'ERROR|BUILD|building|DELETED|deleting|NOSTATE' | wc -l
  #nova list --all-tenants 1 --status DELETED | wc -l
fi

