#!/bin/bash
#
# Collect resource data from OpenStack Hypervisor nodes and OpenStack Database
#
dir_tmp='/tmp'
dir_data="${dir_tmp}/openstack-data"

mkdir -p $dir_data

### Get data from hypervisor nodes
#hypervisors=`nova hypervisor-list | awk -F \| '/node/ { print $3 }' | cut -d. -f1 | sort`
hypervisors=$(nova service-list | grep nova-compute | grep ' up ' | awk '{ print $6 }' | sort -u)

# Process: loop on hypervisor list
# Get remote data
#if [ 1 == 2 ]; then
  for H in $hypervisors; do
    echo "Collecting data from: $H..."
    scp -q report-node-resources.sh root@$H:
    ssh root@$H ./report-node-resources.sh
    scp -q root@$H:openstack.data $dir_data/$H-data
  done
#fi

#if [ 1 == 2 ]; then
  ### Get OpenStack data
  # Get list of all instances on all hosts
	# ADD: fixed, floating - find field names
  nova list --all-tenants 1 --fields name,host,instance_name,status,OS-EXT-STS:vm_state,task_state,power_state,created > $dir_data/openstack-instances
  # Get list of all floating IPs on host
  #	Displays project id, floating ip, instance uuid, pool, interface
  for H in $hypervisors; do
    nova floating-ip-bulk-list --host $H | egrep -v 'address|\+' | awk '{ print $4 }' | sort > $dir_data/openstack-floating-ips-$H
  done

  ## Get list of all fixed IPs on host
  #MySQL: select address from nova.fixed_ips where host = '';
  # | egrep -v 'address|rows|+' | awk '{ print $2 }'
  #MySQL: select address from nova.floating_ips where host = '';
  # | egrep -v 'address|rows|+' | awk '{ print $2 }'
#fi

#if [ 1 == 2 ]; then
  ### Parse data from hypervisor nodes
  for H in $hypervisors; do
    # Parse $H-data
    # === <resource name>
    sep='^=== (.+)'
    while read -r; do
      line=$REPLY
      if [[ $line =~ $sep ]]; then
        # Found seperator ===, process section
        file=$H-${BASH_REMATCH[1]}
        cp /dev/null $dir_data/$file
      elif [ -n "$file" ]; then
       echo $line >> $dir_data/$file
      fi
    done < $dir_data/$H-data
  done
#fi

# Compare data
for H in $hypervisors; do
  # Compare floating IPs
  echo "$H compare floating IPs..."
  diff --from-file=${dir_data}/${H}-ip_addr ${dir_data}/${H}-iptables_OUTPUT ${dir_data}/${H}-iptables_POSTROUTING ${dir_data}/${H}-iptables_PREROUTING ${dir_data}/${H}-iptables_float-snat ${dir_data}/openstack-floating-ips-${H} | egrep '<|>' | sed 's/[<>]/-/' |sort -u
  # Compare instances
  echo "$H compare instances..."
  tmpnwfile="${dir_tmp}/${H}-nw-$$"
  tmpinstfile="${dir_tmp}/${H}-inst-$$"
  cat ${dir_data}/${H}-virsh_nwfilter | cut -d- -f1-2 > $tmpnwfile
  grep $H ${dir_data}/openstack-instances | awk '{ print $8 }' | sort > $tmpinstfile
  diff --from-file=${dir_data}/${H}-virsh_list $tmpnwfile $tmpinstfile | egrep '<|>' | sed 's/[<>]/-/' | sort -u
  #rm $tmpnwfile $tmpinstfile
done > TO-FIX-resources-mismatch-`date +%Y-%m-%d-%H-%M`
