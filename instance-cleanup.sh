#!/bin/bash
#
# Cleanup instances in OpenStack
#
# Current actions:
#   if instance in a bad state:
#     Attempt cleanup with OpenStack commands (cinder & nova)
#       reset instance, attempt to detach cinder volumes, attempt to delete
#
# Author: Steven Nemetz

# TODO:
#	script to verify resources and OpenStack DB are in sync. Report on differences
#	  On Hypervisor: instances, nwfilter, nat, ip
#	Cleanup all other references in DB: floating_ip, detach volumes, ...
#	If CLI cleanup fails, do DB and resource cleanup

tmpdir='/tmp'
Nova_Issues_File="${tmpdir}/issues-nova-instances"
log_error="instance-cleanup-errors"
error_pattern='ERROR|BUILD|building|DELETED|deleting|NOSTATE'
MYSQL_HOST='172.22.192.2'
MYSQL_USER='nova'
MYSQL_PASSWORD='xSuJDU6b'
backend_storage='iscsi'
backend_hypervisor='libvirt'

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

fixed_ip_disassociate () {
  #select * from fixed_ips where id =1;
  #+---------------------+------------+------------+----+--------------+------------+-----------+--------+----------+----------------------+------+---------------+---------+
  #| created_at          | updated_at          | deleted_at | id  | address       | network_id | allocated | leased | reserved | virtual_interface_id | host     | instance_uuid | deleted |
  #+---------------------+------------+------------+----+--------------+------------+-----------+--------+----------+----------------------+------+---------------+---------+
  #| 2015-02-12 14:50:54 | NULL                | NULL       |   1 |  192.168.64.0 |          1 |         0 |      0 |        1 |                 NULL | NULL     | NULL          |       0 |
  #| 2015-02-12 14:50:54 | 2015-02-12 19:45:57 | NULL       |  10 |  192.168.64.9 |          1 |         0 |      0 |        0 |                 NULL | node-354 | NULL          |       0 |
  #| 2015-02-12 14:50:54 | 2015-04-03 03:22:12 | NULL       | 100 | 192.168.64.99 |          1 |         1 |      0 |        0 |               211369 | NULL     | 4421818a-ad37-49ea-b917-6598c0bd29f5 |       0 |

  local Instance_UUID=$1
  local Fixed_IP=$2
  nova remove-fixed-ip $Instance_UUID $Fixed_IP
  error=$?
  if [ $error -ne 0 ]; then
    echo "ERROR: $error: Fixed IP: $Fixed_IP, Instance: $Instance_UUID failed to remove fixed ip" >> $log_error
    # Cleanup database
    # update nova.fixed_ips set updated_at=now(),allocated=1,host=NULL,instance_uuid=NULL,virtual_interface_id=NULL where address = "$Fixed_IP";
    # Cleanup hypervisor
  fi
}

floating_ip_disassociate () {
  #select * from nova.floating_ips where id =4383;
  #+---------------------+------------+------------+------+-------------+-------------+------------+------+---------------+------+-----------+---------+
  #| created_at          | updated_at          | deleted_at | id   | address     | fixed_ip_id | project_id                       | host     | auto_assigned | pool | interface | deleted |
  #+---------------------+------------+------------+------+-------------+-------------+------------+------+---------------+------+-----------+---------+
  #| 2015-02-12 15:08:21 | NULL                | NULL       | 4383 | 172.22.84.6 |        NULL | NULL                             | NULL     |             0 | nova | eth2.519  |       0 |
  #| 2015-02-12 15:03:11 | 2015-03-25 00:30:12 | NULL       |    1 | 172.22.67.1 |        4365 | ba5aee7d599245c981c3b0ffc518d532 | node-277 |             1 | nova | eth2.519  |       0 |

  local Instance_UUID=$1
  local Floating_IP=$2
  nova floating-ip-disassociate $Instance_UUID $Floating_IP
  error=$?
  if [ $error -ne 0 ]; then
    echo "ERROR: $error: Floating IP: $Floating IP, Instance: $Instance_UUID failed to disassociate floating ip" >> $log_error
    # Cleanup database
    # update nova.floating_ips set updated_at=now(),fixed_ip_id=NULL,project_id=NULL,host=NULL,auto_assigned=0 where address = "$Floating_IP";
    # Cleanup hypervisor
  fi
}

volume_delete () {
  local Volume_UUID=$1
  #cinder delete $Volume_UUID
  #cinder reset-state --state available $Volume_UUID
  cinder force-delete $Volume_UUID
  error=$?
  if [ $error -ne 0 ]; then
    echo "ERROR: $error: Volume: $Volume_UUID failed to delete" >> $log_error
    ### Cleanup database
    # TODO: clean database, cleanup resources on storage node (iscsi, files, ...)
    #cinder.volumes iscsi_targets reservations volume_metadata
    #volumes: updated_at, deleted_at, host, instance_uuid, ...
    #iscsi_targets: updated_at, deleted_at, deleted, host, volume_id
    #reservations: updated_at, deleted_at, deleted, uuid
    #volume_metadata: updated_at, deleted_at, deleted, volume_id
    # update nova.block_device_mapping set updated_at=now(),deleted_at=now(),deleted=id where not deleted and volume_id='$Volume_UUID';
    # mysql -e "update cinder.volumes set updated_at=now(),deleted_at=now(),terminated_at=now(),mountpoint=NULL,instance_uuid=NULL,status='deleted',deleted=1 where deleted=0 and id='$Volume_UUID';"
    case $backend_storage in
      iscsi)
        ### Cleanup storage node - iscsi
        host=$(cinder show $Volume_UUID | grep os-vol-host-attr:host | awk '{ print $4 }' | cut -d\# -f1)
        #   ssh to the volume hosting storage
#TEST is in error_deleting:  node-230 - 9d4253af-e0ef-4c31-a955-72283f9aa20b
        # Create script
        cat >$script_volume_delete <<EOF
#!/bin/bash

# identify the target lun
target_lun=\$(tgt-admin -s | grep $Volume_UUID | grep ^Target | awk '{ print \$2 }' | cut -d: -f1)
# Backing device: /dev/cinder/volume-<UUID>
backing_store_path=\$(tgt-admin -s | grep $Volume_UUID | grep 'Backing store path' | awk '{ print \$4 }')

# mark the target offline - offline target
tgt-admin --offline tid=\$target_lun

# get a list of all active connections to this lun (If there are none, skip the next step)
for session_id in \$(tgtadm --lld iscsi --op show --mode conn --tid \$target_lun | grep ^Session | awk '{ print \$2 }'); do
  # close active sessions - didn't close
  tgtadm --lld iscsi --op delete --mode conn --tid \$target_lun --sid \$session_id
  # Might need --cid \$connection_id
done

# delete the lun - got error: target is still active - Can add --force
tgtadm --lld iscsi --op delete --mode target --tid \$target_lun

# delete the target file in /var/lib/cinder/volumes
# How to determine this path?
rm /var/lib/cinder/volumes/volume-$Volume_UUID

# delete the logical volume
lvremove -f cinder/volume-$Volume_UUID

# - Please note the above will leave a stale connection reference in the local iscsi connection table.  The connection itself is gone, however.  This doesn't cause any problems and can be corrected by running the following:
#    # iscsiadm -m node -T <target name> -p <cinder host>:<port> -u
#    # iscsiadm -m node -T <target name> -p localhost:3260 -u
EOF
        #scp $script_volume_delete root@$host:
        # run script
        #ssh root@$host bash ./$script_volume_delete
      ;;
      *)
        echo "ERROR: Unsupported storage backend: $backend_storage"
      ;;
    esac
  fi
}

volume_detach () {
  local Instance_UUID=$1
  local Volume_UUID=$2
  echo -e "\tDetaching: $Volume_UUID"
  Q=`cat <<EOF
update nova.block_device_mapping set deleted_at=now(),updated_at=now(),deleted=id where not deleted and volume_id='$Volume_UUID';
update cinder.volumes set updated_at=now(),attach_status='detached',attached_host=NULL,status='available' where id ='$Volume_UUID';
EOF`
  nova volume-detach $Instance_UUID $Volume_UUID 2>> $log_error
  error=$?
  if [ $error -ne 0 ]; then
    echo "ERROR: $error: Instance: $Instance_UUID Volume: $Volume_UUID while attempting detach" >> $log_error
    RQ=$(mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASSWORD --batch --skip-column-names -e "$Q" 2>> $log_error)
    return 0
  else
    return 0
  fi
}

instance_delete () {
  local Instance_UUID=$1
  nova force-delete $I 2>> $log_error
  error=$?
  if [ $error -ne 0 ]; then
    echo "ERROR: $error: Instance: $I while attempting delete" >> $log_error
    ### Cleanup database
    # mysql -e "update nova.instances set updated_at=now(),deleted_at=now(),terminated_at=now(),vm_state='deleted',task_state=NULL,deleted='1' where uuid='$Instance_UUID';"
    ### Cleanup hypervisor - libvirt (kvm)
    # - ssh to the hosting hypervisor
    # - destroy the instance
    # - get the instance id from libvirt.xml
    #    # grep "<name>instance" /var/lib/nova/instances/e621cbc8-0ab2-4d72-8c48-2b48fb7f9908/libvirt.xml
    #    # /var/lib/nova/instances/<Nova instance UUID>
    # - destroy and undefine the instance
    #    # virsh destroy instance-XXXXXXXX
    #    # virsh undefine instance-XXXXXXXX
    # - delete the instance directory
    #    # rm -rf /var/lib/nova/instances/<instance uuid>
  fi
}
nova_cleanup () {
  ### Cleanup nova instances
  #	Also look at SHUTOFF|stopped
  #nova list --all-tenants 1 | egrep 'ERROR|BUILD|building|DELETED|deleting|NOSTATE' | awk '{ print $2 }' | tee $Nova_Issues_File | xargs -n1 nova reset-state --active
  nova list --all-tenants 1 | egrep -i 'delet|error' | awk '{ print $2 }' | tee $Nova_Issues_File | xargs -n1 nova reset-state --active
  #nova list --all-tenants 1 | awk '{ print $2 }' | tee $Nova_Issues_File | xargs -n1 nova reset-state --active
  for I in `cat $Nova_Issues_File`; do
    echo "Attempting to fix: $I"
    details=$(nova show $I 2>/dev/null)
    if [ $? -eq 0 ]; then
    #  # will fail if task_state=deleting
    #  ACTIVE,deleting,NOSTATE - Still trying
    #  ERROR,-,NOSTATE - reset,force
    #  'fault' may contain a stack trace
      ###  Get attached volumes and detach, then delete
      #IName=$(echo "$details" | grep '| name ' | awk '{ print $4 }')
      # Change to get data from $details
      #volumes=$(nova list --name $IName --fields os-extended-volumes:volumes_attached | egrep -v '[+]|ID' | awk -F\| '{ print $3 }' | sed "s/u\'/\'/g" | sed s/\'/\"/g | jq '.[].id?' | sed s/\"//g)
      volumes=$(echo "$details" | grep 'os-extended-volumes:volumes_attached' | awk -F\| '{ print $3 }' | jq '.[].id' | sed s/\"//g)
      for V in $volumes; do
        # Check cinder that volume is in-use
        if [ "$(nova volume-show $V 2>/dev/null | grep '| status ' | awk '{ print $4 }')" == 'in-use' ]; then
          #volume_detach $I $V
          #if [ $? -eq 0 ]; then
          #  volume_delete $V
          #fi
          echo -e "\tDetaching: $V"
          nova volume-detach $I $V 2>> $log_error
          error=$?
          if [ $error -ne 0 ]; then
            echo "ERROR: $error: Instance: $I Volume: $V while attempting detach" >> $log_error
          fi
        fi
      done
      ### Get Floating IPs and disassociate
      ### Get Fixed IPs and remove
      # nova fixed-ip-get to get/verify fixed ip - returns: instance name, host
      sleep 2
      #nova force-delete $I
      nova delete $I 2>> $log_error
      error=$?
      if [ $error -ne 0 ]; then
        echo "ERROR: $error: Instance: $I while attempting delete" >> $log_error
        # Cleanup database
        # Cleanup hypervisor
      fi
    fi
  done
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

cp /dev/null $log_error
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

