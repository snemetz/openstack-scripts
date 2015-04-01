#!/bin/bash

# Create a Debian 7 KVM VM
# Login will be: root/debian

virt-install --virt-type kvm --name debian-7 --ram 1024 --location=http://ftp.debian.org/debian/dists/wheezy/main/installer-amd64/ --disk path=/tmp/debian-7-amd64-vm.img,size=5 --network network=default --graphics vnc,listen=0.0.0.0 --noautoconsole --os-type=linux --os-variant=debianwheezy --extra-args="priority=critical interface=auto debian-installer/language=en debian-installer/country=US debian-installer/locale=en_US keymap=us preseed/url=http://public.thornelabs.net/debian-7-wheezy-preseed.seed"

