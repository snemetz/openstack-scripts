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
# Setup repos to get around Mirantis Fuel setup
#--------------------
srcfile='/etc/apt/sources.list'
os_name=\$(lsb_release -sc)
# Setup All Repositories
cat >> \$srcfile <<REPOS

deb http://us.archive.ubuntu.com/ubuntu/ \${os_name} main restricted universe multiverse
deb http://us.archive.ubuntu.com/ubuntu/ \${os_name}-updates main restricted universe multiverse
deb http://us.archive.ubuntu.com/ubuntu/ \${os_name}-backports main restricted universe multiverse
deb http://us.archive.ubuntu.com/ubuntu/ \${os_name}-security main restricted universe multiverse
REPOS

apt-get update
# For nova-compute:
apt-get install -y sysfsutils
# To help manage systems:
#apt-get install -y chkconfig linux-crashdump lldpd inetutils-traceroute python-pip tcptraceroute libguestfs-tools sysstat virt-top
#pip install crudini
#sed -i '/ENABLED=/ s/=.*/="true"/' /etc/default/sysstat
#service sysstat restart

#--------------------
# Cleanup from kluge for Mirantis Fuel environment
#--------------------
sed -i '/^deb http:\/\/us.archive/ d' \$srcfile
apt-get update

exit

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
