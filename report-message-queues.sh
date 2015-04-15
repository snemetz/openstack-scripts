#!/bin/bash
#
# Report on RabbitMQ messages queues with messages
#
# Author: Steven Nemetz
# snemetz@hotmail.com

email='snemetz@hortonworks.com'
dir_tmp='/tmp/'
file_queues="${dir_tmp}/message_queues"
highest_queue=$(rabbitmqctl list_queues | egrep -v '^(Listing|notifications\.|\.\.\.done)' | sort -nrk2 | awk '{ print $1","$2 }' | tee $file_queues | head -n1 | awk -F, '{ print $2 }')
report_queues=''

if [ $highest_queue -gt 0 ]; then
  # Build report
  for Q in $(cat $file_queues); do
    if [ "$(echo $Q | awk -F, '{ print $2 }')" == "0" ]; then break; fi
    queue=$(echo $Q | awk -F, '{ print $1"\t"$2 }')
    report_queues=$(echo -e "${report_queues}\n$queue")
  done
  #mail -s "OpenStack Report: Eng Message Queues" $email <<MSG
  cat <<MSG
RabbitMQ Message Queues Report

Queues with < 10 messages are most likely ok
Queues with 10 or more messages should be checked
The simple fix for a queue that is backed up, is to restart the service for that queue
$report_queues
MSG

  rm -f $file_queues
fi



