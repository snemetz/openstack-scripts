#!/bin/bash

for H in `nova service-list --binary nova-conductor | egrep -v '[+]|Host' | awk '{ print $6 }'`; do
  ssh root@$H 'service nova-api restart; service nova-cert restart; service nova-consoleauth restart; service nova-novncproxy restart; service nova-objectstore restart; service nova-scheduler restart; service nova-conductor restart';
done
