#!/bin/bash
#
# Get status from all OpenStack components

service cinder-api status
service cinder-scheduler status
service corosync status
service glance-api status
service glance-registry status
service haproxy status
service heat-api status
service heat-api-cfn status
service heat-api-cloudwatch status
service heat-engine status
service keystone status
service mysql status
service nova-api status
service nova-cert status
service nova-conductor status
service nova-consoleauth status
service nova-novncproxy status
service nova-objectstore status
service nova-scheduler status
service openvswitch-switch status
service pacemaker status
#service plymouth status
#service plymouth-log status
#service plymouth-ready status
#service plymouth-splash status
#service plymouth-stop status
#service plymouth-upstart-bridge status
service rabbitmq-server status
service sahara-all status
service swift-account status
service swift-account-auditor status
service swift-account-reaper status
service swift-account-replicator status
service swift-container status
service swift-container-auditor status
service swift-container-replicator status
service swift-container-sync status
service swift-container-updater status
service swift-object status
service swift-object-auditor status
service swift-object-replicator status
service swift-object-updater status
service swift-proxy status
