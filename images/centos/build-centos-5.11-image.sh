#!/bin/bash

# Build a CentOS 5 image for OpenStack
#
# References:
#   https://kvad32.wordpress.com/2013/01/18/creating-centos-images-for-openstack/
#   https://www.rdoproject.org/Creating_CentOS_and_Fedora_images_ready_for_Openstack
#   http://auzietech.blogspot.com/2011/08/building-custom-centos-56-image-for.html
#   

iso_path='/mirrors/centos/5.11/isos/x86_64/'
iso_file='CentOS-5.11-x86_64-netinstall.iso'
image_file="$(echo $iso_file | sed 's/-netinstall.iso//').raw"
mirror_site='ftp://ftp.uci.edu'

# Download netboot or minimal ISO
if [ ! -f /tmp/${iso_file} ]; then
  wget ${mirror_site}${iso_path}${iso_file}
  mv ${iso_file} /tmp/${iso_file}
fi

# Create image
## 5.x
#kvm-img create -f raw $image_file 5G
## Boot image
#kvm -m 1024 -cdrom $iso_file -drive file=$image_file,if=scsi,index=0 -boot d -net nic -net user -vnc :0 -usbdevice tablet

# 5.x
qemu-img create -f raw /tmp/${image_file} 5G
virt-install --virt-type kvm --name centos-5.11 --ram 1024 \
--cdrom=/tmp/${iso_file} \
--disk /tmp/${image_file},format=raw \
--graphics vnc,listen=0.0.0.0 --noautoconsole \
--os-type=linux --os-variant=rhel5.4

exit

### Connect to VM via VNC
virsh domdisplay centos-5.11
vnc 5900 + display#

# Answer GUI questions:
Installation method: HTTP
Web Site name: mirror.centos.org
Centos OS Directory: /centos/5.11/os/x86_64

# GUI install
Setup partitions
Set Server Time Zone
Set root password root/centos
Change packages:
- remove Desktop
- add server

# Remove CD / ISO image
virsh change-media centos-5.11 /tmp/${iso_file} --eject
reboot

### Boot VM
virsh start centos-5.11
virsh domdisplay centos-5.11
# Connect VNC
# Find IP so can ssh
ifconfig | grep 'inet addr' | head -n1
# Close VNC and ssh instead

###==============
### Config VM
###==============
chkconfig bluetooth off
chkconfig hidd off
chkconfig xinetd off
# Remove iptables rules
rm -f /etc/sysconfig/{iptables,ip6tables}
# sysprep will do
## Remove MAC addresses, Add 'BOOTPROTO=dhcp'
#for F in $(ls -1 /etc/sysconfig/network-scripts/ifcfg-eth*); do
#  sed -i '/^HWADDR=/ d' $F
#done
rpm -ivh http://dl.fedoraproject.org/pub/epel/5/x86_64/epel-release-5.4.noarch.rpm
yum install -y cloud-init curl
sed -i '/^disable_root/ s/1/0/' /etc/cloud/cloud.cfg
sed -i '/^user/ s/ec2-user/centos/' /etc/cloud/cloud.cfg
echo "NOZEROCONF=yes" >> /etc/sysconfig/network

# TODO: get cloud-utils cloud-initramfs-growroot OR linux-rootfs-resize (NO CentOS 5 support)

### Update system
yum -y update
### Cleanup
#rm -f /etc/ssh/ssh_host_*
#rm -f /var/spool/mail/*
# Clean logs
# Remove EPEL
rm -f /etc/yum.repo.d/epel*
yum clean all

# Now shutdown the instance
shutdown -h now
### END VM config

# Do not attempt to boot ever. Cloud-init requires metadata server from this point on

# Cleanup image
virt-sysprep -d centos-5.11
# Remove from KVM

### HERE

# Mount on loopback for any additional changes
# CentOS has 2 partitions
# boot & root. root is LVM2_member. Part 2 has 2 lvm root & swap
mntpt='/tmp/mnt'
cd /tmp

# Mount Raw Image
image=$(ls -1 CentOS*.raw)
dev=$(losetup -f)
losetup $dev $image
# FIX: to get first partition
part=$(kpartx -av $dev | awk '{ print $3 }' | cut -d\  -f1)
mkdir -p $mntpt
vgscan
vgchange -ay
mount /dev/mapper/VolGroup00-LogVol00 $mntpt

#mount /dev/mapper/$part $mntpt
# Make changes to /boot
# consoles in grub $mntpnt/boot/grub/grub.conf
ADD:
serial --unit=0 --speed=115200
terminal --timeout=10 console serial
EDIT: all kernel lines to include
console=tty0 console=ttyS0,115200n8

#yum install -y --installroot=$mntpnt --releasever=/ curl
yum install -y --installroot=$mntpnt curl
yum --installroot=$mntpnt clean all

# Unmount Image
umount $mntpt

# /root
vgscan
vgchange -ay
mount /dev/mapper/VolGroup00-LogVol00 $mntpt
# Will be in VolGroup00 ?
lvdisplay VolGroup00
# VolGroup00-LogVolXX
mount <> $mntpnt

# Make any changes to root volume
# /etc/sysconfig/network
# /etc/cloud/cloud.cfg
# Update /etc/rc.local

# Unmount Image
umount $mntpt
vgchange -an VolGroup00
#vgchange -an <vol group>
# ? tune2fs
kpartx -d $dev
losetup -d $dev

# Convert image
qemu-img convert  -c -f raw $image -O qcow2 $(echo $image | sed 's/\.raw/.qcow2/')

virt-sparsify --format raw --compress --convert qcow2 CentOS-5.11-x86_64.raw CentOS-5.11-x86_64-sparse-5.qcow2


# Setup firstboot
# Use the following script from the openstack site, added to my rc.local before touch /var/lock/subsys/local
# ADD: disk resize - I think
depmod -a
modprobe acpiphp

# TODO: unescape all 
#### FIX all escaped things in image
cat >> /etc/rc.local << "EOF"
export LOG_FILE="/var/log/rc.local.log"

exec 2> $LOG_FILE  # send stderr from rc.local to a log file
exec 1>&2          # send stdout to the same log file

if [ ! -d /root/.ssh ]; then
  mkdir -p /root/.ssh
  chmod 700 /root/.ssh
fi

# unclear if cloud-init will do all this

# Fetch public key using HTTP
ATTEMPTS=30
FAILED=0
while [ ! -f /root/.ssh/authorized_keys-updated ]; do
  curl -f http://169.254.169.254/latest/meta-data/public-keys/0/openssh-key > /tmp/metadata-key 2>/dev/null
  if [ \$? -eq 0 ]; then
    cat /tmp/metadata-key >> /root/.ssh/authorized_keys
    chmod 0600 /root/.ssh/authorized_keys
    restorecon /root/.ssh/authorized_keys
    touch /root/.ssh/authorized_keys-updated
    rm -f /tmp/metadata-key
    echo "Successfully retrieved public key from instance metadata"
    echo "*****************"
    echo "AUTHORIZED KEYS"
    echo "*****************"
    cat /root/.ssh/authorized_keys
    echo "*****************"

    curl -f http://169.254.169.254/latest/meta-data/hostname > /tmp/metadata-hostname 2>/dev/null
    if [ \$? -eq 0 ]; then
      TEMP_HOST=\$(cat /tmp/metadata-hostname)
      sed -i "s/^HOSTNAME=.*\$/HOSTNAME=\$TEMP_HOST/g" /etc/sysconfig/network
      /bin/hostname \$TEMP_HOST
      echo "Successfully retrieved hostname from instance metadata"
      echo "*****************"
      echo "HOSTNAME CONFIG"
      echo "*****************"
      cat /etc/sysconfig/network
      echo "*****************"

    else
      echo "Failed to retrieve hostname from instance metadata.  This is a soft error so we'll continue"
    fi
    rm -f /tmp/metadata-hostname
  else
    FAILED=\$((\$FAILED + 1))
    if [ \$FAILED -ge \$ATTEMPTS ]; then
      echo "Failed to retrieve public key from instance metadata after \$FAILED attempts, quitting"
      break
    fi
    echo "Could not retrieve public key from instance metadata (attempt #\$FAILED/\$ATTEMPTS), retrying in 5 seconds..."
    sleep 5
  fi
done

# TODO: escape $
### LVM free space
part_range=$(parted /dev/vda --script "print free" | grep Free | awk '{ print $1" "$2 }')
if [ -n "$part_range" ]; then
  parted /dev/vda --script "mkpart primary $part_range"
  part_range="${part_range/ /.+}"
  part=$(parted /dev/vda --script "print" | egrep "$part_range" | awk '{ print $1 }')
  parted /dev/vda --script "set $part lvm on"
  pvcreate /dev/vda${part}
  volgroup=$(vgdisplay | grep 'VG Name' | awk '{ print $3 }')
  vgextend $volgroup /dev/vda${part}
  root_dev=$(df / | grep mapper | awk '{ print $1 }')
  lvextend $root_dev /dev/vda${part}
  resize2fs $root_dev
fi
EOF

### If cloud-init doesn't handle it
# is there a was to test it cloud-init processed user data ?
# get user data file
cmd="wget -v --timeout=5 --tries=2 --wait=10 http://169.254.169.254/latest/user-data -a $LOG_FILE -O /tmp/openstack-user-data-file.sh"
echo $cmd
eval $cmd
if [ $? -eq 0 ]; then
  # run the user data file
  chmod +x /tmp/openstack-user-data-file.sh
  /tmp/openstack-user-data-file.sh
fi



# simple attempt to get the user ssh key using the meta-data service
mkdir -p /root/.ssh
echo >> /root/.ssh/authorized_keys
curl -m 10 -s http://169.254.169.254/latest/meta-data/public-keys/0/openssh-key | grep 'ssh-rsa' >> /root/.ssh/authorized_keys
echo "AUTHORIZED_KEYS:"
echo "************************"
cat /root/.ssh/authorized_keys
echo "************************"

#?? cloud-utils parted git

# Setup volume resizing: rootfs resize or cloud-utils-growpart


# Convert and compress image
qemu-img convert -c -f raw <> -O qcow2 <>
# This is ~ 25% smaller - Need to verify image
virt-sparsify --format raw --compress --convert qcow2 old.raw new.qcow2
virt-sparsify --format raw --compress --convert qcow2 CentOS-5.11-x86_64.raw CentOS-5.11-x86_64-sparse-5.qcow2
#virt-sparsify --compress old.qcow2 new.qcow2
# upload it as bare to glance
glance image-create --name=centos-5.11 --disk-format qcow2 --container-format bare --is-public true --owner b9b002a5232c4f5c8d68af96c68338ca --file new.qcow2

nova boot --flavor m1.small --image 'centos-5.11-test1' --key-name snemetz  --poll snemetz-centos5-test-1

#find host
#find vnc
virsh domdisplay <instance>
# ssh tunnel
ssh <user>@<hypervisor> -L <local port>:127.0.0.1:<remote port>
# Run VNC app

# Test in VM
curl http://169.254.169.254/latest/meta-data/hostname

# Issues to fix:
-disk resize
-NO /root/.ssh
NO user created
-hostname NOT set in /etc/sysconfig/network but /etc/hostname is set
-install curl
-Shutdown bluetooth: chkconfig hidd off
# From boot msgs
GRUB loading stage2
Press any key to continue x10
cloud-init: applying credentials failed

FIXes:
### LVM free space
part_range=$(parted /dev/vda --script "print free" | grep Free | awk '{ print $1" "$2 }')
if [ -n "$part_range" ]; then
  parted /dev/vda --script "mkpart primary $part_range"
  # FIX: $part is not getting right value
  part_range="${part_range/ /\s+}"
  part=$(parted /dev/vda --script "print" | egrep "$part_range" | awk '{ print $1 }')
  parted /dev/vda --script "set $part lvm on"
  pvcreate /dev/vda${part}
  volgroup=$(vgdisplay | grep 'VG Name' | awk '{ print $3 }')
  vgextend $volgroup /dev/vda${part}
  root_dev=$(df / | grep mapper | awk '{ print $1 }')
  lvextend $root_dev /dev/vda${part}
  resize2fs $root_dev
fi
