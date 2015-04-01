#!/bin/bash
#
# Collect data from an OpenStack Hypervisor node
#
### Remote script
output="openstack.data"
echo "=== ip_addr" > $output
ip addr show scope global eth2.519 | grep inet | awk '{ print $2 }' | grep '/32' | cut -d/ -f1 | sort >> $output
echo "=== iptables_float-snat" >> $output
iptables -n -t nat -L nova-network-float-snat | egrep -v 'Chain|target' | awk '{ print $6 }' | grep -v '^$' | cut -d: -f2 | sort -u >> $output
echo "=== iptables_OUTPUT" >> $output
iptables -n -t nat -L nova-network-OUTPUT | egrep -v 'Chain|target' | awk '{ print $5 }' | grep -v '^$' | sort -u >> $output
echo "=== iptables_PREROUTING" >> $output
iptables -n -t nat -L nova-network-PREROUTING | egrep -v 'Chain|target' | awk '{ print $5 }' | egrep -v '^169\.|^$' | sort -u >> $output
echo "=== iptables_POSTROUTING" >> $output
iptables -n -t nat -L nova-network-POSTROUTING | egrep -v 'Chain|target' | grep ^SNAT | awk '{ print $8 }' | grep -v '^$' | cut -d: -f2 | sort -u >> $output
echo "=== virsh_list" >> $output
virsh list --all --name | sed '/^$/ d' >> $output
echo "=== virsh_nwfilter" >> $output
virsh nwfilter-list | grep nova-instance- | awk '{ print $2 }' | cut -d- -f3-5 >> $output
#ls -1 /etc/libvirt/nwfilter/nova-instance-* | cut -d- -f3-4
