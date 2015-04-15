#
# Build Windows VMs on KVM
#
# References:
# http://www.boerngen-schmidt.de/2013/10/windows-server-2012-r2-installation-in-kvm/
# https://www.evernote.com/shard/s63/sh/7ca831a4-b275-4c6f-8886-4ba9103c0af3/5a912740e9ab14f342e3c194974390eb
# https://github.com/cloudbase/windows-openstack-imaging-tools
# http://www.cloudbase.it/ws2012r2/ Image avail to download
# https://github.com/larsks/windows-openstack-image

# Download virtio window driver
# alt.fedoraproject.org/pub/alt/virtio-win/

# Fully virtualized
virt-install \
   --name=guest-name \
   --os-type=windows \
   --network network=default \
   --disk path=path-to-disk,size=disk-size \
   --cdrom=path-to-install-disk \
   --graphics vnc --ram=1024

# Windows Server 2012 R2 Example
# with LVM
virt-install --connect qemu:///system --arch=x86_64 -n <VM NAME> -r 4096 --cpu host --vcpus=2 --hvm \
--disk pool=VMs,size=<SIZE>,bus=virtio,cache=none,sparse=false \
-c /media/inst_iso/de_windows_server_2012_r2_x64_dvd_2707952.iso \
--disk path=/media/inst_iso/virtio-win-0.1-65.iso,device=cdrom,perms=ro \
--os-type windows --os-variant win2k8 --network network=default,model=virtio \
--graphics vnc,password=<PASSWORD> --noautoconsole

# Hortonworks Windows Server 2008 R2 on corp5
qemu-img create -f qcow2 /home/qemu/boron.img -o preallocation=metadata 100G
chown qemu:qemu /home/qemu/boron.img
virt-install --connect qemu:///system --arch=x86_64 --name boron --ram 8192 --cpu host --vcpus=1 --hvm \
--description "Boomi Atom" \
--disk path=/home/qemu/boron.img,device=disk,format=qcow2,bus=virtio,cache=none \
--cdrom=/tmp/SW_DVD5_Windows_Svr_DC_EE_SE_Web_2008R2_64-bit_English_X15-59754.ISO \
--disk path=/tmp/virtio-win-0.1-100.iso,device=cdrom,perms=ro \
--os-type windows --os-variant win2k8 \
--network bridge=br0,model=virtio \
--graphics vnc,listen=0.0.0.0,password=PASSWORD --noautoconsole
# Connect to console
# Install virtio drivers from win8 (may not have all or any drivers) or win7
# For 2008 R2 use wlh
# For 2012 R2 use win8


# Para-virtualized
# Look at RedHat doc

# Upload to OpenStack
glance image-create --name 'Windows Server 2012 R2 Standard Eval' --min-disk 40 --min-ram 1000 --is-public True --disk-format qcow2 --container-format bare --owner b9b002a5232c4f5c8d68af96c68338ca --file
