#!/bin/bash
#
# Report on services that are down and still enabled
#
# TODO:
#	Setup so can be used to gerenate alerts

down_cinder='down-service-cinder'
down_nova='down-service-nova'

cinder service-list | grep down | grep enabled | tee $down_cinder | wc -l
cat $down_cinder
nova service-list | grep down | grep enabled | tee $down_nova | wc -l
cat $down_nova
