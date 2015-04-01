#!/bin/bash

service nova-api restart
service nova-cert restart
service nova-consoleauth restart
service nova-novncproxy restart
service nova-objectstore restart
service nova-scheduler restart
service nova-conductor restart
