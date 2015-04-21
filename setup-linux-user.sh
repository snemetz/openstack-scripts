#!/bin/bash
#
# Setup a user on all hosts with limited sudo access
#
# If configuration management is setup, that should be used instead
# Lock password and setup ssh key
#
# Could also do with ACLs or SELinux

user=$1
if [ -z "$user" ]; then
  echo "ERROR: Must specify a user"
  exit 1
fi

dirtmp='/tmp'
sudo_file="${dirtmp}/${user}_sudoers"

cat >$sudo_file <<SUDOERS
Cmnd_Alias PAGERS = /usr/bin/less, /usr/bin/more, /usr/bin/pg
Cmnd_Alias LIST = /usr/bin/head, /usr/bin/tail
Cmnd_Alias PAGERS_LOGS = /usr/bin/less /var/log/*, /usr/bin/more /var/log/*, /usr/bin/pg /var/log/*
Cmnd_Alias LIST_LOGS = /usr/bin/head /var/log/*, /usr/bin/tail /var/log/*
Defaults!PAGERS noexec
Defaults!PAGERS_LOGS noexec
$user	ALL = NOPASSWD: PAGERS_LOGS, LIST_LOGS
SUDOERS

host_list=$(nova service-list | grep ' up ' | awk '{ print $6 }' | sort -u )
#ssh-keygen -t rsa -C "${user}@hortonworks" -N '' -q -f ${dirtmp}/key-${user}

for H in $host_list; do
  scp $sudo_file root@$H:/etc/sudoers.d/$(basename $sudo_file)
  #ssh root@$H "deluser --remove-home --quiet  $user"
  #ssh root@$H "adduser --disabled-password --quiet --gecos ''  $user;cd ~$user && mkdir .ssh && chown $user:$user .ssh && chmod 0700 .ssh"
  #scp ${dirtmp}/key-${user}.pub root@$H:~$user/.ssh/authorized_keys
  #ssh root@$H "cd ~$user/.ssh && chown $user:$user authorized_keys && chmod 644 authorized_keys;chmod 0440 /etc/sudoers.d/$(basename $sudo_file)"
  ssh root@$H "chmod 0440 /etc/sudoers.d/$(basename $sudo_file)"
done
