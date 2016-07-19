#!/usr/bin/bash
#
# Program       : lockstat_sparta.sh
# Author        : Jason.Banham@Nexenta.COM
# Date          : 2013-08-08 / 2016-06-10
# Version       : 0.03
# Usage         : lockstat.sh
# Purpose       : Gather lockstat statistics for a NexentaStor appliance, part of the SPARTA suite
# Legal         : Copyright 2013, Nexenta Systems, Inc. 
#
# History       : 0.01 - Initial version
#		  0.02 - Introduced and changed sleep period between lockstat samples from 
#                        10 to 60 seconds, as this is quite intensive on the CPU.
#		  0.03 - Added in log rotation functionality, when size reaches a tunable limit
#

#
# Configuration file locations
#
SPARTA_CONFIG=/perflogs/etc/sparta.config

#
# How long to wait between samples
#
LOCKSTAT_SAMPLE_WAIT=60
MAX_SIZE=10485760		# 10MB max file size

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
if [ ! -d $LOG_DIR/samples ]; then
    $MKDIR -p $LOG_DIR/samples
    if [ $? -ne 0 ]; then
        $ECHO "Unable to create $LOG_DIR/samples directory to capture statistics"
        exit 1
    fi
fi

#
# Rotate a given file, as arg1
#
function rotate_log
{
    if [ -r ${1}.3 ]; then
        rm ${1}.3
    fi
    for index in `seq 2 -1 0`
    do
        if [ -r ${1}.$index ] ; then
            let next=$index+1
            mv ${1}.$index ${1}.$next
        fi
    done
    if [ -r ${1} ]; then
        mv ${1} ${1}.$index
    fi
}
	
#
# Continually collect the lockstat data
#
while [ 1 -lt 2 ]
do
    $DATE '+%Y-%m-%d %H:%M:%S' >> $LOG_DIR/samples/lockstat-Ccwp.out
    $LOCKSTAT $LOCKSTAT_CONTENTION_OPTS >> $LOG_DIR/samples/lockstat-Ccwp.out 2>&1 
    $DATE '+%Y-%m-%d %H:%M:%S' >> $LOG_DIR/samples/lockstat-kIW.out
    $LOCKSTAT $LOCKSTAT_PROFILING_OPTS >> $LOG_DIR/samples/lockstat-kIW.out 2>&1 

    LOCKSTAT_CONTENTION_SIZE="`ls -l $LOG_DIR/samples/lockstat-Ccwp.out | awk '{print $5}'`"
    if [ $LOCKSTAT_CONTENTION_SIZE -gt $MAX_SIZE ]; then
	rotate_log $LOG_DIR/samples/lockstat-Ccwp.out
    fi

    LOCKSTAT_PROFILE_SIZE="`ls -l $LOG_DIR/samples/lockstat-kIW.out | awk '{print $5}'`"
    if [ $LOCKSTAT_PROFILE_SIZE -gt $MAX_SIZE ]; then
	rotate_log $LOG_DIR/samples/lockstat-kIW.out
    fi
   
    sleep $LOCKSTAT_SAMPLE_WAIT
done
$ECHO " done"
