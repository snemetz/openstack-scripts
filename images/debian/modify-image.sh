#!/bin/bash

mntpt='/tmp/mnt'

cd /tmp

# Mount Raw Image
image=$(ls -1 *.raw)
dev=$(losetup -f)
losetup $dev $image
part=$(kpartx -av $dev | awk '{ print $3 }' )
mkdir -p $mntpt
mount /dev/mapper/$part $mntpt

# Edit Image
sed -i '/^disable_root/ s/true/false/' $mntpt/etc/cloud/cloud.cfg

# Unmount Image
umount $mntpt
# ? tune2fs
kpartx -d $dev
losetup -d $dev

# Convert image
qemu-img convert  -c -f raw $image -O qcow2 $(echo $image | sed 's/\.raw/.qcow2/')
