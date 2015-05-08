#!/bin/bash

# Create a usage report of resources used on all the hypervisors
#
# Report on:
#	vpus allocated by VMs
#	memory allocated by VMs
#	host memory used, swap used, load
#	nova & cinder disk usage
# Author: Steven Nemetz
# snemetz@hotmail.com

dir_tmp='/tmp'
vm_list="${dir_tmp}/hypervisor-vms"
local_script="${dir_tmp}/report-host-usage-local.sh"
report="${dir_tmp}/report_usage-$(date +%Y-%m-%d_%H:%M)"

hypervisors=`nova hypervisor-list | egrep -v 'ID|[+]' | awk -F \| '{ print $3 }' | cut -d. -f1 | sort`

cat > $local_script << 'SCRIPT'
#!/bin/bash
#
# Local host usage report script
#
dir_tmp='/tmp'
report="${dir_tmp}/report_usage"

convert () {
  # Convert K to Human best appoximation
  # use dc or bc to get accurate floating point
  declare -A human=([1024]="Mb" [$((1024**2))]="Gb" [$((1024**3))]="Tb" [$((1024**4))]="Pb")
  local sum=$1
  for ((x=1024**4; x>=1024; x/=1024)); do
    if [ $sum -gt $x ]; then
      echo `printf "%d %s\n" $(($sum/$x)) ${human[$x]}`
      break
    fi
  done
}

###==============
### Host data
###==============
memtotal=$(grep ^MemTotal /proc/meminfo | awk '{ print $2 }')
memfree=$(grep ^MemFree /proc/meminfo | awk '{ print $2 }')
swaptotal=$(grep ^SwapTotal /proc/meminfo | awk '{ print $2 }')
swapfree=$(grep ^SwapFree /proc/meminfo | awk '{ print $2 }')
load=$(awk '{ print $1","$2","$3 }' /proc/loadavg)

# TODO: add date time
cat << HOSTDATA
Resource usage of host: $HOSTNAME at $(date "+%Y-%m-%d %H:%M")

Memory (Total/Free): $memtotal ($(convert $memtotal))/ $memfree ($(convert $memfree))
Swap (Total/Free): $swaptotal ($(convert $swaptotal))/ $swapfree ($(convert $swapfree))
Load (1,5,15 minutes): $load

HOSTDATA

###==============
### VM Data
###==============
tmp_xml="${dir_tmp}/tmp_dom.xml"
vms=$(virsh list --all --name 2>/dev/null)
vm_count=$(echo "$vms" | wc -l)
echo "Virtual Machines"
echo "VMs count: $vm_count"

memtotal=0
cputotal=0
# Individual VM data
for V in $vms; do
  virsh dumpxml $V > $tmp_xml 2>/dev/null
  mem=$(xmllint --xpath 'string(//memory)' $tmp_xml)
  cmem=$(xmllint --xpath 'string(//currentMemory)' $tmp_xml)
  vcpu=$(xmllint --xpath 'string(//vcpu)' $tmp_xml)
  # Key: nova:{memory, vcpus}
  amem=$(xmllint --xpath '//metadata' $tmp_xml | grep 'nova:memory' | sed 's/.*>\(.*\)<.*/\1/')
  avcpu=$(xmllint --xpath '//metadata' $tmp_xml | grep 'nova:vcpus' | sed 's/.*>\(.*\)<.*/\1/')
  echo "$V, State: $(virsh dominfo $V | grep ^State | awk '{ print $2 }'), Total Mem: $mem ($(convert $mem)), Current Mem: $cmem ($(convert $cmem)), VCPUs: $vcpu, Nova Mem: $amem, Nova VCPUs: $avcpu"
  ((memtotal+=$mem))
  ((cputotal+=$vcpu))
done
# memory & cpu allocated
# total_vcpu=$(grep vcpu /var/lib/nova/instances/*-*/libvirt.xml | cut -d\> -f2 | cut -d\< -f1 | awk '{sum+=$1}END{print sum}')
# total_mem=$(grep memory /var/lib/nova/instances/*-*/libvirt.xml | cut -d\> -f2 | cut -d\< -f1 | awk '{sum+=$1}END{print sum}')
echo -e "Totals: VCPUs: $cputotal, Memory: $memtotal ($(convert $memtotal))\n"

rm -f $tmp_xml

###==============
### Disk Usage
### LVM Cinder & Nova
###==============
for VG in vm cinder; do
  VGSize=$(vgdisplay $VG | grep 'VG Size' | awk '{ print $3"\t"$4 }')
  Volumes=$(lvs -o lv_name,lv_size --sort lv_name  --separator , --noheadings --units g --nosuffix $VG)
  echo "LVM Volume Group $VG: $VGSize"
  count=0
  sum=0
  for V in $Volumes; do
    VName=$(echo $V | cut -d, -f1)
    VSize=$(echo $V | cut -d, -f2 | cut -d. -f1)
    echo -e "$VName\t$VSize GB"
    for M in $(mount | grep mapper | awk '{ print $1 }' | sed 's#.*/\(.*\)$#\1#'); do
      if [ "$M" == "$VG-$VName" ]; then
        used=$(df -h | grep $M | awk '{ print $3 }')
        echo "Volume $M: space used: $used"
      fi
    done
    ((sum+=$VSize))
    ((count++))
  done
  echo -e "Total volumes in $VG: $count, Size: $sum GB\n"
done
SCRIPT

echo "Transferring script..."
for H in $hypervisors; do
  scp $local_script root@$H: > /dev/null
done
echo "Collecting data..."
remote_script=$(basename $local_script)
for H in $hypervisors; do
  echo $H 1>&2
  ssh root@$H "bash ./$remote_script"
done > $report

# tar czf ${report}.tgz $report
