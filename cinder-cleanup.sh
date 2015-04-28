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

tmpdir='/tmp'
Volume_Issues_File='issues-volume'

MYSQL_HOST='172.22.192.2'
MYSQL_USER='nova'
MYSQL_PASSWORD='xSuJDU6b'
MYSQL_CINDER_USER='cinder'
MYSQL_CINDER_PASSWORD='ERIVQgf6'
MYSQL_NOVA_USER='nova'
MYSQL_NOVA_PASSWORD='xSuJDU6b'
script_volume_delete="${tmpdir}/local-volume-delete.sh"

mysql_call () {
  local MySQL_Host=$1
  local MySQL_User=$2
  local MySQL_Password=$3
  local SQL=$4
  local MySQL_Verbose=$5
  local SQL_Results

  #echo -e "\tApplying SQL for $MySQL_User..." 1>&2
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
  local SQL="$4"
  local SQL_Results

  SQL_Results=$(mysql_call $MySQL_Host $MySQL_User $MySQL_Password "$SQL" 'Metrics' )
  Result_Matches=$(echo "$SQL_Results" | egrep '(row in)? set' | awk '{ print $1 }') 
  # Empty set or 1 row in set OR UUID ( hex{8}-hex{4}-hex{4}-hex{4}-hex{12} )
  #echo -e "\tSQL Query Results= ${Result_Matches}"
  if [ "${Result_Matches}" != "1" ]; then
    echo -e "\tWARNING: $MySQL_User DB query didn't return 1 match" 1>&2
    return 1
  fi
  return 0
}

mysql_update () {
  local MySQL_Host=$1
  local MySQL_User=$2
  local MySQL_Password=$3
  local SQL=$4
  local SQL_Results

  #echo -e "\tApplying SQL update for $MySQL_User..."

  SQL_Results=$(mysql_call $MySQL_Host $MySQL_User $MySQL_Password "$SQL" 'Metrics' )
  Result_Stats=($(echo "$SQL_Results" | grep 'Rows matched:' | awk -F: '{ print $2$3$4 }' | awk '{ print $1" "$3" "$5 }'))
  #echo -e "\tSQL Update Results= ${Result_Stats[*]}"
  # if [ "${Result_Stats[@]:0:2}" == "1 1" ]; then # All Good - DOESN'T WORK, complains about too many arguments
  if [ ${Result_Stats[0]} -eq 1 -a ${Result_Stats[1]} -eq 0 ]; then
    echo -e "\tWARNING: $MySQL_User DB query matched but didn't change anything" 1>&2
    return 1
  elif [ ${Result_Stats[0]} -eq 0 ]; then
    echo -e "\tWARNING: $MySQL_User DB query didn't match anything" 1>&2
    return 2
  fi
  if [ ${Result_Stats[2]} -ne 0 ]; then
    echo -e "\tWARNING MySQL: $SQL_Results" 1>&2
    return 3
  fi
  return 0
}

volume_delete () {
  local Volume_UUID=$1
  # host, iscsi target, 
  echo -e "\tDeleting Volume: $Volume_UUID"
  ((count_delete++))
  SQL="select id from nova.block_device_mapping where not deleted and volume_id = '$Volume_UUID';"
  mysql_query $MYSQL_HOST $MYSQL_NOVA_USER $MYSQL_NOVA_PASSWORD "$SQL"
  if [ $? -eq 0 ]; then
    SQL="update nova.block_device_mapping set deleted_at=now(),updated_at=now(),deleted=id where not deleted and volume_id='$Volume_UUID';"
    mysql_update $MYSQL_HOST $MYSQL_NOVA_USER $MYSQL_NOVA_PASSWORD "$SQL"
    if [ $? -ne 0 ]; then
      echo -e  "\tERROR: Update of nova.block_device_mapping for Volume=$Volume_UUID failed"
    fi
  fi
  SQL="select id from cinder.volumes where id = '$Volume_UUID' and not attach_status='detached';"
  mysql_query $MYSQL_HOST $MYSQL_CINDER_USER $MYSQL_CINDER_PASSWORD "$SQL"
  if [ $? -eq 0 ]; then
    SQL="update cinder.volumes set updated_at=now(),attach_status='detached',attached_host=NULL,status='available' where id ='$Volume_UUID' and not attach_status='detached';"
    mysql_update $MYSQL_HOST $MYSQL_CINDER_USER $MYSQL_CINDER_PASSWORD "$SQL"
    if [ $? -ne 0 ]; then
      echo -e "\tERROR: Update of cinder.volumes for Volume=$Volume_UUID failed"
    fi
  fi

  cinder reset-state --state available $Volume_UUID
  cinder force-delete $Volume_UUID
  # Test if gone, if not manual clean (db, iscsi, lvm)
  # If not delete
    # delete in database
    # mysql -e "update cinder.volumes set updated_at=now(),deleted_at=now(),terminated_at=now(),mountpoint=NULL,instance_uuid=NULL,status='deleted',deleted=1 where deleted=0 and id='$volume_uuid';"
    # cleanup host
    # ssh root@$host
  if [ 1 -eq 2 ]; then
  # Code here and in instance-single-cleanup.sh should match once fully working
  cat >$script_volume_delete <<SCRIPT   
#!/bin/bash
    #Get iSCSI target ID
    target=\$(tgt-admin -s | grep $Volume_UUID | grep Target | awk '{ print \$2 }' | cut -d: -f1)
    #Offline it
    tgt-admin --offline tid=\$target
    # Get open connections
    sessions=\$(tgtadm --lld iscsi --op show --mode conn --tid \$target | grep ^Session | awk '{ print \$2 }')
    # Close connections
    for ssession in sessions; do
      tgtadm --lld iscsi --op delete --mode conn --tid \$target --sid \$session
    done
    # Delete LUN
     tgtadm --lld iscsi --op delete --mode target --tid \$target
    # Delete target file
    rm /var/lib/cinder/volumes/volume-$Volume_UUID
    # Delete Logical Volume
    lvremove -f cinder/volume-$Volume_UUID
    # Cleanup stale connection
    #iscsiadm -m node -T <target name> -p <cinder host>:<port> -u
SCRIPT
  fi
}

instance_cleanup () {
  #===================================================
  # Cleanup all volumes attached to instances that do not exist
  #===================================================
  echo -e "Cleaning volumes attached to non-existing instances..."
  # This is very slow. All queries to database instead of API would probably be much faster
  #   Change nova show to a database query
  # cinder list --all-tenants 1 --status=in-use | grep in-use | awk '{ print $2 }'
  SQL="select id,host,instance_uuid,status,attach_status,provider_location from cinder.volumes where not deleted and status='in-use';"
  results=$(mysql_call $MYSQL_HOST $MYSQL_CINDER_USER $MYSQL_CINDER_PASSWORD "$SQL" )
  total_volumes=$(echo "$results" | wc -l)
  #echo "$results"
  for Instance in $(echo "$results" | awk '{ print $3 }' | sort -u); do
    echo -e "\tProcessing instance: $Instance"
    ((total_instances++))
    SQL="select id from nova.instances where not deleted and uuid = '$Instance';"
    #nova show $Instance > /dev/null
    mysql_query $MYSQL_HOST $MYSQL_NOVA_USER $MYSQL_NOVA_PASSWORD "$SQL"
    if [ $? -ne 0 ]; then
      # If not found
      ((count_instance_nonexist++))
      for Volume in $(echo "$results" | grep $Instance | awk '{ print $1 }'); do
        ((count_volume_nonexist++))
        volume_delete $Volume
      done
    fi
  done
}

volume_available_cleanup () {
  #===================================================
  # Cleanup all volumes in available state for too long
  #===================================================
  echo -e "Cleaning volumes in available..."
  # cinder list --all-tenants 1 --status=available | grep creating | awk '{ print $2 }'
  SQL="select id from cinder.volumes where not deleted and status='available' and date_add(updated_at, interval 20 minute) <= now();"
  results=$(mysql_call $MYSQL_HOST $MYSQL_CINDER_USER $MYSQL_CINDER_PASSWORD "$SQL" )
  for Volume in $results; do
    ((count_available++))
    volume_delete $Volume
  done
}

volume_creating_cleanup () {
  #===================================================
  # Cleanup all volumes in creating state for too long
  #===================================================
  echo -e "Cleaning volumes stuck in creating..."
  # cinder list --all-tenants 1 --status=creating | grep creating | awk '{ print $2 }'
  SQL="select id from cinder.volumes where not deleted and status='creating' and date_add(updated_at, interval 20 minute) <= now();"
  results=$(mysql_call $MYSQL_HOST $MYSQL_CINDER_USER $MYSQL_CINDER_PASSWORD "$SQL" )
  for Volume in $results; do
    ((count_creating++))
    volume_delete $Volume
  done
}

cinder_cleanup () {
  ### Cleanup cinder volumes via nova (or cinder)
  # Status values:
  #    attaching, available, backing-up, creating, deleting, detaching, error, error_deleting, error_extending, error_restoring, in-use, restoring-backup, 

  count_available=0
  count_creating=0
  count_instance_nonexist=0
  count_volume_nonexist=0
  count_delete=0
  total_instances=0
  total_volumes=0

  volume_available_cleanup
  volume_creating_cleanup
  instance_cleanup 

  echo -e "\nVolumes in available to cleanup:\t$count_available"
  echo -e "Volumes stuck in creating to cleanup:\t$count_creating"
  echo -e "Volumes with non-existing instances:\t$count_volume_nonexist"
  echo -e "Total volumes to delete:\t\t$count_delete"
  echo -e "Total volumes:\t\t\t\t$total_volumes"
  echo -e "Total instances that did not exist:\t$count_instance_nonexist"
  echo -e "Total instances checked:\t\t$total_instances"

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
  # nova volume-detach $vm_uuid $volume_uuid
  
  #nova volume-list --all-tenants 1 | grep -i delet | awk '{ print $2 }' | tee $Volume_Issues_File | xargs -n1 cinder reset-state --state error
  #for V in `cat $Volume_Issues_File`; do nova volume-delete $V; done
}

echo "Starting volume error cleanup via CLI..."
cinder_cleanup
echo "Finished cleaning via cinder/nova"
exit

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
