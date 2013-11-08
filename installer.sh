#!/bin/bash

#
# Program	: installer.sh
# Author	: Jason Banham
# Date		: 2013-01-04 | 2013-11-09
# Version	: 0.07
# Usage		: installer.sh [<zpool name>]
# Purpose	: Gather performance statistics for a NexentaStor appliance
# History	: 0.01 - Initial version
#		  0.02 - Added ZIL stat collection scripts
#		  0.03 - NexentaStor 3.x detection added
#		  0.04 - Added more scripts, CIFS and iSCSI monitoring, metaslab allocs
#		  0.05 - Adjusted how we call sparta.sh script
#		  0.06 - Corrected sparta_shield.sh filename for installer
#		  0.07 - Corrected logic error when saving data in .services_to_monitor
#

#
# Where we're going to store our performance logging data
#
LOG_DIR=/perflogs
LOG_DATASET=syspool/perflogs
LOG_CONFIG=${LOG_DIR}/etc
LOG_SCRIPTS=${LOG_DIR}/scripts

#
# How much space needs to be available to start logging data (in bytes)
#
LOG_SPACE_MIN=1073741824

#
# Where our binaries live
#
CAT=/usr/bin/cat
CHMOD=/usr/sun/bin/chmod
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
SCRIPTS="arcstat.pl arc_adjust.v2.d arc_evict.d cifssvrtop dnlc_lookups.d iscsisvrtop kmem_reap_100ms.d large_delete.d txg_monitor.v3.d hotkernel.priv lockstat_sparta.sh metaslab.sh nfsio.d nfssrvutil.d nfssvrtop nfsrwtime.d sparta.sh sparta_shield.sh zil_commit_time.d zil_stat.d"
CONFIG_FILES="sparta.config"
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
        $ECHO "Here are the available (non syspool) volumes (zpools) on this appliance:"
        $ZPOOL list | grep -v syspool
        $ECHO "\nPlease enter the name of the volume (zpool) to monitor? : \c "
        read ANS
	if [ `echo $ANS | wc -c` -lt 2 ]; then
	    continue;
	fi
        ZPOOL_EXIST="`$ZPOOL list -H $ANS > /dev/null 2>&1`"
        if [ $? -ne 0 ]; then
    	    $ECHO "Unable to find that volume ($ANS) - please try again."
    	    ANS=""
        else
	    ZPOOL_NAME="$ANS"
	    break
        fi
    done
else
    ZPOOL_EXIST="`$ZPOOL list -H $1 > /dev/null 2>&1`"
    if [ $? -ne 0 ]; then
	echo "Unable to find that volume ($ANS) - must exit but please check and re-run the installer."
	exit 1
    fi
    ZPOOL_NAME="$1"
fi
echo "You have chosen to monitor the volume - $ZPOOL_NAME"

SERVICE_ANS="n"
$ECHO "Which service do you wish to monitor?"
$ECHO "(Any other letter to skip this section)\n"
$ECHO "\t(N)FS"
$ECHO "\t(C)IFS"
$ECHO "\t(I)SCSI"

$ECHO "\nEnter the initial letter of the service you wish to monitor: \c"

read SERVICE_ANS
SERVICE_ANS="`$ECHO $SERVICE_ANS | $TR '[:upper:]' '[:lower:]'`"

TRACE_NFS=n
TRACE_CIFS=n
TRACE_ISCSI=n

case $SERVICE_ANS in
    n ) TRACE_NFS=y
 	;;
    c ) TRACE_CIFS=y
	;;
    i ) TRACE_ISCSI=y
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
$ECHO "Scripts installed"

#
# Post processing of configuration files, based on user input
#
$ECHO "ZPOOL_NAME=$ZPOOL_NAME" > $LOG_CONFIG/.zpool_to_monitor

#
# By now the $LOG_CONFIG directory should be present, so store our service preferences
#
$ECHO "TRACE_NFS=${TRACE_NFS}\nTRACE_CIFS=${TRACE_CIFS}\nTRACE_ISCSI=${TRACE_ISCSI}" > $LOG_CONFIG/.services_to_monitor


$ECHO "\nWould you like me to run the performance gathering script? (y|n) \c"
read RUNME
RUNME="`$ECHO $RUNME | $TR '[:upper:]' '[:lower:]'`"
if [ "$RUNME" == "y" ]; then
    $LOG_SCRIPTS/sparta.sh start
fi

$ECHO "\nTo run the script manually use - $LOG_SCRIPTS/sparta.sh start"

exit 0
