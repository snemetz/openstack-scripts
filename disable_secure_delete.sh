#!/bin/bash

cinder_conf='/etc/cinder/cinder.conf'
perl -p -i -e "s/kombu_reconnect_delay=5.0$/kombu_reconnect_delay=5.0\nvolume_clear=none/" $cinder_conf
service cinder-api restart
service cinder-scheduler restart

exit 0
