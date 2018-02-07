#!/bin/bash

#
# Program       : memstat.sh
# Author        : Jason.Banham@Nexenta.COM
# Date          : 2018-02-05
# Version       : 0.01
# Usage         : Launched by main SPARTA script
# Purpose       : Launcher script for gathering platform memory statistics
# Legal         : Copyright 2013, 2014, 2015, 2016 and 2017 Nexenta Systems, Inc.
#

#
# Configuration file locations
#
SPARTA_CONFIG=/perflogs/etc/sparta.config

#
# Pull out configurations details from the resource monitor config file
#
if [ -s $SPARTA_CONFIG ]; then
    source $SPARTA_CONFIG
else
    echo "The SPARTA configuration file ($SPARTA_CONFIG) is missing or empty, must exit."
    echo "Please check that SPARTA was installed using installer.sh and that you're not running it directly from the tarball."
    exit 1
fi

let count=0
while [ $count -lt 3 ]; do
    print_to_log "  memory statistics - sample ${count}" $SPARTA_LOG $FF_DATE
    print_to_log "::memstat data - sample ${count}" $LOG_DIR/samples/memstat.out $FF_DATE_SEP
    $ECHO "::memstat" | $MDB -k >> $LOG_DIR/samples/memstat.out
    sleep 60
    let count=$count+1
done
