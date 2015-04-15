# Editing CentOS 7 image

loop=$(losetup -f)
losetup $loop CentOS-7-x86_64-GenericCloud-20141129_01.raw
part=$(kpartx -av $loop | awk '{ print $3 }')
mkdir -p mnt
mount -t xfs /dev/mapper/$part mnt/

# Undo
#umount mnt
#kpartx -d $loop
#losetup -d $loop
