#!/bin/bash
#
# Check message queues against hypervisors


# Put current rabbit queues in array
#declare -a queue_array
#for i in $(rabbitmqctl list_queues | awk '{print $1}' | tail -n+1 );
#do
#   queue_array=$(("${queue_array[@]}" "$i"))
#done

queues=$(rabbitmqctl list_queues | awk '{print $1}')

# Put current nova services in array
declare -a service_array
for i in $(nova service-list | awk -F\| '/compute/ {print $4}' | cut -d\  -f2);
do
   service_array=( "${service_array[@]}" "$i" )
done

# debug
#echo "${queue_array[@]}"
#echo
#echo $queues
#echo "${service_array[@]}"

# Compare
count=0
for i in ${service_array[@]};
do
   echo $queues | grep $i &> /dev/null
   if [ $? -ne 0 ];
   then
      echo $i
      count=$((count + 1))
   fi
done
echo $count
