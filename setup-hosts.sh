#!/bin/bash
#
# Setup for Nova hypervisor and cinder storage hosts

delay=5
dirtmp='/tmp'
script_host_setup="${dirtmp}/host-setup.sh"

hypervisors=$(nova service-list | grep nova-compute | grep ' up ' | awk '{ print $6 }' | sort -u)

cat > $script_host_setup <<SCRIPT
#!/bin/bash

do_ubuntu=''
do_cinder=''
do_nova='1'

#=====================
# Additional system setup - Ubuntu
#=====================
if [ -n "\$do_ubuntu" ]; then
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
fi

#=====================
# Cinder setup
#=====================
if [ -n "\$do_cinder" ]; then
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
fi

#=====================
# Nova setup
#=====================
if [ -n "\$do_nova" ]; then
  which crudini 1>/dev/null 2>&2
  if [ \$? -eq 0 ]; then
    crudini --set /etc/nova/nova.conf DEFAULT resume_guests_state_on_host_boot True
    crudini --set /etc/nova/logging.conf logger_nova level DEBUG
    crudini --set /etc/nova/nova.conf DEFAULT debug True
    #crudini --set /etc/nova/rootwrap.conf DEFAULT use_syslog True
    #crudini --set /etc/nova/rootwrap.conf DEFAULT syslog_log_level INFO
    #crudini --set /etc/nova/rootwrap.conf DEFAULT syslog_log_facility local6
    # Juno
    for Service in nova-api nova-compute nova-network; do
      service \$Service restart
    done
  else
    echo "ERROR: crudini not found!"
  fi
fi
SCRIPT
chmod +x $script_host_setup

for H in $hypervisors; do
  echo "Updating $H..."
  scp $script_host_setup root@$H:
  ssh root@$H ./$(basename $script_host_setup)
  if [ $delay -gt 0 ]; then
    sleep $delay
  fi
done
