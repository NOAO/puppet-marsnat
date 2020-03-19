#!/bin/bash 

# filebeats
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.1.0-linux-x86_64.tar.gz
tar xzvf filebeat-7.1.0-linux-x86_64.tar.gz

# metricbeats
curl -L -O https://artifacts.elastic.co/downloads/beats/metricbeat/metricbeat-7.1.0-linux-x86_64.tar.gz
tar xzvf metricbeat-7.1.0-linux-x86_64.tar.gz

