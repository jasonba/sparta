#!/bin/bash

#
# Program       : sparta_shield.sh
# Author        : Jason.Banham@Nexenta.COM
# Date          : 2013-10-25 - 2014-01-07
# Version       : 0.04
# Usage         : sparta_shield.sh
# Purpose       : A Watchdog script to monitor the SPARTA performance logging 
#		  filesystem and stop sparta.sh if that becomes too full
# Legal         : Copyright 2013, Nexenta Systems, Inc. 
#
# History       : 0.01 - Initial version
#		  0.02 - Moved the date prefix code so it's accurate when we
#		         need to record this in the sparta.log file
#		  0.03 - Modified how we call the stop method to SPARTA
#		  0.04 - Added a trap handler to shutdown SPARTA and exit the shield
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
    $ECHO "The SPARTA configuration file ($SPARTA_CONFIG) is missing or empty, must exit."
    $ECHO "Please check that SPARTA was installed correctly and that you're not running it directly from the tarball."
    exit 1
fi

if [ $SPARTA_CONFIG_READ_OK == 0 ]; then
    $ECHO "Guru meditation error: Something went drastically wrong reading the config file."
    $ECHO "I have no choice but to quit, sorry."
    $ECHO "Please discuss this fault with a Nexenta support engineer."
    exit 1
fi

#
# Handling a SIGTERM signal
#
function shutdown_sparta
{
    PREFIX="${PREFIX}`date +%Y-%m-%d_%H:%M:%S` "
    $ECHO "${PREFIX}sigterm received - stopping sparta" >> $SPARTA_LOG
    $LOG_SCRIPTS/sparta.sh stop >> $SPARTA_LOG 2>&1
    logger -p daemon.notice "SPARTA shutdown requested."
    exit 0
}

trap shutdown_sparta SIGTERM SIGHUP

#
# Sleep period between sampling the current pool capacity (in seconds).
# Too frequently means we'll be burning CPU cycles, too infrequently means 
# we might fill up the pool.
# 
WATCHDOG_SLEEP_PERIOD=300

#
# At what capacity (%full) do we consider stopping SPARTA?
# This is defined in the sparta.config file as PERF_ZPOOL_CAPACITY_PERC
#

while [ 1 -lt 2 ]; 
do
    #
    # Test to see how much space we're using in the perflogs directory 
    #
    PERF_POOL="`$ECHO $LOG_DATASET | awk -F'/' '{print $1}'`"
    POOL_CAPACITY="`$ZPOOL list -H -o capacity $PERF_POOL | awk -F'%' '{print $1}'`"
    if [ $POOL_CAPACITY -gt $PERF_ZPOOL_CAPACITY_PERC ]; then
        #
        # What we prefix to the log file when writing
        #
        PREFIX="${PREFIX}`date +%Y-%m-%d_%H:%M:%S` "

	$ECHO "${PREFIX}Unable to continue monitoring $ZPOOL_NAME for performance issues as the pool is > ${PERF_ZPOOL_CAPACITY_PERC}% full" >> $SPARTA_LOG
	$ECHO "${PREFIX}stopping sparta" >> $SPARTA_LOG
	$LOG_SCRIPTS/sparta.sh stop >> $SPARTA_LOG 2>&1
	logger -p daemon.notice "SPARTA terminated due to lack of space in $PERF_POOL"
	exit 0
    fi

    #
    # All is well, sleep until next check
    #
    sleep $WATCHDOG_SLEEP_PERIOD & wait $!
done

