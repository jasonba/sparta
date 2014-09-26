#!/bin/bash

# Program       : arc_meta.sh
# Author        : Jason.Banham@Nexenta.COM
# Date          : 2014-09-24
# Version       : 0.01
# Usage         : arc_meta.sh [ sample_time | sample_count ]
# Purpose       : Look at filesystem statistics for all ZFS (non syspool) filesystems
# Legal         : Copyright 2013 and 2014, Nexenta Systems, Inc. 
#
# History       : 0.01 - Initial version
#                 0.02 - Added usage/help menu
#

function usage
{
    echo "Usage: `basename $0` [-h] [-t frequency | -c count ]"
}

#
# Sample every 2 seconds
#
TIME_FREQ=5
TRACKING=0
COUNT=1

while getopts c:ht: argopt
do
    case $argopt in
    c)    COUNT=$OPTARG
	  TRACKING=1
          ;;
    h)    usage
          exit 0
          ;;
    t)    TIME_FREQ=$OPTARG
          ;;
    esac
done

shift $((OPTIND-1))

let counter=0
while [ $counter -lt $COUNT ]; do
    kstat -Td -C zfs:0:arcstats:arc_meta_max zfs:0:arcstats:arc_meta_used
    if [ $TRACKING -eq 1 ]; then
	let counter=$counter+1
    fi
    if [ $counter -lt $COUNT ]; then
        sleep $TIME_FREQ
    fi
done
