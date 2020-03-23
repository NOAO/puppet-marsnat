#!/bin/bash 

# filebeats
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.1.0-x86_64.rpm
rpm -vi filebeat-7.1.0-x86_64.rpm

# metricbeats
curl -L -O https://artifacts.elastic.co/downloads/beats/metricbeat/metricbeat-7.1.0-x86_64.rpm
rpm -vi metricbeat-7.1.0-x86_64.rpm

