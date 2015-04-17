#!/bin/bash
#
# Cleanup issues in OpenStack
#	volumes, 
# TODO:
#	Make seperate scripts
#	add testing, verification - both for what needs to be done and if it succeeded, metric of how much got fixed
#	Add metrics for before and after each clean attempt
# REFS:
#	https://raymii.org/s/articles/Fix_inconsistent_Openstack_volumes_and_instances_from_Cinder_and_Nova_via_the_database.html
#

Volume_Issues_File='issues-volume'

cinder_cleanup () {
  ### Cleanup cinder volumes via nova (or cinder)
  # Status values:
  #    creating, available, attaching, in-use, deleting, error, error_deleting, backing-up, restoring-backup, error_restoring, error_extending
  #for Status in creating detaching error_deleting available; do
  #  for Volume in $(cinder list --all-tenants 1 --status=$Status | grep -v 'ID|[+]' | awk '{ print $2 }'); do
  #    case
  #  done
  #done
  # cinder list --all-tenants 1 --status=creating | grep -v 'ID|[+]' | awk '{ print $2 }'
  # cinder list --all-tenants 1 --status=detaching | grep -v 'ID|[+]' | awk '{ print $2 }'
  # cinder list --all-tenants 1 --status=error_deleting | grep -v 'ID|[+]' | awk '{ print $2 }'
  # cinder list --all-tenants 1 --status=available | grep -v 'ID|[+]' | awk '{ print $2 }' | xargs cinder delete
  # cinder delete|force-delete
  #nova volume-list --all-tenants 1 | egrep 'creating|deleting|detaching|available|error' | awk '{ print $2 }' | tee $Volume_Issues_File | xargs -n1 cinder reset-state --state available
  #nova volume-list --all-tenants 1 | egrep -v in-use | awk '{ print $2 }' | tee $Volume_Issues_File | xargs -n1 cinder reset-state --state available
  nova volume-list --all-tenants 1 | grep -i delet | awk '{ print $2 }' | tee $Volume_Issues_File | xargs -n1 cinder reset-state --state error
  # nova volume-detach $vm_uuid $volume_uuid
  for V in `cat $Volume_Issues_File`; do nova volume-delete $V; done
}

echo "Starting volume error cleanup via CLI..."
cinder_cleanup
echo "Finished cleaning via cinder/nova"
echo -n "Volume issues before: "
wc -l $Volume_Issues_File
echo -n "Volume issues after: "
sleep 1
#nova volume-list --all-tenants 1 | egrep 'creating|deleting|detaching|available|error' | wc -l
nova volume-list --all-tenants 1 | grep -i delet | wc -l
#nova volume-list --all-tenants 1 | egrep -v in-use | wc -l

# Set a volume as detached in Cinder via MySQL
# update cinder.volumes set attach_status='detached',status='available' where id ='$volume_uuid';

# nova volume-detach $vm_uuid $volume_uuid
# Detach a volume from Nova via MySQL
# delete from block_device_mapping where not deleted and volume_id='$volume_uuid' and project_id='$project_uuid';

# cinder delete $volume_uuid
# Delete a volume from Cinder via MySQL
# update volumes set deleted=1,status='deleted',deleted_at=now(),updated_at=now() where deleted=0 and id='$volume_uuid';
