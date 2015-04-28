#!/bin/bash

# Setup OpenStack authentication environment

export OS_AUTH_URL=http://172.22.64.1:5000/v2.0

export OS_TENANT_ID=b9b002a5232c4f5c8d68af96c68338ca
export OS_TENANT_NAME="admin"

export OS_USERNAME="snemetz"

# With Keystone you pass the keystone password.
echo "Please enter your OpenStack Password: "
read -sr OS_PASSWORD_INPUT
export OS_PASSWORD=$OS_PASSWORD_INPUT

# If your configuration has multiple regions, we set that information here.
# OS_REGION_NAME is optional and only valid in certain environments.
export OS_REGION_NAME="RegionOne"
# Don't leave a blank variable, unset it if it was empty
if [ -z "$OS_REGION_NAME" ]; then unset OS_REGION_NAME; fi

export PS1="[\u@\h \W($OS_TENANT_NAME)]\$ "
