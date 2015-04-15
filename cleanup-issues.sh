#!/bin/bash
#
# Cleanup issues in OpenStack
#	instances, volumes, 
# TODO:
#	Make seperate scripts
#	add testing, verification - both for what needs to be done and if it succeeded, metric of how much got fixed
#	Add metrics for before and after each clean attempt
# REFS:
#	https://raymii.org/s/articles/Fix_inconsistent_Openstack_volumes_and_instances_from_Cinder_and_Nova_via_the_database.html
#


# Cleanup cinder volumes
Volume_Issues_File='issues-volume'
nova volume-list --all-tenants 1 | egrep 'creating|deleting|detaching|available|error' | awk '{ print $2 }' | tee $Volume_Issues_File | xargs -n1 cinder reset-state --state available
#nova volume-list --all-tenants 1 | egrep -v in-use | awk '{ print $2 }' | tee $Volume_Issues_File | xargs -n1 cinder reset-state --state available
# nova volume-detach $vm_uuid $volume_uuid
for V in `cat $Volume_Issues_File`; do nova volume-delete $V; done
echo -n "Volume issues before: "
wc -l $Volume_Issues_File
echo -n "Volume issues after: "
sleep 1
nova volume-list --all-tenants | egrep 'creating|deleting|detaching|available|error' | wc -l
#nova volume-list --all-tenants | egrep -v in-use | wc -l

# Set a volume as detached in Cinder via MySQL
# update cinder.volumes set attach_status='detached',status='available' where id ='$volume_uuid';

# nova volume-detach $vm_uuid $volume_uuid
# Detach a volume from Nova via MySQL
# delete from block_device_mapping where not deleted and volume_id='$volume_uuid' and project_id='$project_uuid';

# cinder delete $volume_uuid
# Delete a volume from Cinder via MySQL
# update volumes set deleted=1,status='deleted',deleted_at=now(),updated_at=now() where deleted=0 and id='$volume_uuid';

# Cleanup nova instances
#	Also look at SHUTOFF|stopped
Nova_Issues_File='issues-nova-instances'
nova list --all-tenants | egrep 'ERROR|BUILD|building|DELETED|deleting|SHUTOFF|NOSTATE|stopped' | awk '{ print $2 }' | tee $Nova_Issues_File | xargs -n1 nova reset-state --active
#nova list --all-tenants | awk '{ print $2 }' | tee $Nova_Issues_File | xargs -n1 nova reset-state --active
for I in `cat $Nova_Issues_File`; do nova delete $I; done
echo -n "Total instances: "
nova list --all-tenants 1 | egrep -v '\---|Name' | wc -l
echo -n "Instance issues before: "
wc -l $Nova_Issues_File
echo -n "Instance issues after: "
sleep 1
nova list --all-tenants | egrep 'ERROR|BUILD|building|DELETED|deleting|SHUTOFF|NOSTATE|stopped' | wc -l
#nova list --all-tenants | wc -l

# List hosts that problem instances are on
nova list --all-tenants 1 --fields name,host,instance_name,status,OS-EXT-STS:vm_state,task_state,power_state,created | egrep -v '\---|Name' | sort -k6 | egrep -i 'ERROR|BUILD|building|DELETED|deleting'

# List hosts that problem volumes are on
cinder list --all-tenants 1
nova volume-list --all-tenants 1

# Restart down services on hosts
Down_Services_File='node-down'
# On a controller node use
#nova-manage service list | grep XXX | grep enabled | sort -k2 | awk '{ print $2":"$1 }' > $Down_Services_File
# From any client with permissions
nova service-list | grep down | grep enabled | sort -k6 | awk '{ print $6":"$4 }' > $Down_Services_File
for L in `cat $Down_Services_File`; do
  node=`echo $L | cut -d: -f1`
  cmd=`echo $L | cut -d: -f2`
  ssh $node "service $cmd restart"
done

# Disable services on hosts
Down_Services_File='node-down'
nova-manage service list | grep XXX | grep enabled | awk '{ print $2":"$1 }' > $Down_Services_File
for L in `cat $Down_Services_File`; do
  node=`echo $L | cut -d: -f1`
  cmd=`echo $L | cut -d: -f2`
  nova-manage service disable --host $node --service $cmd
done
