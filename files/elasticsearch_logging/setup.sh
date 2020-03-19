#!/bin/bash
# run as root

export elastic_url=$@
export replace='{{ elastic_url }}'

rm /opt/filebeat-*/filebeat.yml
rm /opt/metricbeat-*/metricbeat.yml

# copy the config into place
# replace the string with url
sed -e "s/$replace/$elastic_url/ig" filebeat.yml > /opt/filebeat-7.1.0-linux-x86_64/filebeat.yml
sed -e "s/$replace/$elastic_url/ig" metricbeat.yml > /opt/metricbeat-7.1.0-linux-x86_64/metricbeat.yml

cd /opt/filebeat-7.1.0-linux-x86_64
# set ownership of files
chown root:root -R filebeat.yml modules.d module
/opt/filebeat modules enable nginx
/opt/filebeat modules enable system
/opt/filebeat setup

cd /opt/metricbeat-7.1.0-linux-x86_64
chown root:root -R metricbeat.yml modules.d module
/opt/metricbeat modules enable nginx
/opt/metricbeat setup

