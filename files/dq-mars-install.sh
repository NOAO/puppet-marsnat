#!/bin/bash
# Install DATAQ on provisioned MARS host
# run as: devops
# run from directory top of installed dataq repo, containing DESCRIPTION.rst
# Used by puppet.


LOG="/var/log/mars/install-dataq.log"
date                              > $LOG
source /opt/mars/venv/bin/activate

dir=`pwd`
#e.g. cd /opt/data-queue
VERSION=`cat dataq/VERSION`
echo "Running install on dir: $dir"

python3 setup.py install --force >> $LOG
echo "Installed DATAQ version: $VERSION" >> $LOG
cat $LOG
