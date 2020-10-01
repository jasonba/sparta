#!/bin/bash

#
# Name          : cpu-grabit.sh
# Author        : Jason Banham
# Date          : 28th November 2019 - 6th June 2020
# Usage         : cpu-grabit.sh
# Purpose       : Collect additional data when kernel CPU usage crosses a threshold
# Version       : 0.04
# History       : 0.01 - Initial version
#                 0.02 - More robust with more data collection
#                 0.03 - powertop can be quite chatty with errors, so directing to /dev/null
#                 0.04 - Added lockstat data sampling so we can see lock latency
#

#
# Cleanup function
#
function cleanup
{
    if [ -r ${CPU_LOCK_FILE} ]; then
        rm ${CPU_LOCK_FILE}
    fi
}

#
# Monitor SIGHUP, SIGINT, SIGQUIT signals (see kill -l for a list of signals)
#
trap cleanup 1 2 3

CPU="$1"

#
# Where we're going to store our performance logging data, config and scripts
# - LOG_DATASET has been moved to an OS version specific section later
#
LOG_DIR=/perflogs
LOG_CONFIG=$LOG_DIR/etc
LOG_SCRIPTS=$LOG_DIR/scripts
LOG_LAUNCHERS=${LOG_SCRIPTS}/launchers
LOG_BIN=$LOG_DIR/bin
CPU_LOCK_FILE=/tmp/.cpu-grabit.lck.${CPU}

. $LOG_CONFIG/sparta.config

if [ ! -d ${LOG_DIR}/samples/watch_cpu ]; then
    mkdir -p ${LOG_DIR}/samples/watch_cpu
fi

LOCAL_POWERTOP_ENABLE="true"
#
# Check to see if we have the necessary kstat to run powertop
#
kstat -m acpi_drv -i 0 -n "battery BIF0" > /dev/null
if [ $? -ne 0 ]; then
    LOCAL_POWERTOP_ENABLE="false"
fi

#
# If we're already running, don't run another sample, otherwse we may have a
# runaway sample period
#
if [ -r ${CPU_LOCK_FILE} ]; then
    sleep 5
    exit 0
else
    touch ${CPU_LOCK_FILE}
fi 

#
# Detect which version of NexentaStor we're running on
# - Presently this should be 3.x, 4.x and 5.x
#
OS_VERS="`uname -v | cut -d':' -f1`"
OS_MAJOR="`echo $OS_VERS | sed -e 's/\..*//g'`"
OS_MINOR="$(echo $OS_VERS | awk -F'.' '{print $2}')"
case $OS_MAJOR in
    NexentaOS_134f )
                        NEXENTASTOR_MAJ_VER=3
                        ;;
    NexentaOS_4    )
                        NEXENTASTOR_MAJ_VER=4
                        ;;
    NexentaStor_5  )
                        NEXENTASTOR_MAJ_VER=5
                        ;;
esac

#
# Work out the date
#
LOG_DATESTAMP=$(date +%Y-%m-%d)_00_00
FLAME_TIMESTAMP=$(date +%Y-%m-%d_%H_%M_%S)
TIMESTAMP=$(date "+%a %b %e %T %Z %Y")

echo "$(date "+%Y-%m-%d_%H:%M:%S") Grabbing CPU interrupt status " >> $LOG_DIR/sparta.log
echo "$TIMESTAMP" >> $LOG_DIR/samples/watch_cpu/intrstat.out.$LOG_DATESTAMP
intrstat 1 30 >> $LOG_DIR/samples/watch_cpu/intrstat.out.$LOG_DATESTAMP &

#
# powertop has a tendency to dump core on 4.x so don't run there.
# Also whilst lab testing has shown it works, customer experience shows powertop runs into
# kstat and battery problems, so it is now disabled by default
#
if [ $ENABLE_POWERTOP -eq 1 ]; then
    if [ $NEXENTASTOR_MAJ_VER -ge 5 ]; then
        if [ "$LOCAL_POWERTOP_ENABLE" == "true" ]; then
           echo "$(date "+%Y-%m-%d_%H:%M:%S") Grabbing powertop" >> $LOG_DIR/sparta.log
           powertop -c $CPU -d 5 -t 1 >> $LOG_DIR/samples/watch_cpu/powertop.out.$LOG_DATESTAMP 2> /dev/null &
        fi
    fi
fi

#
# This will run for 60 seconds and then exit
#
echo "$(date "+%Y-%m-%d_%H:%M:%S") Capturing busy cpu status" >> $LOG_DIR/sparta.log
$LOG_SCRIPTS/busy_cpus.d >> $LOG_DIR/samples/watch_cpu/busy_cpus.out.$LOG_DATESTAMP &

#
# Grab a kernel flame graph
#
echo "$(date "+%Y-%m-%d_%H:%M:%S") Grabbing kernel flame graph" >> $LOG_DIR/sparta.log
$LOG_SCRIPTS/flame_stacks.sh -k >> $LOG_DIR/samples/watch_cpu/flame_kernel_stacks.out.$FLAME_TIMESTAMP 

#
# Grab some lockstat data
#
echo "$(date "+%Y-%m-%d_%H:%M:%S") Grabbing lockstat data" >> $LOG_DIR/sparta.log
$LOG_SCRIPTS/lockstat_sparta_one.sh &

#
# Tidy up after ourselves
#
cleanup
