#!/bin/bash
#
# Cleanup Openstack hypervisor host to make consistant with itself.
#   NOTE: this only checks the host, NOT the OpenStack database
#	Cleanup KVM nwfilers that VMs don't exist
#	Cleanup Floating IPs that have no NATs
#	Cleanup instances kvm & nova instances should match - remove what doesn't
#
# Author: Steven Nemetz
# snemetz@hotmail.com

# TODO:
#	Cleanup cinder/iscsi inconsistances

DEBUG=1
ACTION=0

echo "Processing $HOSTNAME..."

tmpdir='/tmp/cleanup'
mkdir -p $tmpdir

###========================================================
### Check if Nova and KVM agree on the number of instances
###========================================================
if [ $DEBUG == 1 ]; then
  echo "Checking number of KVM VMs and Nova Instances match..."
fi
Instances=`virsh list --all --name | sed '/^$/ d'`
Instance_UUIDs=$(ls -1d /var/lib/nova/instances/*-* 2>/dev/null | cut -d/ -f6)
Instances_Nova=''
#echo "VM=$(echo '$Instances' | wc -l), Nova=$(echo '$Instance_UUIDs' | wc -l)"
if [ $(echo "$Instance_UUIDs" | wc -l) -ne $(echo "$Instances" | wc -l) ]; then
  if [ $DEBUG == 1 ]; then
    echo -e "\tNumber Nova and KVM instances do NOT match - Cleaning Nova Instances..."
  fi
  #--------------------------------------------------------
  # Cleanup nova instances that do not have a matching VM
  #--------------------------------------------------------
  for UUID in $Instance_UUIDs; do
    if [ -f /var/lib/nova/instances/${UUID}/libvirt.xml ]; then
      vm_name=$(grep '<name>' /var/lib/nova/instances/${UUID}/libvirt.xml | awk -F'name>' '{ print $2 }' | sed 's/..$//')
      # Build list of names
      Instances_Nova+=" $vm_name"
    else
      vm_name='INSTANCE_TO_CLEANUP'
    fi
    if ! [[ $Instances =~ $vm_name ]]; then
      # If there is NOT a VM for the nova instance, remove the nova instance
      if [ $DEBUG == 1 ]; then
        echo -e "\tRemoving Nova Instance: $UUID"
      fi
      if [ $ACTION == 1 ]; then
        rm -rf /var/lib/nova/instances/${UUID}
      fi
    fi
  done
  #--------------------------------------------------------
  # Cleanup KVM VMs that do not have a Nova Instance
  # TODO: Still need to test this code
  #--------------------------------------------------------
  for Instance_Name in $Instances; do
    if ! [[ $Instances_Nova =~ $Instance_Name ]]; then
      # If there is NOT a nova instance for the VM, remove the VM
      if [ $DEBUG == 1 ]; then
        echo -e "\tRemoving KVM VM: $Instance_Name"
      fi
      if [ $ACTION == 1 ]; then
        echo "TODO: virsh undefine $Instance_name"
      fi
    fi
  done
fi

###========================================================
### Cleanup KVM nwfilters for instances that no longer exist
###========================================================
for F in `virsh nwfilter-list | grep instance | awk '{ print $2 }'`; do
  nwf=`echo $F | cut -d- -f3-4`
  if [ $DEBUG == 1 ]; then
     echo "Checking nwfilter: $nwf"
  fi
  # Need if nwfilter is not in Instances
  if ! [[ $Instances =~ $nwf ]]; then
    if [ $DEBUG == 1 ]; then
      echo -e "\tRemoving nwfilter: $F"
    fi
    if [ $ACTION == 1 ]; then
      virsh nwfilter-undefine $F
    fi
  fi
done

###========================================================
### Cleanup NATs that do not have an nwfilter with the instance (fixed) ip
###========================================================
echo "Checking NATs have corresponding nwfilters..."
grep IP /etc/libvirt/nwfilter/nova-instance-* 2>/dev/null | awk '{ print $4 }' | cut -d= -f2 | cut -c2- | sed 's#...$##' | sort > $tmpdir/nwfilter-ips
# Get current iptables NAT floating-snat
iptables -n -t nat -L nova-network-float-snat | egrep -v 'Chain|target' | awk '{ print $4 }' | sort -u > $tmpdir/float-snat-local-ips
for IP in `diff $tmpdir/nwfilter-ips $tmpdir/float-snat-local-ips | grep '>' | awk '{ print $2 }'`; do
  if [ $DEBUG == 1 ]; then
    echo -e "\tRemoving NAT rules for: $IP"
  fi
  if [ $ACTION == 1 ]; then
    # Check that rules are valid
    iptables -S -t nat | grep $IP | sed 's/^-A/-C/' | xargs -L1 iptables --table nat
    if [ $? -eq 0 ]; then
      # Delete rules
      iptables -S -t nat | grep $IP | sed 's/^-A/-D/' | xargs -L1 iptables --table nat
    else
      echo -e "\tERROR: rules failed check - NOT deleted"
    fi
    # service iptables save
    # service iptables restart
  fi
done

###========================================================
### Cleanup Floating IPs that do not have a matching NAT
###========================================================
# Get current live floating IPs
ip addr show scope global eth2.519 | grep inet | awk '{ print $2 }' | grep '/32' | cut -d/ -f1 | sort > $tmpdir/ips
# Get current iptables NAT floating-snat
iptables -n -t nat -L nova-network-float-snat | egrep -v 'Chain|target' | awk '{ print $6 }' | grep -v '^$' | cut -d: -f2 | sort -u > $tmpdir/float-snat
# Get current iptables NAT OUTPUT
iptables -n -t nat -L nova-network-OUTPUT | egrep -v 'Chain|target' | awk '{ print $5 }' | grep -v '^$' | sort -u > $tmpdir/OUTPUT
# Get current iptables NAT PREROUTING
iptables -n -t nat -L nova-network-PREROUTING | egrep -v 'Chain|target' | awk '{ print $5 }' | egrep -v '^169\.|^$' | sort -u > $tmpdir/PREROUTING
# Get current iptables NAT POSTROUTING
iptables -n -t nat -L nova-network-POSTROUTING | egrep -v 'Chain|target' | grep ^SNAT | awk '{ print $8 }' | grep -v '^$' | cut -d: -f2 | sort -u > $tmpdir/POSTROUTING
diff -q --from-file=$tmpdir/float-snat $tmpdir/OUTPUT $tmpdir/PREROUTING $tmpdir/POSTROUTING
if [ $? == 0 ]; then
  if [ $DEBUG == 1 ]; then
    echo "NATs consistent - OK to proceed"
    echo "Floating IP cleanup..."
  fi
  for IP in `diff $tmpdir/float-snat $tmpdir/ips | grep '>' | awk '{ print $2 }' | sort`; do
    if [ $DEBUG == 1 ]; then
      echo -e "\tRemoving IP: ${IP}/32 from eth2.519"
    fi
    if [ $ACTION == 1 ]; then
      ip addr del ${IP}/32 dev eth2.519
    fi
  done
else
  echo "ERROR: NATs inconsistent"
fi
