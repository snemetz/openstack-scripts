#!/bin/bash
#
# Things for reconfiguring nova

# Turn on Nova quotas - Run on controllers
sed -i '/^quota_driver=/ s/=.*/=nova.quota.DbQuotaDriver/' /etc/nova/nova.conf
