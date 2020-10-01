#!/bin/bash

#
# Program	: installer.sh
# Author	: Jason Banham
# Date		: 2013-01-04 : 2019-12-02
# Version	: 0.27
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
#		  0.20 - Modified installer to work on NS5.x Beta
#		  0.21 - Added in the arc_adjust_ns5.d script to work on NexentaStor 5
#		  0.22 - Added check for library required by rotatelog binary on NexentaStor 5
#		  0.23 - Improved code to install missing library from local package, now bundled in tarball
#                 0.24 - Modified to install the zil_stat script for NexentaStor 5.2 onwards
#                 0.25 - Added more CPU data collection scripts
#                 0.26 - Added some additional ZIL dtrace scripts
#                 0.27 - Created lockstat_sparta_one.sh and added this to the cpu-grabit.sh script
#

#
# Where we're going to store our performance logging data
#
LOG_DIR=/perflogs
LOG_CONFIG=${LOG_DIR}/etc
LOG_BIN=${LOG_DIR}/bin
LOG_SCRIPTS=${LOG_DIR}/scripts
LOG_LAUNCHERS=${LOG_SCRIPTS}/launchers
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

OS_MAJOR="`uname -v | cut -d':' -f1 | sed -e 's/\..*//g'`"

case $OS_MAJOR in
    NexentaOS_134f )
                        ECHO=/usr/sun/bin/echo
                        LOG_DATASET=syspool/perflogs
                        ;;
    NexentaOS_4    )
                        ECHO=/usr/bin/echo
                        LOG_DATASET=syspool/perflogs
                        ;;
    NexentaStor_5    )
                        ECHO=/usr/bin/echo
                        LOG_DATASET=rpool/perflogs
                        ;;
esac

#
# Configuration file
#
SPARTA_CONFIG=$LOG_CONFIG/sparta.config
SPARTA_TEMPLATE=$LOG_CONFIG/sparta.config.template

#
# Scripts and files to install
#
SCRIPTS="arc_adjust_ns4.v2.d arc_adjust_ns5.d arc_adjust.v2.d arc_evict.d arc_meta.sh arcstat_ns5.pl arcstat.pl busy_cpus.d cifs_taskq_watch.sh cifs_threads.sh cifssvrtop cifssvrtop.v4 cpu-grabit.sh delay_mintime.d delayed_writes.d dirty.d dnlc_lookups.d duration.d flame_stacks.sh fsstat.sh hotkernel.priv iscsirwlat.d iscsisvrtop kmem_reap_100ms_ns.d kmem_reap_100ms.d kmem_reap_100ms_5x.d large_delete.d lockstat_sparta.sh lockstat_sparta_one.sh metaslab.sh msload.d msload_zvol.d nfsio_handsoff.d nfsio_onehost.d nfsio.d nfsrwtime.d nfssrvutil.d nfssvrtop nicstat openzfs_txg.d rwlatency.d sbd_zvol_unmap.d sparta_shield.sh sparta.sh stmf_sbd_unmap.d stmf_task_time.d stmf_threads.d tcp_input.d txg_monitor.v3.d use_slog_agg_debug.d watch_cpu.pl zil_commit_time.d zil_lwb_write_start.d zil_commit_watch.d zil_commit_writer.d zil_stat.d zil_stat_520.d"
BINARIES="rotatelogs nsver-check.pl pv"
LAUNCHERS="arc_mdb.sh arc_prefetch.sh hotkernel.sh flame_stacks.sh kmastat.sh kmemslabs.sh memstat.sh nfsstat.sh stmf_workers.sh"
CONFIG_FILES="sparta.config"
APRUTIL_LIB="libapr-util.p5p"
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
if [ ! -d $LOG_LAUNCHERS ]; then
    mkdir $LOG_LAUNCHERS
fi
if [ ! -d $LOG_CONFIG ]; then
    mkdir $LOG_CONFIG
fi
if [ ! -d $LOG_TEMPLATES ]; then
    mkdir $LOG_TEMPLATES
fi
if [ ! -d $LOG_BIN ]; then
    mkdir $LOG_BIN
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

for launcher in $LAUNCHERS
do
    $COPY payload/launchers/$launcher $LOG_LAUNCHERS/
    if [ $? -ne 0 ]; then
        $ECHO "Failed to install launcher $launcher"
    fi
done

for binary in $BINARIES
do
    $COPY payload/$binary $LOG_BIN/
    if [ $? -ne 0 ]; then
	$ECHO "Failed to install $binary"
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

#
# Miscellaneous
#
# Due to a missing library, we need to copy this package to /tmp in case we need to install it later
#
$COPY payload/$APRUTIL_LIB /tmp

$ECHO "Scripts installed"

#
# Post processing of configuration files, based on user input
#
$ECHO "ZPOOL_NAME=$ZPOOL_NAME" > $LOG_CONFIG/.zpool_to_monitor

#
# By now the $LOG_CONFIG directory should be present, so store our service preferences
#
$ECHO "TRACE_NFS=${TRACE_NFS}\nTRACE_CIFS=${TRACE_CIFS}\nTRACE_ISCSI=${TRACE_ISCSI}\nTRACE_STMF=${TRACE_STMF}" > $LOG_CONFIG/.services_to_monitor

#
# Post processing of the sparta.config to enable/disable features based on patch levels
#
# ----------------------------------------------------------------------------
# Bug #NEX-3273
# Synopsis:smbstat delays its output when redirected to a file
# Fix version: 4.0.3-FP4
# ----------------------------------------------------------------------------
#
$ECHO "Checking for patch levels and modifying sparta.config (where appropriate) ..."
case $OS_MAJOR in
    NexentaOS_4 ) 
    	if [ "`$LOG_BIN/nsver-check.pl /etc/issue 4.0.3-FP4`" == "fixed" ]; then
	    $COPY $SPARTA_CONFIG ${SPARTA_CONFIG}.prepatch
            $SED -e 's/ENABLE_CIFS_UTIL=0/ENABLE_CIFS_UTIL=1/g' -e 's/ENABLE_CIFS_OPS=0/ENABLE_CIFS_OPS=1/' ${SPARTA_CONFIG}.prepatch > ${SPARTA_CONFIG}
	    $ECHO "  Enabled smbstat data gathering as appliance meets patch levels"
        else
            $ECHO "  This version of NexentaStor 4 does *NOT* meet the requirement to enable smbstat - DISABLING"
	    $ECHO "  (see NEX-3273)"
        fi
	;;
    NexentaStor_5 )
        $COPY $SPARTA_CONFIG ${SPARTA_CONFIG}.prepatch
        $SED -e 's/ENABLE_CIFS_UTIL=0/ENABLE_CIFS_UTIL=1/g' -e 's/ENABLE_CIFS_OPS=0/ENABLE_CIFS_OPS=1/' ${SPARTA_CONFIG}.prepatch > ${SPARTA_CONFIG}
	$ECHO "  Enabled smbstat data gathering as appliance meets patch levels"
	;;
esac

#
# NexentaStor 5 GA (5.0.1) ships without the required libraries to run the rotatelogs script
# It's fairly trivial to install but we need to check, otherwise you get lots of errors
#

if [ "$OS_MAJOR" == "NexentaStor_5" ]; then
    $ECHO "\nChecking for pkg:/library/apr-util ... \c"
    pkg info -q pkg:/library/apr-util
    if [ $? -ne 0 ]; then
	$ECHO "NOT INSTALLED!"
	$ECHO "\nWARNING: Package pkg:/library/apr-util is missing, which will prevent log files from rotating."
	$ECHO "Failure to install this package means that SPARTA will not run.\n"
 	$ECHO "Would you like me to install the missing package? (y|n) \c"
	read INSTALL_ME 
	INSTALL_ME="`$ECHO $INSTALL_ME | $TR '[:upper:]' '[:lower:]'`"
	if [ "$INSTALL_ME" == "y" ]; then
	    $ECHO "Does this machine have direct access to the Internet ? (y|n) \c"
	    read INTERNET_ACCESS
	    INTERNET_ACCESS="`$ECHO $INTERNET_ACCESS | $TR '[:upper:]' '[:lower:]'`"
	    if [ "$INTERNET_ACCESS" == "y" ]; then
	        PKG_COMMAND="pkg install -q pkg:/library/apr-util"
  		PKG_SOURCE="from remote package server"
	    else
		if [ -r /tmp/$APRUTIL_LIB ]; then
		    PKG_COMMAND="pkg install -q -g file:///tmp/libapr-util.p5p pkg:/library/apr-util"
		    PKG_SOURCE="from local p5p package"
		else
		    $ECHO "Could not locate /tmp/$APRUTIL_LIB"
		    $ECHO "This should have been bundled with SPARTA in the payload directory, please locate and then manually"
		    $ECHO "run the following command:\n\n"
		    $ECHO "pkg install -g file:///<location_of_file>/libapr-util.p5p pkg:/library/apr-util"
		    $ECHO "\nMust exit now."
		    exit 1
	        fi
            fi
	    $ECHO "Attempting to install missing package $PKG_SOURCE ... \c"
 	    $PKG_COMMAND
	    ERR_CODE=$?
	    if [ $ERR_CODE -ne 0 ]; then
		$ECHO "Error!"
		$ECHO "Unable to install that package, so I must exit."
		$ECHO "Please seek assistance from a Nexenta support engineer, advising them that SPARTA"
		$ECHO "was unable to install pkg:/library/apr-util with error code $ERR_CODE"
	   	exit 1
	    else
		$ECHO "Successfully installed."
	    fi
        else
	    $ECHO "Must exit as SPARTA will not run without this package."
	    exit 1
        fi
    else
        $ECHO "already installed."
    fi
fi 

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
