#!/bin/bash

#
# Program       : updater.sh
# Author        : Jason.Banham@Nexenta.COM
# Date          : 2013-10-03
# Version       : 0.01
# Usage         : updater.sh
# Purpose       : Concept code to see if we can perform an auto update for SPARTA
# Legal         : Copyright 2013, Nexenta Systems, Inc. 
#
# History       : 0.01 - Initial version
#

#
# Configuration details
#
SPARTA_ETC=/perflogs/etc							# Where we store the fingerprint/hash
SPARTA_HASH=sparta.hash								# Name of temporary downloaded hash file 
SPARTA_HASH_URL="https://github.com/jasonba/sparta/raw/master/sparta.hash" 	# The URL for the hash file

SPARTA_URL="https://github.com/jasonba/sparta/raw/master/sparta.tar.gz" 	# The URL of the SPARTA tarball
SPARTA_FILE="/tmp/sparta.tar.gz"						# Local copy of the tarball

SPARTA_UPDATER_URL="https://github.com/jasonba/sparta/raw/master/auto-updater.sh"   # The program that performs the update
SPARTA_UPDATER="/tmp/auto-updater.sh"						# Local copy of the updater script

# 
# Setup some binaries from known locations
#
CP=/usr/bin/cp
DIFF=/usr/bin/diff
ECHO=/usr/sun/bin/echo


#
# Download a file from the Internet, where we pass in:
# arg1 = URL
# arg2 = The full name and path of the file to store (typically in /tmp)
#
function pull_me
{
    DOWNLOAD_URL="$1"
    DOWNLOAD_FILE="$2"
    if [ "x$DOWNLOAD_URL" == "x" -o "x$DOWNLOAD_FILE" == "x" ]; then
	return 1
    fi

    WGET_OPTS="-o /dev/null --no-check-certificate"
    #WGET_OPTS="--no-check-certificate"

    TEMP_LOCATION="`$ECHO $DOWNLOAD_FILE | awk -F'/' '{print "/"$2}'`"	# Where we're storing the download
    FREE_SPACE_MIN=10						        # How much free space required in Megabytes

    # In reality we don't need much space but we're processing human readable output
    # which means we're likely to see K (kilobytes), M (megabytes) or G (gigabytes)
    # so if free space is either M or G then we know there's plenty available.
    # The first check is to see if there's gigabytes of free space, in which case we
    # know we can continue, otherwise if that fails we check for at least 10MB of free
    # space and if that succeeds we can proceed.
    #
    # In theory we should also check for Terabytes and Petabytes but I've never seen
    # the output for a Petabyte filesystem.  The man page for df suggests T and P 
    # for Terabytes and Petabytes, so we could check for those.
    #
    FREE_SPACE_CHECK="`df -h $TEMP_LOCATION | grep -v 'Filesystem' | awk '$4 ~ /[0-9][G|T|P]/ {print $4}'`"
    if [ "x${FREE_SPACE_CHECK}" == "x" ]; then
	FREE_SPACE_CHECK="`df -h $TEMP_LOCATION | grep -v 'Filesystem' | awk '$4 ~ /[1-9][0-9]M/ {print $4}'`"
	if [ "x${FREE_SPACE_CHECK}" == "x" ]; then
	    $ECHO "Less than ${FREE_SPACE}MB in $TEMP_LOCATION"
	    $ECHO "Unable to proceed in pulling down new file due to lack of available space"
	    $ECHO "Please check and take corrective maintenance soon, otherwise the appliance may become unresponsive"
	    exit 1
	fi
    fi

    wget $WGET_OPTS $DOWNLOAD_URL -O ${DOWNLOAD_FILE}
    if [ $? -ne 0 ]; then
	$ECHO "failed."
	return 1
    else
        $ECHO "success"
	return 0
    fi
}

#
# Attempt to pull down the current md5 fingerprint/hash of the SPARTA tarball and
# compare to the file that's stored locally.
# If this doesn't exist, then store a copy locally and update SPARTA anyhow
#
# Return codes:
# 0 - Hash files are the same
# 1 - Hash files were different
# 2 - There was an error
#
function bootstrap
{
    if [ ! -d $SPARTA_ETC ]; then
	mkdir $SPARTA_ETC
	if [ $? -ne 0 ]; then
	    $ECHO "Unable to create SPARTA config directory"
	    return 2
	fi
    fi
    $ECHO "Checking SPARTA version online ... \c"
    if [ ! -r $SPARTA_ETC/$SPARTA_HASH ]; then
	pull_me $SPARTA_HASH_URL /tmp/$SPARTA_HASH
        if [ $? -ne 0 ]; then
	    $ECHO "Unable to obtain SPARTA hash"
	    return 2
	fi
        $CP /tmp/$SPARTA_HASH $SPARTA_ETC
    else 
        $DIFF $SPARTA_ETC/$SPARTA_HASH /tmp/$SPARTA_HASH > /dev/null 2>&1 
        if [ $? -ne 0 ]; then
	    $ECHO "success"
            return 1
        else
   	    $ECHO "failed"
	    return 0
        fi
    fi
}


#
# Check to see if there's a newer version of SPARTA out there
#
bootstrap

if [ $? -eq 1 ]; then
    printf "Attempting to download current version of SPARTA ... "

    pull_me $SPARTA_URL $SPARTA_FILE
    if [ $? -eq 0 ]; then
        pull_me $SPARTA_UPDATER_URL $SPARTA_UPDATER
	if [ $? -eq 0 ]; then
	    $ECHO "SPARTA tarball and auto-update script successfully downloaded"
	else
	    $ECHO "unable to download the auto-updater"
	    exit 1
	fi
    else
	$ECHO "unable to download the current SPARTA tarball"
	exit 1
    fi

else
    printf "most recent version of SPARTA already installed\n"
fi

exit 0
