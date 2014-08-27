#!/bin/bash

# Program       : flame_stacks.sh
# Author        : Jason.Banham@Nexenta.COM
# Date          : 2014-08-27
# Version       : 0.01
# Usage         : flame_stacks.sh
# Purpose       : Sample some kernel or userland stacks to flamegraph later
# Legal         : Copyright 2013 and 2014, Nexenta Systems, Inc. 
#
# History       : 0.01 - Initial version
#

function usage
{
    echo "Usage: `basename $0` [ -h | -a | -k | -u ]"
}

function help
{
    echo ""
    echo "  -h : Display help menu"
    echo "  -a : Sample kernel and userland stacks"
    echo "  -k : Sample kernel stacks only"
    echo "  -u : Sample userland stacks only"
    echo ""
}

#
# Capture 60 seconds of kernel activity
#
function kernel
{
    dtrace -x stackframes=100 -qn 'profile-997 /arg0/ { @[stack()] = count(); } tick-60s { exit(0); }'
}

#
# Capture 60 seconds of userland activity
#
function userland
{
    dtrace -x ustackframes=100 -qn 'profile-97 /arg1/ { @[ustack()] = count(); } tick-60s { exit(0); }'
}

#
# Capture 60 seconds of userland, plus time spent in the kernel, activity
#
function kernel_and_userland
{
    dtrace -x ustackframes=100 -qn 'profile-97 /{ @[ustack()] = count(); } tick-60s { exit(0); }'
}

while getopts haiku argopt
do
    case $argopt in
    h)    help
          exit 0
          ;;
    a)    kernel
	  userland
	  kernel_and_userland
          exit 0
          ;;
    i)    # Waiting future enhancement
          ;;
    k)    kernel
	  exit 0
	  ;;
    u)	  userland
	  exit 0
	  ;;
    esac
done

shift $((OPTIND-1))

usage
