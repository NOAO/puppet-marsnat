#!/bin/bash
cd /tmp/
curl -L -O 'https://github.com/jgm/pandoc/releases/download/2.10/pandoc-2.10-linux-amd64.tar.gz'
tar xzf pandoc-2.10-linux-amd64.tar.gz
rsync -a pandoc-2.10/{bin,share} /usr/

