#!/bin/bash

#
# Program       : nfsstat.sh
# Author        : Jason.Banham@Nexenta.COM
# Date          : 2018-02-05 | 2022-08-17
# Version       : 0.02
# Usage         : Launched by main SPARTA script
# Purpose       : Launcher script for gathering nfsstat statistics 
# Legal         : Copyright 2013, 2014, 2015, 2016 and 2017 Nexenta Systems, Inc.
#
# History	: 0.01 - Initial version
#		  0.02 - Modified to use the rotate binary
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

print_to_log "  nfsstat -s" $SPARTA_LOG $FF_DATE
print_to_log "nfsstat -s" $LOG_DIR/samples/nfsstat-s.out $FF_DATE_SEP
$NFSSTAT $NFSSTAT_OPTS | $ROTATELOGS $LOG_DIR/samples/nfsstat-s.out.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME 2>&1 &
