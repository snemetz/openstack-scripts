#!/bin/bash
#
# Setup Kernel Crash Dump
#

#============
# Ubuntu
#============
# Mirantis Fuel install all nodes go to fuel master as only repo - FIX
apt-get install linux-crashdump
if [ $(cat /proc/sys/kernel/sysrq) -eq 0 ]; then
  sysctl -w kernel.sysrq=1
fi

exit

# Reboot is required
# verify after reboot
#grep crashkernel /proc/cmdline

# Installing tools to analyze crash dumps
sudo tee /etc/apt/sources.list.d/ddebs.list << EOF
deb http://ddebs.ubuntu.com/ $(lsb_release -cs)          main restricted universe multiverse
deb http://ddebs.ubuntu.com/ $(lsb_release -cs)-security main restricted universe multiverse
deb http://ddebs.ubuntu.com/ $(lsb_release -cs)-updates  main restricted universe multiverse
deb http://ddebs.ubuntu.com/ $(lsb_release -cs)-proposed main restricted universe multiverse
EOF

sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys ECDCAD72428D7C01
sudo apt-get update
sudo apt-get install linux-image-$(uname -r)-dbgsym

