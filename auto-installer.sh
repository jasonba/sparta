#!/bin/bash

#
# Program	: auto-installer.sh
# Author	: Jason Banham
# Date		: 2013-11-04 : 2015-08-13
# Version	: 0.09
# Usage		: auto-installer.sh <tarball>
# Purpose	: Companion script to SPARTA for auto-installing a new sparta.tar.gz file
# History	: 0.01 - Initial version, based on the installer.sh script
#		  0.02 - Altered call method for starting sparta.sh (removed -c switch)
#		  0.03 - Modified how we call sparta.sh to save input args and reinvoke with the same
#		  0.04 - Modifed CHMOD to work on NexentaStor 4
#                 0.05 - Added test for NexentaStor 4 for arc_adjust*.d script
#		  0.06 - Updated for fsstat.sh and cifssvrtop.v4 scripts
#		  0.07 - Added 5 scripts to help observer NexentaStor 4 transaction engine/throttling/vdev queue
#	      	  0.08 - Added cifs_taskq_watch.sh, cifs_threads.sh, nfsio_onehost.d scripts
#		  0.09 - Added kmem_reap_100ms_ns.d for the 4.0.4 no strategy change for Illumos #5379
#

#
# Where we're going to store our performance logging data
#
LOG_DIR=/perflogs
LOG_DATASET=syspool/perflogs
LOG_CONFIG=${LOG_DIR}/etc
LOG_SCRIPTS=${LOG_DIR}/scripts
LOG_TEMPLATES=${LOG_DIR}/workload_templates

#
# How much space needs to be available to start logging data (in bytes)
#
LOG_SPACE_MIN=1073741824

#
# Where our binaries live
#
CAT=/usr/bin/cat
CD=/usr/bin/cd
CHMOD=/usr/bin/chmod
CHOWN=/usr/bin/chown
COPY=/usr/bin/cp
SED=/usr/bin/sed
TAR=/usr/sbin/tar
TAR_OPTS="zxf"
TEMP_DIR=/tmp/sparta.auto
TR=/usr/bin/tr
ZFS=/usr/sbin/zfs
ZPOOL=/usr/sbin/zpool
if [ "`uname -v`" == "NexentaOS_134f" ]; then
    ECHO=/usr/sun/bin/echo
else
    ECHO=/usr/bin/echo
fi

#
# Configuration file
#
SPARTA_CONFIG=$LOG_CONFIG/sparta.config
SPARTA_TEMPLATE=$LOG_CONFIG/sparta.config.template

#
# Scripts and files to install
#
SCRIPTS="arcstat.pl arc_adjust.v2.d arc_adjust_ns4.v2.d arc_evict.d cifssvrtop cifssvrtop.v4 delay_mintime.d delayed_writes.d dirty.d dnlc_lookups.d duration.d flame_stacks.sh fsstat.sh iscsisvrtop kmem_reap_100ms.d kmem_reap_100ms_ns.d large_delete.d txg_monitor.v3.d hotkernel.priv lockstat_sparta.sh metaslab.sh nfsio.d nfssrvutil.d nfssvrtop nfsrwtime.d rwlatency.d sbd_zvol_unmap.d sparta.sh sparta_shield.sh stmf_task_time.d tcp_input.d zil_commit_time.d zil_stat.d openzfs_txg.d arc_meta.sh cifs_taskq_watch.sh cifs_threads.sh nfsio_onehost.d"
CONFIG_FILES="sparta.config"
README="README"
TEMPLATE_FILES="README_WORKLOADS light"


# 
# Sanity checks
#
if [ $# -lt 2 ]; then
    $ECHO "Missing tarball and sparta hash file"
    exit 1
else
    TARBALL="$1"
    HASH_FILE="$2"
fi

if [ ! -r $TARBALL ]; then
    $ECHO "Unable to read $TARBALL"
    exit 1
fi
if [ ! -r $HASH_FILE ]; then
    $ECHO "Unable to read $HASH_FILE"
    exit 1
fi

#
# We got through the tarball and hash file checks, so now we need to shift the input
# arguments by two to grab the passed in input arguments from the original sparta.sh
# script, so we know how to re-invoke SPARTA after an update
#
shift ; shift
INPUT_ARGS="$*"


$ZFS get -H type $LOG_DATASET > /dev/null 2>&1
if [ $? -ne 0 ]; then
    $ZFS create -o compression=gzip-9 -o mountpoint=$LOG_DIR $LOG_DATASET
    if [ $? != 0 ]; then
	$ECHO "Unable to create performance logging data directory, must exit - error = $?"
	exit 1
    fi
fi

LOG_TYPE="`$ZFS get -H type $LOG_DATASET | awk '{print $3}'`"

if [ -d $LOG_DIR ]; then
    if [ "$LOG_TYPE" != "filesystem" ]; then
	$ECHO "Logging directory is not a zfs filesystem, must exit."
	exit 1
    else
	LOG_SPACE="`$ZFS get -Hp available $LOG_DATASET | awk '{print $3}'`"
	if [ $LOG_SPACE -lt $LOG_SPACE_MIN ]; then
	    $ECHO "Logging directory has less than $LOG_SPACE_MIN bytes free, will not capture any data."
	    exit 1
	fi
	if [ ! -w $LOG_DIR ]; then
	    $ECHO "Unable to write to $LOG_DIR, must exit."
	    exit 1
	fi
    fi
fi

$CHMOD u+rwx $LOG_DIR
$CHOWN root $LOG_DIR

#
# Unpack SPARTA tarball
#
mkdir $TEMP_DIR > /dev/null 2>&1
cd $TEMP_DIR
$TAR $TAR_OPTS $TARBALL > /dev/null 2>&1
if [ $? -ne 0 ]; then
    $ECHO "tarball extraction failed"
    exit 1
fi

$ECHO "Updating SPARTA ... \c"

if [ ! -d $LOG_SCRIPTS ]; then
    mkdir $LOG_SCRIPTS
fi
if [ ! -d $LOG_CONFIG ]; then
    mkdir $LOG_CONFIG
fi
if [ ! -d $LOG_TEMPLATES ]; then
    mkdir $LOG_TEMPLATES
fi

cp $README $LOG_DIR/

for script in $SCRIPTS
do
    $COPY payload/$script $LOG_SCRIPTS/
    if [ $? -ne 0 ]; then
	$ECHO "Failed to install $script"
    fi
done

for template in $TEMPLATE_FILES
do
    $COPY payload/workload_templates/$template $LOG_TEMPLATES/
    if [ $? -ne 0 ]; then
        $ECHO "Failed to copy $template"
    fi
done

#
# Need to copy the sparta.config file into the $LOG_CONFIG directory
# The predetermined zpool name and any services to monitor *should* be already
# saved in the $LOG_CONFIG directory as dot files that are subsequently read 
# into the $SPARTA_CONFIG file (if they exist)
# This avoids the need to post process the config file on an update by moving
# the semi-volatile data (nothing stopping the admin from manually changing those
# dot files) outside of the volatile file.
#
for config in $CONFIG_FILES
do
    $COPY payload/$config $LOG_CONFIG/
    if [ $? -ne 0 ]; then
        $ECHO "Failed to copy $config"
    fi
done

$COPY $HASH_FILE $LOG_CONFIG/sparta.hash

$ECHO "done"
$ECHO "Restarting SPARTA with the new version"
exec $LOG_SCRIPTS/sparta.sh $INPUT_ARGS
