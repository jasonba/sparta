#!/bin/bash

# Program       : cifs_taskq_watch.sh
# Author        : Jason.Banham@Nexenta.COM
# Date          : 2014-03-05
# Version       : 0.02
# Usage         : cifs_taskq_watch.sh [ sample_time | sample_count ]
# Purpose       : Look at CIFS taskq activity on the appliance
# Legal         : Copyright 2013 and 2014, Nexenta Systems, Inc. 
# Notes         : Only runs on NexentaStor 4.x systems as the stats aren't exposed to kstat on 3.x
#                 and I don't want to be continuously running mdb -k on a production machine.
#
# History       : 0.01 - Initial version
#                 0.02 - Added usage/help menu

LC_TIME=C
export LC_TIME

function usage
{
    echo "Usage: `basename $0` [-h] [-t frequency | -c count ]"
}

#
# Sample every 5 seconds
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

SMBADDR=`echo "::smbsrv" | mdb -k | grep '^ff' | awk '{print $1}'`

let counter=0
while [ $counter -lt $COUNT ]; do
    date
    #echo "$SMBADDR::print -t smb_server_t sv_worker_pool | ::print taskq_t tq_active tq_nthreads tq_nthreads_max" | mdb -k
    echo "$SMBADDR::print -t smb_server_t sv_worker_pool | ::taskq" | mdb -k
    if [ $TRACKING -eq 1 ]; then
        let counter=$counter+1
    fi
    if [ $counter -lt $COUNT ]; then
        sleep $TIME_FREQ
    fi
done

exit 0
