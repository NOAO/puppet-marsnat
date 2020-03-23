#!/bin/bash
# run as root

export elastic_url=$@
export replace='{{ elastic_url }}'

# filebeats
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.1.0-x86_64.rpm
rpm -vi filebeat-7.1.0-x86_64.rpm

# metricbeats
curl -L -O https://artifacts.elastic.co/downloads/beats/metricbeat/metricbeat-7.1.0-x86_64.rpm
rpm -vi metricbeat-7.1.0-x86_64.rpm



# copy the config into place
# replace the string with url
sed -e "s/$replace/$elastic_url/ig" filebeat.yml > /etc/filebeat/filebeat.yml
sed -e "s/$replace/$elastic_url/ig" metricbeat.yml > /etc/metricbeat/metricbeat.yml

filebeat modules enable nginx
filebeat modules enable system
filebeat -c /etc/filebeat/filebeat.yml setup

metricbeat modules enable nginx
metricbeat -c /etc/metricbeat/metricbeat.yml setup

#systemctl enable filebeat
#systemctl enable metricbeat
