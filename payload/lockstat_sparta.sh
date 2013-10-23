#!/usr/bin/bash
#
# Program       : lockstat_sparta.sh
# Author        : Jason.Banham@Nexenta.COM
# Date          : 2013-08-08 / 2013-10-10
# Version       : 0.02
# Usage         : lockstat.sh
# Purpose       : Gather lockstat statistics for a NexentaStor appliance, part of the SPARTA suite
# Legal         : Copyright 2013, Nexenta Systems, Inc. 
#
# History       : 0.01 - Initial version
#		  0.02 - Introduced and changed sleep period between lockstat samples from 
#                        10 to 60 seconds, as this is quite intensive on the CPU.
#

#
# Configuration file locations
#
SPARTA_CONFIG=/perflogs/etc/sparta.config

#
# How long to wait between samples
#
LOCKSTAT_SAMPLE_WAIT=60

#
# Pull out configurations details from the resource monitor config file
#
if [ -s $SPARTA_CONFIG ]; then
    source $SPARTA_CONFIG
else
    echo "The performance monitor configuration file is missing or empty, must exit."
    exit 1
fi

#
# Performance samples are collated by day (where possible) so figure out the day
# This should really be handled by the main SPARTA script, so probably redundant
# but may be useful if run outside of SPARTA
#
SAMPLE_DAY="`$DATE +%Y:%m:%d`"
if [ ! -d $LOG_DIR/$SAMPLE_DAY ]; then
    $MKDIR -p $LOG_DIR/$SAMPLE_DAY
    if [ $? -ne 0 ]; then
        $ECHO "Unable to create $LOG_DIR/$SAMPLE_DAY directory to capture statistics"
        exit 1
    fi
fi

#
# Continually collect the lockstat data
#
while [ 1 -lt 2 ]
do
    $DATE '+%Y-%m-%d %H:%M:%S' >> $LOG_DIR/$SAMPLE_DAY/lockstat-Ccwp.out
    $LOCKSTAT $LOCKSTAT_CONTENTION_OPTS >> $LOG_DIR/$SAMPLE_DAY/lockstat-Ccwp.out 2>&1 
    $DATE '+%Y-%m-%d %H:%M:%S' >> $LOG_DIR/$SAMPLE_DAY/lockstat-kIW.out
    $LOCKSTAT $LOCKSTAT_PROFILING_OPTS >> $LOG_DIR/$SAMPLE_DAY/lockstat-kIW.out 2>&1 
    sleep $LOCKSTAT_SAMPLE_WAIT
done
$ECHO " done"
