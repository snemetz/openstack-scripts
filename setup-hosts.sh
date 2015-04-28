#!/bin/bash
#
# Setup for Nova hypervisor and cinder storage hosts

dirtmp='/tmp'
script_host_setup="${dirtmp}/host-setup.sh"

hypervisors=$(nova service-list | grep nova-compute | grep ' up ' | awk '{ print $6 }' | sort -u)

cat > $script_host_setup <<SCRIPT
#!/bin/bash

#=====================
# Additional system setup - Ubuntu
#=====================
# apt-get install -y chkconfig linux-crashdump lldpd inetutils-traceroute python-pip tcptraceroute libguestfs-tools virt-top
# pip install crudini
apt-get install -q -y sysstat
sed -i '/ENABLED=/ s/=.*/="true"/' /etc/default/sysstat
service sysstat restart

#=====================
# Cinder setup
#=====================
# Make sure cinder starts when system boots
if [ -f /etc/init/cinder-volume.override ]; then
  echo "Removing cinder autostart override"
  rm /etc/init/cinder-volume.override
fi

# Cinder using iscsi
#sysctl -p | grep -q kernel.sem 1>/dev/null 2>&1
kernel_sem='250 256000 32 4096'
grep -q ^kernel.sem /etc/sysctl.conf 1>/dev/null 2>&1
if [ \$? -eq 0 ]; then
  sed -i "/^kernel.sem/ s/=.*/=\$kernel_sem/" /etc/sysctl.conf
else
  echo "kernel.sem=\$kernel_sem" >> /etc/sysctl.conf
fi
sysctl -p

#=====================
# Nova setup
#=====================
which crudini 1>/dev/null 2>&2
if [ \$? -eq 0 ]; then
  crudini --set /etc/nova/nova.conf DEFAULT resume_guests_state_on_host_boot True
else
  echo "ERROR: crudini not found!"
fi

SCRIPT
chmod +x $script_host_setup

for H in $hypervisors; do
  scp $script_host_setup root@$H:
  ssh root@$H ./$(basename $script_host_setup)
done
