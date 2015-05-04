#!/bin/bash
#
# Setup changes for Controller nodes

dirtmp='/tmp'
script_ctrl_setup="${dirtmp}/setup-controller.sh"

controllers=$(nova service-list | grep nova-conductor | grep ' up ' | awk '{ print $6 }' | sort -u)

cat > $script_ctrl_setup <<SCRIPT
#!/bin/bash

do_ubuntu=''
do_cinder='1'
do_glance=''
do_nova=''

if [ 1 -eq 2 ]; then
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
# To help manage systems:
apt-get install -y chkconfig lldpd inetutils-traceroute python-pip tcptraceroute sysstat 
pip install crudini
sed -i '/ENABLED=/ s/=.*/="true"/' /etc/default/sysstat
service sysstat restart

#--------------------
# Cleanup from kluge for Mirantis Fuel environment
#--------------------
sed -i '/^deb http:\/\/us.archive/ d' \$srcfile
apt-get update
fi

#=====================
# Cinder setup
#=====================
# /etc/cinder/cinder.conf
#[DEFAULT]
# osapi_max_limit=5000
# /etc/cinder/logging.conf
#[logger_root]
#level = WARNING
#[logger_cinder]
#level = INFO
#[logger_amqplib]
#level = WARNING
#[logger_sqlalchemy]
#level = WARNING
#[logger_boto]
#level = WARNING
#[logger_suds]
#level = INFO
#[logger_eventletwsgi]
#level = WARNING
if [ -n "\$do_cinder" ]; then
crudini --set /etc/cinder/cinder.conf DEFAULT osapi_max_limit 5000
crudini --set /etc/cinder/logging.conf logger_cinder level INFO
crudini --set /etc/cinder/logging.conf logger_sqlalchemy level INFO
# Juno
for Service in cinder-api cinder-scheduler; do
  service \$Service restart
done
fi

#=====================
# Glance setup
#=====================
# /etc/glance/glance-api.conf
#[DEFAULT]
#verbose = True
#debug = False

#=====================
# Nova setup
#=====================
# /etc/nova/nova.conf
#[DEFAULT]
#osapi_max_limit=5000
# /etc/nova/logging.conf
#[logger_root]
#level = WARNING
#[logger_nova]
#level = INFO
#[logger_amqp]
#level = WARNING
#[logger_amqplib]
#level = WARNING
#[logger_sqlalchemy]
#level = WARNING
#[logger_boto]
#level = WARNING
#[logger_suds]
#level = INFO
#[logger_eventletwsgi]
#level = WARNING
if [ -n "\$do_nova" ]; then
crudini --set /etc/nova/nova.conf DEFAULT osapi_max_limit 5000
crudini --set /etc/nova/logging.conf logger_nova level DEBUG
crudini --set /etc/nova/logging.conf logger_amqp level INFO
crudini --set /etc/nova/logging.conf logger_amqplib level INFO
crudini --set /etc/nova/logging.conf logger_sqlalchemy level INFO
# Juno
for Service in nova-api nova-cert nova-consoleauth nova-novncproxy nova-objectstore nova-scheduler nova-conductor; do
  service \$Service restart
done
fi

SCRIPT

chmod +x $script_ctrl_setup

for H in $controllers; do
  echo "Controller: $H"
  scp $script_ctrl_setup root@$H:
  ssh root@$H ./$(basename $script_ctrl_setup)
done
