#!/bin/bash

#
# Program       : flame_stacks.sh
# Author        : Jason.Banham@Nexenta.COM
# Date          : 2018-02-05
# Version       : 0.01
# Usage         : Launched by main SPARTA script
# Purpose       : Launcher script for gathering flame graph data
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

print_to_log "Collecting kernel/user stacks" $SPARTA_LOG $FF_DATE
print_to_log "  Starting kernel stack collection" $SPARTA_LOG $FF_DATE

$FLAME_STACKS -k > $LOG_DIR/samples/flame_kernel_stacks.out 2>&1 

$FLAME_STACKS -u > $LOG_DIR/samples/flame_user_stacks.out 2>&1 &
