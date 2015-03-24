#!/bin/bash

# Program       : cifs_threads.sh
# Author        : Jason.Banham@Nexenta.COM
# Date          : 2014-03-05
# Version       : 0.02
# Usage         : cifs_threads.sh [ sample_time | sample_count ]
# Purpose       : Look at CIFS thread utilisation on the appliance
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
    echo "Usage: `basename $0` [-h] [-t frequency ]"
}

#
# Sample every 5 seconds
#
TIME_FREQ=5
SMBSTAT=/usr/sbin/smbstat
SMB_UTIL_OPTS="-cu"

while getopts c:ht: argopt
do
    case $argopt in
    h)    usage
          exit 0
          ;;
    t)    TIME_FREQ=$OPTARG
          ;;
    esac
done

shift $((OPTIND-1))

$SMBSTAT $SMB_UTIL_OPTS $TIME_FREQ

exit 0
