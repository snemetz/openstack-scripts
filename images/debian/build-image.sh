#!/bin/bash
#
# Build a Debian 7 (wheezy) image for OpenStack
#
# Requirements - Steps

# Create a Debian system
#   http://thornelabs.net/2014/04/07/create-a-kvm-based-debian-7-openstack-cloud-image.html
# Setup backports repo
#   echo 'deb http://ftp.debian.org/debian wheezy-backports main' >> /etc/apt/sources.list
#   apt-get update
# Install 
#   apt-get install openstack-debian-images
# Run this script to build new image


# edit /usr/sbin/build-openstack-debian-image - add --force-yes to apt-get upgrade
cd /tmp
build-openstack-debian-image -r wheezy --hook-script /root/bootlogd-console-fix.sh --extra-packages curl
