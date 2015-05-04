#!/bin/bash

# trace an instance build
# info from /var/log/nova/nova-api.log on controller nodes
# trace by tenant uuid and instance uuid - sort on time (yyyy-mm-dd hh:mm:ss.mmm)
# can also pull all 'req-' 

# nova/nova-api.log	req-
# glance/api.log	-v [-]
# cinder/cinder-api.log	req-

trace_log=/tmp/trace-log
controllers='node-212 node-213 node-265 node-266 node-273'

for H in $controllers; do
  ssh $H "grep req- /var/log/nova/nova-api.log /var/log/cinder/cinder-api.log; grep -v '[-]' /var/log/glance/api.log"
done | grep 2015-05 > $trace_log




