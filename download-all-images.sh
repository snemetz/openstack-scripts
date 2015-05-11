
#!/bin/bash
#
# Download all images from Openstack glance
#
# Author: Steven Nemetz
# snemetz@hotmail.com

# Get all formats, then loop on. This is for naming the files correctly
formats=$(glance image-list --all-tenants | egrep -v '[+]|Disk Format' | awk -F\| '{ print $4 }' | sed 's/ //g' | sort -u)
for F in $formats; do
  images=$(glance image-list --all-tenants --disk-format $F | grep $F | awk '{ print $2 }')
  for I in $images; do
    name=$(glance image-show $I | grep ' name ' | awk -F\| '{ print $3 }' | tr -s ' ' | cut -c2- | sed 's/ $//')
    echo "Downloading: $I..."
    echo "Creating ${name}.$F"
    glance image-download --file "${name}.$F" $I
  done
done
