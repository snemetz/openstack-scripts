#!/bin/bash
#
# Report on all in-use cinder volumes that are attached to instances that do not exist
#
# Author: Steven Nemetz
# snemetz@hotmail.com

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
  #echo -e "\tVerbose='$verbose'" 1>&2
  SQL_Results=$(mysql -h $MySQL_Host -u $MySQL_User -p$MySQL_Password $verbose --batch --skip-column-names -e "$SQL" 2>/dev/null)
  #SQL_Results=$(mysql -h $MySQL_Host -u $MySQL_User -p$MySQL_Password $verbose --batch --skip-column-names -e "$SQL")
  echo "$SQL_Results"
}

#===================================================
# Volumes attached to instances that do not exist
#===================================================
SQL="select id,host,instance_uuid,status,attach_status,provider_location from cinder.volumes where not deleted and status='in-use';"
results=$(mysql_call $MYSQL_HOST $MYSQL_CINDER_USER $MYSQL_CINDER_PASSWORD "$SQL" )
echo "$results"
count=0
for Instance in $(echo "$results" | awk '{ print $3 }' | sort -u); do
  echo $Instance
  nova show $Instance > /dev/null
  if [ $? -ne 0 ]; then
    ((count++))
    #for Volume in $(echo "$results" | grep $Instance | awk '{ print $1 }')
    #  cinder reset-status --state available $Volume
    #  cinder force-delete $Volume
    #done
  fi
done

#===================================================
# Volumes in creating state for too long
#===================================================
SQL="select id,host,instance_uuid,status,attach_status,provider_location from cinder.volumes where not deleted and status='creating' and date_add(updated_at, interval 20 minute) <= now();"

echo "Total Volumes: $(echo "$results" | wc -l)"
echo "Total Instances: $(echo "$results" | awk '{ print $3 }' | sort -u | wc -l)"
echo "Instances that do not exist: $count"
