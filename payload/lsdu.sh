#!/bin/bash

#
# This function walks a given path, printing out the file/directory details using find -ls which
# will display the file size in bytes.
# Assuming each file/directory being displayed has >=7 fields, it will then accumulate both the
# disk usage (2nd column) in blocks and object size (7th column) in bytes.
#
# It then uses a technique to work out what is the simplest, most humanly readable "base unit" 
# of the values calculated, so converting bytes to gigabytes or terabytes where appropriate.
# The way this works is that we take the calculated sum of all the object sizes in bytes and
# work our way down a list of size values, starting at Petabytes, then trying Terabytes and
# so on until the summed value is divisible by the test size and the result is > 1
#
# We start at 5 and work our way down, so:
# 2^(10*5) = 1125899906842624 = 1PB
# 2^(10*4) =    1099511627776 = 1TB
# 2^(10*3) =       1073741824 = 1GB
# 2^(10*2) =          1048576 = 1MB
# 2^(10^1) =             1024 = 1KB
# 2^(10^0) =                1 = 1B
#
# Quick example:
# The summed value of all files, directories = 1599802888 bytes
#   1599802888 / 1125899906842624 = .00000142091040089553 PB
#
# which means it's less than 1PB, so decrement the counter and test again:
#   1599802888 / 1099511627776    = .00145501225051702931 TB
#
# which means it's less than 1TB, so decrement the counter and test again:
#   1599802888 / 1073741824       = 1.48993254452943801879 GB
#
# This means we're in the gigabyte range, so now we have an index entry into the "type"
# array, however because we've been decrementing the index is now less than when we tested
# as Gigabytes at 2^(10*i) where i was 3 but is now 2, so we need to get back to where we
# where *BUT* the array starts at position 1, thus position 3 would be MB and we wanted
# Gigabytes, so instead of bumping the index back to 3 it is incremented to 4 for the
# correct array position.
#

function lsdu() (
    export SEARCH_PATH=$*
    if [ ! -e "$SEARCH_PATH" ]; then
        echo "ERROR: Invalid file or directory ($SEARCH_PATH)"
        return 1
    fi
    find "$SEARCH_PATH" -ls | gawk --lint --posix '
        BEGIN {
            split("B KB MB GB TB PB",type)
            ls=hls=du=hdu=0;
            out_fmt="Path: %s \n  Total Size: %.2f %s \n  Disk Usage: %.2f %s \n  Compress Ratio: %.4f \n"
        }
        NF >= 7 {
            ls += $7
            du += $2
        }
        END {
            du *= 1024
            for(i=5; hls<1; i--) {
		hls = ls / (2^(10*i))
	    }
            for(j=5; hdu<1; j--) {
		hdu = du / (2^(10*j))
	    }
            printf out_fmt, ENVIRON["SEARCH_PATH"], hls, type[i+2], hdu, type[j+2], ls/du
        }
    '
)

function calc_space()
{
    export SEARCH_PATH=$*
    if [ ! -e "$SEARCH_PATH" ]; then
        echo "ERROR: Invalid file or directory ($SEARCH_PATH)"
        return 1
    fi
    find "$SEARCH_PATH" -ls | gawk --lint --posix '
        BEGIN {
            split("B K M G T P",type)
            ls=hls=0;
        }
        NF >= 7 {
            ls += $7
	}
        END {
            for(i=5; hls<1; i--) {
                hls = ls / (2^(10*i))
            }
	    printf "%d\n", ls
	}
    '
}

if [ "x$1" == "x" ]; then
    echo "usage: lsdu.sh <directory path>"
    exit 1
else
    echo "Calculating actual disk usage in $1"
    lsdu $1

    echo "Just returning the size for $1"
    PERF_SPACE_USAGE="`calc_space $1`"

#
# Double the space usage as a safety margin
#
    ZFS=/usr/sbin/zfs
    TARBALL_DIR=/var/tmp
    PERF_SPACE_USAGE="`expr $PERF_SPACE_USAGE \* 2`"
    PERF_DATASET="`df $TARBALL_DIR | awk -F'(' '{print $2}' | awk -F')' '{print $1}'`"
    PERF_DATASET_AVAIL="`$ZFS get -Hp avail $PERF_DATASET | awk '{print $3}'`"
    echo "/perflogs space usage $PERF_SPACE_USAGE"
    echo "perf dataset = $PERF_DATASET"
    echo "free space in $PERF_DATASET = $PERF_DATASET_AVAIL"

#
# Free space in bytes
#
    FREE_SPACE="`zfs get -Hpo value avail syspool`"

    if [ $FREE_SPACE -gt $PERF_SPACE_USAGE ]; then
        echo "Plenty of free space is available ($FREE_SPACE > $PERF_SPACE_USAGE)"
    else
        echo "Not enough free space ($FREE_SPACE < $PERF_SPACE_USAGE)"
    fi
fi

