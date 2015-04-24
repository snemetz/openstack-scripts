#!/bin/bash
#
# Check all hypervisors for shut off instances and remove if they are not in the OpenStack database
# Maybe verify all instances
#
# Author: Steven Nemetz
# snemetz@hotmail.com

dirtmp='/tmp'
script_host_cleanup="${dirtmp}/host-cleanup-instances.sh"

MYSQL_HOST='172.22.192.2'
MYSQL_CINDER_USER='cinder'
MYSQL_CINDER_PASSWORD='ERIVQgf6'
MYSQL_NOVA_USER='nova'
MYSQL_NOVA_PASSWORD='xSuJDU6b'

mysql_call () {
  local MySQL_Host=$1
  local MySQL_User=$2
  local MySQL_Password=$3
  local SQL="$4"
  local MySQL_Verbose=$5
  local SQL_Results

  #echo -e "\tApplying SQL for $MySQL_User..." 1>&2
  #echo -e "\tSQL:$SQL" 1>&2
  verbose=''
  if [ -n "$MySQL_Verbose" ]; then
    verbose='--verbose --verbose'
  fi
  SQL_Results=$(mysql -h $MySQL_Host -u $MySQL_User -p$MySQL_Password $verbose --batch --skip-column-names -e "$SQL" 2>/dev/null)
  #echo "mysql_call: $SQL_Results" 1>&2
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
  #echo -e "\tSQL Results= ${Result_Matches}"
  if [ "${Result_Matches}" != "1" ]; then
    #echo -e "\tWARNING: DB query didn't return 1 match"
    return 1
  fi
  return 0
}

cleanup_hypervisors=''
hypervisors=$(nova service-list | grep nova-compute | grep ' up ' | awk '{ print $6 }' | sort -u)
for hypervisor in $hypervisors; do
  echo "Processing hypervisor: $hypervisor"
  cleanup_ids=''
  #hex_ids=$(ssh root@$hypervisor "virsh list --all | grep 'shut off' | awk '{ print \$2 }' | cut -d- -f2")
  hex_ids=$(ssh root@$hypervisor "virsh list --all --name | cut -d- -f2")
  for id in $hex_ids; do
    echo -e "\tProcessing instance $id"
    SQL="select uuid from nova.instances where id = conv('$id', 16, 10);"
    mysql_query $MYSQL_HOST $MYSQL_NOVA_USER $MYSQL_NOVA_PASSWORD "$SQL"
    if [ $? -ne 0 ]; then
      # save all failed ones for cleanup
      cleanup_ids+=" $id"
      echo -e "\t\tTODO: on $hypervisor remove $id"
    fi
  done
  if [ -n "$cleanup_ids" ]; then
    echo -e "\tRemoving ID's $cleanup_ids from $hypervisor"
    cleanup_hypervisors+=" $hypervisor"

    cat > $script_host_cleanup <<SCRIPT
#!/bin/bash

# Remove KVM instances that are not in OpenStack database
for id in $cleanup_ids; do
   virsh undefine instance-\$id
done
# ./host-cleanup.sh # nwfilters, NAT, IPs, nova instance
SCRIPT
    chmod +x $script_host_cleanup 
    scp -q $script_host_cleanup host-cleanup.sh root@$hypervisor:
    #ssh root@$hypervisor "sed -i '/^ACTION=/ s/0/1/' host-cleanup.sh; ./$(basename $script_host_cleanup); ./host-cleanup.sh"
  fi
done
echo "Hypervisors that need cleanup: $cleanup_hypervisors"
