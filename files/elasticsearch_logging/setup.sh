#!/bin/bash
# run as root

export elastic_url=$@
export replace='{{ elastic_url }}'


# copy the config into place
# replace the string with url
sed -e "s/$replace/$elastic_url/ig" filebeat.yml > /etc/filebeat/filebeat.yml
sed -e "s/$replace/$elastic_url/ig" metricbeat.yml > /etc/filebeat/metricbeat.yml

filebeat modules enable nginx
filebeat modules enable system
filebeat setup

metricbeat modules enable nginx
metricbeat setup

