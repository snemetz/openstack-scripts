#!/bin/bash
#
# Cleanup issues in OpenStack
#	volumes, 
#
# REFS:
#	https://raymii.org/s/articles/Fix_inconsistent_Openstack_volumes_and_instances_from_Cinder_and_Nova_via_the_database.html
#
# Author: Steven Nemetz
# snemetz@hotmail.com
#
# TODO:
#	Make seperate scripts
#	add testing, verification - both for what needs to be done and if it succeeded, metric of how much got fixed
#	Add metrics for before and after each clean attempt

Volume_Issues_File='issues-volume'

MYSQL_HOST='172.22.192.2'
MYSQL_USER='nova'
MYSQL_PASSWORD='xSuJDU6b'
MYSQL_CINDER_USER='cinder'
MYSQL_CINDER_PASSWORD='ERIVQgf6'
MYSQL_NOVA_USER='nova'
MYSQL_NOVA_PASSWORD='xSuJDU6b'

mysql_call () {
  local MySQL_Host=$1
  local MySQL_User=$2
  local MySQL_Password=$3
  local SQL=$4
  local MySQL_Verbose=$5
  local SQL_Results

  echo -e "\tApplying SQL for $MySQL_User..." 1>&2
  #echo -e "\tSQL:$SQL" 1>&2
  verbose=''
  if [ -n "$MySQL_Verbose" ]; then
    verbose='--verbose --verbose'
  fi
  SQL_Results=$(mysql -h $MySQL_Host -u $MySQL_User -p$MySQL_Password $verbose --batch --skip-column-names -e "$SQL" 2>/dev/null)
  echo "$SQL_Results"
}

mysql_query () {
  local MySQL_Host=$1
  local MySQL_User=$2
  local MySQL_Password=$3
  local SQL=$4
  local SQL_Results

  #echo -e "\tApplying SQL for $MySQL_User..."

  SQL_Results=$(mysql_call $MySQL_Host $MySQL_User $MySQL_Password "$SQL" 'Metrics' )
  Result_Stats=($(echo "$SQL_Results" | grep 'Rows matched:' | awk -F: '{ print $2$3$4 }' | awk '{ print $1" "$3" "$5 }'))
  #echo -e "\tSQL Results= ${Result_Stats[*]}"
  # if [ "${Result_Stats[*]:0:2}" == "1 1" ]; then
    # Made 1 change
  if [ ${Result_Stats[0]} -eq 1 -a ${Result_Stats[1]} -eq 0 ]; then
    echo -e "\tWARNING: DB query matched but didn't change anything"
    return 1
  elif [ ${Result_Stats[0]} -eq 0 ]; then
    echo -e "\tWARNING: DB query didn't match anything"
    return 2
  fi
  if [ ${Result_Stats[2]} -ne 0 ]; then
    echo -e "\tWARNING MySQL: $SQL_Results"
    return 3
  fi
  return 0
}

volume_delete () {
  local Volume_UUID=$1
  # host, iscsi target, 
  cinder reset-status --state available $Volume_UUID
  cinder force-delete $Volume_UUID
  # Test if gone, if not manual clean (db, iscsi, lvm)
}

instance_cleanup () {
  #===================================================
  # Cleanup all volumes attached to instances that do not exist
  #===================================================
  # This is very slow. All queries to database instead of API would probably be much faster
  #   Change nova show to a database query
  # cinder list --all-tenants 1 --status=in-use | grep in-use | awk '{ print $2 }'
  SQL="select id,host,instance_uuid,status,attach_status,provider_location from cinder.volumes where not deleted and status='in-use';"
  results=$(mysql_call $MYSQL_HOST $MYSQL_CINDER_USER $MYSQL_CINDER_PASSWORD "$SQL" )
  #echo "$results"
  count_instances=0
  count_volumes=0
  for Instance in $(echo "$results" | awk '{ print $3 }' | sort -u); do
    echo $Instance
    SQL="select * from nova.instances where not deleted and id = '$Instance';"
    nova show $Instance > /dev/null
    if [ $? -ne 0 ]; then
      ((count_instance++))
      #for Volume in $(echo "$results" | grep $Instance | awk '{ print $1 }')
      #  ((count_volumes++))
      #  volume_delete $Volume
      #done
    fi
  done
  echo "Instances that do not exist: $count_instances"
  echo "Volumes attempted to delete: $count_volumes"
}

volume_creating_cleanup () {
  #===================================================
  # Cleanup all volumes in creating state for too long
  #===================================================
  # cinder list --all-tenants 1 --status=creating | grep creating | awk '{ print $2 }'
  SQL="select id from cinder.volumes where not deleted and status='creating' and date_add(updated_at, interval 20 minute) <= now();"
  results=$(mysql_call $MYSQL_HOST $MYSQL_CINDER_USER $MYSQL_CINDER_PASSWORD "$SQL" )
  for Volume in $results; do
    volume_delete $Volume
  done
}

cinder_cleanup () {
  ### Cleanup cinder volumes via nova (or cinder)
  # Status values:
  #    attaching, available, backing-up, creating, deleting, detaching, error, error_deleting, error_extending, error_restoring, in-use, restoring-backup, 

  #volume_creating_cleanup
  #instance_cleanup 

  #for Status in detaching error_deleting available; do
  #  for Volume in $(cinder list --all-tenants 1 --status=$Status | grep -v 'ID|[+]' | awk '{ print $2 }'); do
  #    case $Status in
  #      detaching)
  #          ;;
  #      detaching)
  #          ;;
  #      error_deleting)
  #          ;;
  #      *)
  #          echo "ERROR: Unknown volume status: $Status"
  #          ;;
  #    esac
  #  done
  #done
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
