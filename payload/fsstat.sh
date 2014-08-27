#!/usr/bin/bash

# Program       : fsstat.sh
# Author        : Jason.Banham@Nexenta.COM
# Date          : 2014-08-22
# Version       : 0.02
# Usage         : fsstat.sh [ sample_time | sample_count ]
# Purpose       : Look at filesystem statistics for all ZFS (non syspool) filesystems
# Legal         : Copyright 2013 and 2014, Nexenta Systems, Inc. 
#
# History       : 0.01 - Initial version
#		  0.02 - Added usage/help menu
#

function usage
{
    echo "Usage: `basename $0` [-h] [-t frequency | -c count | -F filesystem ]"
}

#
# Sample every 2 seconds
#
TIME_FREQ=2

#
# Which filesystems to monitor - NULL for first pass in case we want to specify
# a list using -F
#
FILESYSTEM=""

while getopts c:ht:F: argopt
do
    case $argopt in
    c)    COUNT=$OPTARG
	  ;;
    h)	  usage
     	  exit 0
	  ;;
    t)	  TIME_FREQ=$OPTARG
	  ;;
    F)	  FILESYSTEM="${FILESYSTEM} $OPTARG"
	  ;;
    esac
done

shift $((OPTIND-1))

#
# Sample all ZFS filesystems that are not the syspool
#
if [ "x$FILESYSTEM" == "x" ]; then
    FILESYSTEM="`grep zfs /etc/mnttab | grep -v syspool | awk '{print $2}'`"
fi

if [ "x${COUNT}" == "x" ]; then
    fsstat -i -Td $FILESYSTEM $TIME_FREQ 2>/dev/null
else
    fsstat -i -Td $FILESYSTEM $TIME_FREQ $COUNT 2>/dev/null
fi
