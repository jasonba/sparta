#!/bin/bash

#
# Program	: installer.sh
# Author	: Jason Banham
# Date		: 2013-01-04 | 2015-08-13
# Version	: 0.19
# Usage		: installer.sh [<zpool name>]
# Purpose	: Gather performance statistics for a NexentaStor appliance
# History	: 0.01 - Initial version
#		  0.02 - Added ZIL stat collection scripts
#		  0.03 - NexentaStor 3.x detection added
#		  0.04 - Added more scripts, CIFS and iSCSI monitoring, metaslab allocs
#		  0.05 - Adjusted how we call sparta.sh script
#		  0.06 - Corrected sparta_shield.sh filename for installer
#		  0.07 - Corrected logic error when saving data in .services_to_monitor
#		  0.08 - Modified use of CHMOD
#		  0.09 - Added test for NexentaStor 4 for arc_adjust*.d script
#		  0.10 - Added an ignore/skip option to pool selection for when a data
#		         pool has not yet been created
#		  0.11 - Added logic in case installer.sh is not run from the same directory
#			 where the tarball was unpacked
#		  0.12 - Enhanced installer to pick multiple zpools/volumes to monitor
#		  0.13 - Fixed bug in loop code for copying from payload directory
#		  0.14 - Added an option to skip the auto-updater when calling sparta.sh
#			 for customers who do not have a route out to the Internet
#	   	  0.15 - Added in fsstat.sh for list of scripts to install
#		  0.16 - Added in cifssvrtop.v4 specifically for NS4.x installations
#		  0.17 - Added 5 scripts to help observer NexentaStor 4 transaction engine/throttling/vdev queue
#		  0.18 - Added cifs_taskq_watch.sh, cifs_threads.sh, nfsio_onehost.d scripts
#		  0.19 - Added kmem_reap_100ms_ns.d for the 4.0.4 no strategy change for Illumos #5379

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
CHMOD=/usr/bin/chmod
CHOWN=/usr/bin/chown
COPY=/usr/bin/cp
SED=/usr/bin/sed
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
TEMPLATE_FILES="README_WORKLOADS light"
README="README"

$ZFS get -H type $LOG_DATASET > /dev/null 2>&1
if [ $? -ne 0 ]; then
    $ECHO "Could not find a performance logging data directory, creating one now ..."
    $ZFS create -o compression=gzip-9 -o mountpoint=$LOG_DIR $LOG_DATASET
    if [ $? != 0 ]; then
	$ECHO "Unable to create performance logging data directory, must exit - diag = $?"
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

$ECHO "Welcome to the performance monitoring script installer\n"

if [ "x$1" == "x" ]; then
    ANS=""
    while [ `echo $ANS | wc -c` -lt 2 ]; do
	let failcount=0
        $ECHO "Here are the available (non syspool) volumes (zpools) on this appliance:"
        $ZPOOL list | grep -v syspool
        $ECHO "\nPlease enter the name(s) of the volume(s) (zpool) to monitor"
        $ECHO "using commas to separate if multiple pools are specified"
	$ECHO "or enter none if no data pool exists : \c "
        read ANS
	if [ `echo $ANS | wc -c` -lt 2 ]; then
	    continue;
	fi
        if [ "$ANS" == "none" ]; then
	    ZPOOL_NAME="syspool"		# Default to syspool so we have something
	    break				# but likely to give unsatisfying results
	fi
	IFS=", 	"
	for poolname in $ANS
	do
            ZPOOL_EXIST="`$ZPOOL list -H $poolname > /dev/null 2>&1`"
            if [ $? -ne 0 ]; then
                $ECHO "Unable to find that volume ($poolname) - please try again.\n\n"
                poolname=""
                let failcount++
            fi
        done
        unset IFS
        if [ $failcount -eq 0 ]; then
	    ZPOOL_NAME="$ANS"
            break
        else
	    ANS=""
            continue
        fi
    done
else
    ZPOOL_EXIST="`$ZPOOL list -H $1 > /dev/null 2>&1`"
    if [ $? -ne 0 ]; then
	$ECHO "Unable to find that volume ($ANS) - must exit but please check and re-run the installer."
	exit 1
    fi
    ZPOOL_NAME="$1"
fi
$ECHO "You have chosen to monitor the volume - $ZPOOL_NAME"
$ECHO ""

SERVICE_ANS="n"
$ECHO "Which service do you wish to monitor?"
$ECHO "(Any other letter to skip this section)\n"
$ECHO "\t(N)FS"
$ECHO "\t(C)IFS"
$ECHO "\t(I)SCSI"
$ECHO "\t(S)TMF"

$ECHO "\nEnter the initial letter of the service you wish to monitor: \c"

read SERVICE_ANS
SERVICE_ANS="`$ECHO $SERVICE_ANS | $TR '[:upper:]' '[:lower:]'`"

TRACE_NFS=n
TRACE_CIFS=n
TRACE_ISCSI=n
TRACE_STMF=n

case $SERVICE_ANS in
    n ) TRACE_NFS=y
 	;;
    c ) TRACE_CIFS=y
	;;
    i ) TRACE_ISCSI=y
	;;
    s ) TRACE_STMF=y
	;;
    * ) SERVICE_SED_STRING="willrobinson"
	;;
esac

$ECHO "Installing scripts ..."

if [ ! -d $LOG_SCRIPTS ]; then
    mkdir $LOG_SCRIPTS
fi
if [ ! -d $LOG_CONFIG ]; then
    mkdir $LOG_CONFIG
fi
if [ ! -d $LOG_TEMPLATES ]; then
    mkdir $LOG_TEMPLATES
fi

 
#
# We expect people to unpack the tarball in /tmp and then cd into that directory
# in order to install SPARTA, however that may not always be the case, so check
# we can find the config file and prompt for the unpack location if not found.
#
UNPACK_DIR="."
if [ ! -r payload/sparta.config ]; then
    UNPACK_DIR=""
    while [ `echo $UNPACK_DIR | wc -c` -lt 2 ]; do
        $ECHO "I cannot find the scripts to install."
        $ECHO "Please give the full path to where you unpacked the tarball, eg: /var/tmp"
        $ECHO "Path name : \c"
        read UNPACK_DIR
        if [ `echo $UNPACK_DIR | wc -c` -lt 2 ]; then
            continue;
        fi
        if [ ! -r ${UNPACK_DIR}/payload/sparta.config ]; then
	    $ECHO "Oops, it doesn't look like SPARTA was unpacked there either, please try again.\n"
   	    UNPACK_DIR=""
	    continue
	else
	    $ECHO "thanks, I've found them now."
            break
        fi
    done
fi

cd $UNPACK_DIR

cp $README $LOG_DIR/

for script in $SCRIPTS
do
    $COPY payload/$script $LOG_SCRIPTS/
    if [ $? -ne 0 ]; then
	$ECHO "Failed to install $script"
    fi
done

for config in $CONFIG_FILES
do
    $COPY payload/$config $LOG_CONFIG/
    if [ $? -ne 0 ]; then
	$ECHO "Failed to copy $config"
    fi
done

for template in $TEMPLATE_FILES
do
    $COPY payload/workload_templates/$template $LOG_TEMPLATES/
    if [ $? -ne 0 ]; then
	$ECHO "Failed to copy $template"
    fi
done

$ECHO "Scripts installed"

#
# Post processing of configuration files, based on user input
#
$ECHO "ZPOOL_NAME=$ZPOOL_NAME" > $LOG_CONFIG/.zpool_to_monitor

#
# By now the $LOG_CONFIG directory should be present, so store our service preferences
#
$ECHO "TRACE_NFS=${TRACE_NFS}\nTRACE_CIFS=${TRACE_CIFS}\nTRACE_ISCSI=${TRACE_ISCSI}\nTRACE_STMF=${TRACE_STMF}" > $LOG_CONFIG/.services_to_monitor


$ECHO "\nWould you like me to run the performance gathering script? (y|n) \c"
read RUNME
RUNME="`$ECHO $RUNME | $TR '[:upper:]' '[:lower:]'`"
if [ "$RUNME" == "y" ]; then
    $ECHO "SPARTA usually dials home in order to get the latest version"
    $ECHO "Does this appliance have direct access to the Internet? (y|n) \c"
    read INTERNET_ACCESS
    INTERNET_ACCESS="`$ECHO $INTERNET_ACCESS | $TR '[:upper:]' '[:lower:]'`"
    if [ "$INTERNET_ACCESS" == "y" ]; then
        $LOG_SCRIPTS/sparta.sh start
    else
	$LOG_SCRIPTS/sparta.sh -u no start
    fi
fi

$ECHO "\nTo run the script manually use - $LOG_SCRIPTS/sparta.sh start"
$ECHO "To see the help page for SPARTA, run sparta.sh -h"

exit 0
