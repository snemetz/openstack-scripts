#!/bin/sh
#
# Fix for Debian 7 (wheezy)
#
pkg='bootlogd_2.88dsf-41+deb7u2_amd64.deb'
if [ ! -f /tmp/$pkg ]; then
  wget http://archive.gplhost.com/debian/pool/juno-backports/main/s/sysvinit/$pkg /tmp/
fi 
cp /tmp/$pkg ${BODI_CHROOT_PATH}
chroot ${BODI_CHROOT_PATH} dpkg -i $pkg
rm ${BODI_CHROOT_PATH}/$pkg

