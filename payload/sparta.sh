#!/bin/bash

#
# Program	: sparta.sh
# Author	: Jason.Banham@Nexenta.COM
# Date		: 2013-02-04 - 2021-03-24
# Version	: 0.93
# Usage		: sparta.sh [ -h | -help | start | status | stop | tarball ]
# Purpose	: Gather performance statistics for a NexentaStor appliance
# Legal		: Copyright 2013, 2014, 2015, 2016, 2017, 2018, 2019 Nexenta Systems, Inc. 
#                 Copyright 2020 and 2021, Nexenta by DDN
#
# History	: 0.01 - Initial version
#		  0.02 - Added DNLC lookup and prstat functions
#		  0.03 - Added ZIL stat gathering scripts
#		  0.04 - Detect when NFS server enabled
#			 Detect when running on NexentaStor 3.x or later
#			 Minor adjustments to code
#		  0.05 - Added arcstat and arc_adjust monitoring
#		  0.06 - Added the "large delete" script 
#		  0.07 - Put in a safety check for creating the tarball
#		         to try and limit the size of an auto-generated file
#		  0.08 - Modified script to ask if you want to generate a
#			 tarball rather than automatically do this
#		  0.09 - iostat and vmstat now collect data indefinitely
#			 rather than for a set period of time
#		  0.10 - Added script to look for NFS rw times and top files
#		  0.11 - Modified to perform continual lockstat sampling
#		  0.12 - Added mpstat and psrinfo collection
#		  0.13 - Added iostat -En ($IOSTAT_INFO_OPTS) for disk info
#		  0.14 - Added CPU interrupt info
#		  0.15 - Added taskq info
#		  0.16 - The arc_evict.d script is no longer run by default
#			 but is still installed for manual invocation
#		  0.17 - Added NFS and CIFS sharectl collection
#		  0.18 - Added network configuration data collection
#		  0.19 - SPARTA is now capable of auto updates through external update script
#		  0.20 - Added new switches to enable CIFS, iSCSI or NFS on command line
#	   	  0.21 - Added a -p <poolname> switch for quick pool selection
#		  0.22 - Modified the generate_tarball function to be more intelligent to
#			 actual data file usage and available free space
#		  0.23 - Added nfs server side statistic collection
#		  0.24 - Added a timeout value to the WGET options
#		  0.25 - Improved -p <poolname(s)> handling code so we can specify multiple
#			 zpools in one go, rather than having to run sparta multiple times
#		  0.26 - Significant rewrite, creating functions for the various data gathering
#			 and dtrace launching scripts.  
#		         Created a new set of variables in sparta.config to enable (1) or disable (0)
#			 the collection/launching of those scripts.
#		  0.27 - Added -P <protocol> switch to specific which protocols to enable (nfs,cifs,iscsi)
#		  0.28 - Added -S switch and stmf to protocol switch to allow for STMF/COMSTAR scripts
#		  0.29 - Modified how we invoke the auto-updater to pass in the input args to SPARTA
#		  0.30 - Added additional comstar scripts
#		  0.31 - Fixed NULL file logging problems
#		  0.32 - Changed lockstat monitoring to be disabled by default
#		  0.33 - Added a zpool iostat monitor for Paul Nienabar
#		  0.34 - Added LC_TIME into sparta.config to ensure correct date format for analysis tools
#		  0.35 - Added visual feedback if we find a site specific .commands.local file
#		  0.36 - sbd_zvol_unmap has disappeared from NS4.x so don't run the SBD_ZVOL_UNMAP script there
#		  0.37 - Modified the SAMPLE_DAY variable to use hyphens instead of colons
#		  0.38 - Added /etc/issue to list of files collected
#		  0.39 - Fixed bugs in input filter (IFS) variable and selection of STMF monitoring
#			 that were working but had come undone. (thanks to Dominic Watts @ NAS)
#		  0.40 - Removed a redundant tunable from sparta.config (LOG_USED_MAX)
#		  0.41 - Added filesystem statistic gathering
#		  0.42 - Added a cifssvrtop.v4 script that works on NS4.x
#		  0.43 - Added flamestack data collection for kernel and userland
#		  0.44 - Now checks for sufficient free space in $LOG_DATASET (zpool) before starting
#		  0.45 - nfsstat -s now runs continuously, as requested by Bayard
#		  0.46 - Added ARC metadata monitoring
#		  0.47 - Added monitoring of zpool TXG throughput, sync times, delays for NS4.x / OpenZFS
#		  0.48 - Added R/W latency monitoring script for I/O operations
#		  0.49 - Added OpenZFS write delay monitoring
#		  0.50 - Disabled ARC meta data monitoring on NS3.x as values aren't exposed to kstat interface
#		  0.51 - Added timestamp based data collection for zil_stat.d script
#		  0.52 - Added the option to collect the uptime of the system
#		  0.53 - Adjusted the kmem_reap_100ms.d script to include freemem, lotsfree, minfree, desfree and throttlefree values
#		  0.54 - Added the 'space' command to sparta to show uncompressed space usage in the $LOG_DIR
#		  0.55 - Added some smbstat monitoring for thread utilisation and iops statistics
#			 Modified arcstat.pl for portability and to print date+time stamps (thanks Tony Nguyen)
#			 We now also collect some log and misc files to assist analysis (see $OTHER_FILE_LIST)
#		  0.56 - Fixed bug in OpenZFS TXG monitoring that sampled at the wrong time, leading to odd numbers
#		  0.57 - Renamed ZFS/OpenZFS TXG output filenames (now as zfstxg_zpoolname.out)
#		  0.58 - Adjusted config to pick the no strategy script for NS4.0.4 after Illumos #5376 fix
#		  0.59 - Added in log rotation functionality that had been requested
#		  0.60 - Added in kmastat and kmem_slabs data collection at start time
#		  0.61 - Modified to work on NexentaStor 5
#		  0.62 - Improved the shutdown code to stop a clash with the watchdog monitor
#		  0.63 - Wrote some code to re-enable the sbd_zvol_unmap.d / stmf_sbd_unmap.d dtrace scripts
#		  0.64 - Added in some package information collection
#		  0.65 - Added in more network captures, kstat, ping and nicstat
#		  0.66 - Added a check for a missing library on NexentaStor 5 GA for the rotatelogs binary
#		  0.67 - The missing library is included in the tarball for local installation behind a firewall
#		  0.68 - We now collect tunables for NFS performance analysis
#		  0.69 - Added in new code to purge/zap the $LOG_DIR/samples if size exceeds $PURGE_LOG_WARNING
#			 and code for pruning the $LOG_DIR/samples directory of data greater than a specified 
#			 of number of days
#                 0.70 - Changed format of tarball file to remove colons in time as this causes issues with the Linux/GNU
#                        versions of tar, requiring you to use --force-local to stop it interpreting the filename as
#                        a URL to a remote system
#                 0.71 - Rewrote the large_delete.d script to match up deletes based on dnode object number and to
#                        make the output easier to understand
#                 0.72 - Changed the nfsio.d script to nfsio_handsoff.d as the other version required user interaction
#                 0.73 - Modified tarball creation code to show progress bar
#                        Included an STMF threads script to monitor needed and current values
#                        Additional CIFS data collection tools using the inbuilt statistics from smbstat
#                        Modified OpenZFS TXG monitor to be more accurate on delays and non-delays for specified zpool
#                 0.74 - Now collects ARC prefetch kstats
#                 0.75 - Significant speed increase on SPARTA startup after rethink on previous design decision
#                 0.76 - Removed debugging line from cifssvrtop.v4 which was generating huge files
#		  0.77 - Changes to NexentaStor 5.2 onwards change ZIL behaviour (Illumos #8585)
#                        - Modified the zil_stat.d script for 5.2+ to make this work again but now we have two scripts
#                 0.78 - NEX-9752 / Illumos #6950 removed the arc_do_user_evicts() code, so kmem_reap_100ms.d no longer
#                        worked in 5.1 onwards.  Created a kmem_reap_100ms_5x.d script with this removed.
#                 0.79 - Changed trunc() to clear() in zil_commit_time.d as requested by Daniel Borek
#                 0.80 - Fixed utterly stupid bug in zil_commit_time.d introduced in 0.79
#                 0.81 - Now extracts some sd state from the kernel
#                 0.82 - Now collects process information and kernel thread information
#                 0.83 - Added CPU watcher script which invokes capture script when kernel utilisation exceeds threshold
#                 0.84 - Added metaslab load script from Engineering
#                 0.85 - Re-enabled the zpool iostat data collection (for a 5 minute sample) as requested by Misha
#		  0.86 - Added further ZIL probing scripts, to dig deeper into ZIL behaviour.
#                        Modified nfsio_handsoff.d to truncate data to top 10 samples, as this just wastes cycles and
#                        eats disk space.
#                 0.87 - Added the Illumos txg_full.d script to give deeper insight into ZFS TXG processing
#                 0.88 - Disabled powertop collection in sparta.config.  Whilst this works on a variety of lab machines
#                        it turns out in the customer world, powertop spews kstat errors an awful lot.
#                 0.89 - Added a feature to allow SPARTA to be scheduled to start or stop at specific times
#                 0.90 - Simplified iSCSI startup options and re-used -S <protocol> to set protocols into config file
#                 0.91 - Improved script_status for (non) verbose use case.
#                        Fixed kstat data collection.
#                        Collects VLAN kstat information pertinent to NEX-22907
#                        Collects NEF configuration, useful to check on which profile is enabled
#                        Fixed the Delphix ZFS TXG full script which had not been running
#                        Collects the spa_obj_mtx_sz tunable and the /etc/system.d directory contents
#                        Added iscsisnoop.d and sbd_lu_rw_mb.d dtrace scripts for more iSCSI data
#			 Tuned the metaslab MSLOAD_TIME value down to 20ms from 50ms - this may be a moving target
#                        until a happy median is found
#                 0.92 - Looks like smbstat -r no longer dumps a core file from 5.3.0-CP3 onwards so have put checks in
#                        place to automatically enable this again, if you're on at least this version.
#                 0.93 - Adjusted the FTP server details / URL for uploading the tarball
#

# 
# Save the input arguments for passing into auto-updater, if required
#
INPUT_ARGS="$*"

SPARTA_CONFIG_READ_OK=0

#
# Configuration file locations 
#
SPARTA_CONFIG=/perflogs/etc/sparta.config

#
# Pull out configurations details from the resource monitor config file
#
if [ -s $SPARTA_CONFIG ]; then
    source $SPARTA_CONFIG
else
    echo "The SPARTA configuration file ($SPARTA_CONFIG) is missing or empty, must exit."
    echo "Please check that SPARTA was installed using installer.sh and that you're not running it directly from the tarball."
    exit 1
fi

if [ $SPARTA_CONFIG_READ_OK == 0 ]; then
    echo "Guru meditation error: Something went drastically wrong reading the config file."
    echo "I have no choice but to quit, sorry."
    echo "Please discuss this fault with a Nexenta support engineer."
    exit 1
fi

    
#
# The internal routines for this code are defined onwards
#

#
# Usage function, displayed when the wrong number/combination of arguments are
# supplied by the user
#
function usage
{
    $ECHO "Usage: `basename $0` [-h] [-b <begin_time>] [-e <end_time>] [-i <days>]  [-C|-I|-N] [-p zpoolname] [-r <atjob>] -u [ yes | no ] [-P|-S] {protocol,protocol... | all | none} ] { start | stop | status | tarball | version | space | prune | zap }\n"
}

#
# Help function, display help when requested
#
function help
{
    $ECHO "This is SPARTA (System Performance And Reporting Tool Analyser)"
    $ECHO "a performance gathering utility for NexentaStor\n"
    $ECHO "To invoke you must call sparta.sh start and it will then look for"
    $ECHO "a configuration file in $SPARTA_CONFIG and if found and valid, will read"
    $ECHO "this file in, then start collecting a series of performance data using"
    $ECHO "dtrace and other utilities.\n"
    $ECHO "You MUST use a command in order to invoke SPARTA to perform an action"
    $ECHO "where the command must be one of the following:"
    $ECHO ""
    $ECHO "    start         : start collecting performance data."
    $ECHO "    status        : displays any running dtrace scripts it has invoked."
    $ECHO "    stop          : attempt to stop the dtrace scripts it started."
    $ECHO "    tarball       : generate a tarball of the performance data."
    $ECHO "    version       : display the version."
    $ECHO "    space         : show uncompressed space usage in $LOG_DIR"
    $ECHO "    prune         : prune sample data greater than a specified number of days (-i <days>)"
    $ECHO "    zap           : remove all historical sample data in $LOG_DIR"
    $ECHO ""
    $ECHO "The following are valid optional arguments:\n"
    $ECHO "  -C              : Enable CIFS data collection (in addition to existing protocols)"
    $ECHO "  -I              : Enable iSCSI data collection [stmf/iscsi] (in addition to existing protocols)"
    $ECHO "  -N              : Enable NFS data collection (in addition to existing protocols)"
    $ECHO "  -b <timefmt>    : Schedule SPARTA to start at the specified time"
    $ECHO "  -e <timefmt>    : Schedule SPARTA to stop at the specified time"
    $ECHO "  -p <zpoolname>  : Monitor the given ZFS pool(s)"
    $ECHO "  -r <atjob>      : Remove a scheduled SPARTA job"
    $ECHO "  -u [ yes | no ] : Enable or disable the automatic update feature"
    $ECHO "  -P <protocol>   : Enable *only* the given protocol(s) nfs iscsi cifs stmf or a combination"
    $ECHO "                    of multiple protocols, eg: -P nfs,cifs"
    $ECHO "                    Also takes the options all or none to switch on all protocols, or collect none"
    $ECHO "                    Input list should be comma separated"
    $ECHO "  -S <protocol>   : Set protocols to monitor in configuration file"
    $ECHO "                    Uses the same format as the -P switch"
    $ECHO "  -i <days>       : Specify the number of days (greater than) for pruning sample data"
    $ECHO "                    (only works with the 'prune' command)"
    $ECHO ""
    $ECHO "  -v              : display the version."
    $ECHO "  -help | -h | -? : display this help page.\n"
    $ECHO ""
    $ECHO "NOTES:"
    $ECHO "  For scheduled start/stop activity the <timefmt> is the same as used by the"
    $ECHO "  at(1) shell command.  Either review https://illumos.org/man/1/at or use"
    $ECHO "  $ man at"
    $ECHO ""
    $ECHO "  Time format examples:"
    $ECHO "  now + 5 hours      : Will schedule SPARTA in 5 hours time from now"
    $ECHO "  21:00              : Will schedule SPARTA at 9pm"
    $ECHO "  0815am Sep 30      : Scheduled SPARTA for 08:15am on the 30th September"
    $ECHO ""

    $ECHO "Caveats:\n"
    $ECHO "Running\n-------"
    $ECHO "  The script is expected to live in $LOG_SCRIPTS which will be created by the"
    $ECHO "  installer.  If you did not use the installer.sh script to install this"
    $ECHO "  utility, then odd things may happen.\n"
    $ECHO "Disk space\n---------"
    $ECHO "  Some scripts, in particular the NFS scripts can consume a large amount of"
    $ECHO "  disk space, thus the script creates a new filesystem, with compression"
    $ECHO "  enabled to minimise the impact.\n"
    $ECHO "  You are STRONGLY advised to monitor the space used by $LOG_DIR and stop the"
    $ECHO "  dtrace scripts, if space is being consumed too quickly.\n"
    $ECHO ""
}


#
# Display a status of the scripts we're interested in / have invoked
# this includes dtrace and other scripts
# 2021-02-02 : Tweaked function to allow a verbose mode, which is what you want to see if
#              you're running sparta.sh status
#              Where this is used during script shutdown, the verbose output was being
#              counted as possible active scripts, ie: a red herring
#              We can now pass in the 'verbose' keyword as the first argument to get the
#              useful status information and keep quiet when we're just counting
#
function script_status
{
    if [ "$1" == "verbose" ]; then
        ATJOBS=$(at -l | wc -l)
        if [ $ATJOBS -gt 0 ]; then
            $ECHO "Scheduled SPARTA activity:"
            for startjob in $(grep -l 'sparta.*start' /var/spool/cron/atjobs/*.a)
            do
                atjob=$(basename $startjob)
                STIME=$(at -l $atjob | sed -e "s/$atjob//g")
                $ECHO "Start: $STIME ($atjob)"
            done
            for stopjob in $(grep -l 'sparta.*stop' /var/spool/cron/atjobs/*.a)
            do
                atjob=$(basename $stopjob)
                STIME=$(at -l $atjob | sed -e "s/$atjob//g")
                $ECHO "Stop : $STIME ($atjob)"
            done
        fi

        $ECHO ""
        $ECHO "Running processes:"
    fi
    pgrep -fl 'dtrace .* [/perflogs|nfssvrtop|cifssvrtop|iscsisvrtop|metaslab|msload_zvol|iscsisnoop|sbd_lu_rw_mb]'
    pgrep -fl 'perflogs/scripts/launchers'
    pgrep -fl $ARCSTAT_PL
    pgrep -fl $LOCKSTAT_SPARTA
    pgrep -fl "$VMSTAT $VMSTAT_OPTS"
    pgrep -fl "$MPSTAT $MPSTAT_OPTS"
    pgrep -fl "$IOSTAT $IOSTAT_OPTS"
    pgrep -fl "$PRSTAT $PRSTAT_OPTS"
    pgrep -fl "$SPARTA_SHIELD"
    pgrep -fl "$ZPOOL iostat $ZPOOL_IOSTAT_OPTS"
    pgrep -fl "$ARC_META"
    pgrep -fl "$SMBSTAT"
    pgrep -fl "$NICSTAT"
    pgrep -fl "$NFSSTAT $NFSSTAT_OPTS"
    pgrep -fl "watch_cpu.pl"
}


#
# Kill a list of performance monitoring scripts
#
function script_kill
{
    STOP_PID=$$
    if [ ! -r $STOPPING_FILE ]; then
        $ECHO $STOP_PID > $STOPPING_FILE
    else
        $ECHO "We appear to be stopping already, under PID = `cat $STOPPING_FILE`"
        ps -fp `cat $STOPPING_FILE`
        exit 0
    fi
    pkill -f 'dtrace .* [/perflogs|nfssvrtop|cifssvrtop|iscsisvrtop|metaslab|msload_zvol]'
    pkill -f $ARCSTAT_PL
    pkill -f $LOCKSTAT_SPARTA
    pkill -f "$VMSTAT $VMSTAT_OPTS"
    pkill -f "$MPSTAT $MPSTAT_OPTS"
    pkill -f "$IOSTAT $IOSTAT_OPTS"
    pkill -f "$PRSTAT $PRSTAT_OPTS"
    pkill -f "$SPARTA_SHIELD"
    pkill -f "$ZPOOL iostat $ZPOOL_IOSTAT_OPTS"
    pkill -f "$ARC_META"
    pkill -f "$SMBSTAT"
    pkill -f "$NICSTAT"
    pkill -f "$NFSSTAT $NFSSTAT_OPTS"
    pkill -f "watch_cpu.pl"
    if [ -r $STOPPING_FILE ]; then
        RECORDED_STOP_PID="`cat $STOPPING_FILE`"
        if [ $STOP_PID == $RECORDED_STOP_PID ]; then
            rm $STOPPING_FILE
        else
            $ECHO "Woah, something went wrong and changed the stopping PID whilst we were trying to stop."
            $ECHO "Must exit"
            exit 1
        fi
    else
        $ECHO "Error!  Someone deleted the stop lock file whilst we were trying to delete it"
        $ECHO "Must exit"
        exit 1
    fi
}
 

#
# Start SPARTA at a specified time via the use of the at sub-system
#
function schedule_sparta_start
{
    $ECHO "Scheduling SPARTA to start at: $*"
    at -s $* << EOF
/perflogs/scripts/sparta.sh -u no start
EOF
}


#
# Stop SPARTA at a specified time via the use of the at sub-system
function schedule_sparta_stop
{
    $ECHO "Scheduling SPARTA to stop at: $*"
    at -s $* << EOF
/perflogs/scripts/sparta.sh -u no stop
EOF
}


#
# Format flags used by print_to_log and callers
#
FF_DATE=1
FF_SEP=2
FF_DATE_SEP=3
FF_NEWL=4

#
# Moved print_to_log function to sparta.config
#

#
# Zero out/truncate/create an empty file.
#
# arg1 = The file to zero out
#
function zero
{
    $CP /dev/null $1
}

#
# Display a spinning cursor to show progress
#
declare -a SPINNER

SPINNER=(/ - \\ \| / - \\ \| ) 
SPINNERPOS=0

cursor_update()
{
    printf "\b"${SPINNER[$SPINNERPOS]} 
    (( SPINNERPOS=(SPINNERPOS +1)%8 ))
}

cursor_blank()
{
    printf "\b"
}

cursor_pause()
{
    printf "Zzz"
    sleep $1
    printf "\b\b\b   \b\b\b"
}


#
# Download a file from the Internet, where we pass in:
# arg1 = URL
# arg2 = The full name and path of the file to store (typically in /tmp)
#
# Return codes:
#   0 = Success
#   1 = An error occurred
#
function pull_me
{
    DOWNLOAD_URL="$1"
    DOWNLOAD_FILE="$2"
    if [ "x$DOWNLOAD_URL" == "x" -o "x$DOWNLOAD_FILE" == "x" ]; then
	return 1
    fi

    WGET_OPTS="-T 10 -o /dev/null --no-check-certificate"
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
	    return 1
	fi
    fi

    $WGET $WGET_OPTS $DOWNLOAD_URL -O ${DOWNLOAD_FILE}
    if [ $? -ne 0 ]; then
	return 1
    else
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
    pull_me $SPARTA_HASH_URL /tmp/$SPARTA_HASH
    if [ $? -ne 0 ]; then
        $ECHO "Unable to obtain SPARTA hash"
        return 2
    fi
    if [ ! -r $SPARTA_ETC/$SPARTA_HASH ]; then
        $CP /tmp/$SPARTA_HASH $SPARTA_ETC
    else 
        $DIFF $SPARTA_ETC/$SPARTA_HASH /tmp/$SPARTA_HASH > /dev/null 2>&1 
        if [ $? -ne 0 ]; then
            return 1
        else
	    return 0
        fi
    fi
}

#
# Calculate the non-compressed disk/space usage of a given directory.
# This is required as the performance logging filesystem usually has gzip-9 compression
# thus you cannot rely on then usual methods for working out space used.
#
function calc_space()
{
    SEARCH_PATH=$1
    if [ ! -e "$SEARCH_PATH" ]; then
        # Invalid path supplied
        return -1
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

#
# Check that we're being passed in an integer
#
function is_integer()
{   
    num=$(printf '%s' "$1" | sed "s/^0*\([1-9]\)/\1/; s/'/^/")
    test "$num" && printf '%d' "$num" >/dev/null 2>&1
}

#
# Check to see if a scrub is already in progress on any of the zpools
# Notify the user as this can be a performance inhibitor
#
function check_for_scrub()
{
    for zpool_name in `$ZPOOL list -H | awk '{print $1}'`
    do
        if [ "`zpool status $zpool_name | awk '/scrub in progress/ {print $1}'`" == "scan:" ]; then
	    $ECHO "    scrub running on $zpool_name"
	fi
    done
}


#
# Can we actually startup SPARTA?  Is there sufficient free space in the logging directory?
#
function space_checker
{
    PERF_POOL="`$ECHO $LOG_DATASET | awk -F'/' '{print $1}'`"
    POOL_CAPACITY="`$ZPOOL list -H -o capacity $PERF_POOL | awk -F'%' '{print $1}'`"
    if [ $POOL_CAPACITY -gt $PERF_ZPOOL_CAPACITY_PERC ]; then
        #
        # What we prefix to the log file when writing
        #
	$ECHO "Unable to start SPARTA as $PERF_POOL capacity > ${PERF_ZPOOL_CAPACITY_PERC}%"
	exit 1
    fi
}


#
# Generate a tarball of the perflogs directory
#   arg1 = whether we wish to bypass the 'Do you wish to ...' question as this can be
#          rather annoying when asked previously at the end of a sparta run
#
function generate_tarball
{
    #
    # Test to see how much space we're using in the perflogs directory before trying to create a tarball
    # as this may fill up the temporary filesystem and then multiply that by a safety margin
    #
    PERFLOG_USAGE="`calc_space $LOG_DIR`"
    PERFLOG_USAGE="`$ECHO $PERFLOG_USAGE $LOG_USAGE_SCALING_FACTOR | awk '{printf("%d", $1 * $2)}'`"

    #
    # Now figure out the dataset/filesystem associated with the tarball temporary directory and
    # pull out the available space from that dataset
    #
    PERF_DATASET="`df $TARBALL_DIR | awk -F'(' '{print $2}' | awk -F')' '{print $1}'`"
    PERF_DATASET_AVAIL="`$ZFS get -Hp avail $PERF_DATASET | awk '{print $3}'`"


    if [ $PERFLOG_USAGE -lt $PERF_DATASET_AVAIL ]; then
        if [ $PERFLOG_USAGE -gt $LOG_USAGE_WARNING ]; then
            $ECHO "\nThere appears to be historical data in the $LOG_DIR filesystem exceeding `expr $LOG_USAGE_WARNING / $GIGABYTE`GB"
	    $ECHO "This may take a while to generate the tarball and then compress it"
	    $ECHO "Please consider reviewing the contents of $LOG_DIR and removing redundant data\n"
            TARBALL_ANS="n"
            while [ true ]; do
 	        if [ "x$1" == "xbypass" ]; then
	            TARBALL_ANS="y"
		    break;
	        fi
	        $ECHO "Are you sure you wish to generate a tarball? (y|n) : \c"
                read TARBALL_ANS
                if [ `echo $TARBALL_ANS | wc -c` -lt 2 ]; then
                    continue;
                fi
                TARBALL_ANS="`$ECHO $TARBALL_ANS | $TR '[:upper:]' '[:lower:]'`"
                case $TARBALL_ANS in 
		    y ) break
		        ;;
		    n ) $ECHO "Skipping tarball generation"
		        return 1
		        ;;
	            * ) continue
		        ;;
	        esac
	    done
	fi
    else
        $ECHO "\nCreating that tarball would require `expr $PERFLOG_USAGE / $MEGABYTE`MB of free space in $TARBALL_DIR"
	$ECHO "and you only have `expr $PERF_DATASET_AVAIL / $MEGABYTE`MB available."
		$ECHO "\nPlease consider removing old/redundant data in $LOG_DATASET"
		$ECHO "or you can adjust the location of TARBALL_DIR in the sparta configuration file."
		$ECHO ""
		$ECHO "Unable to create that tarball"
		return 1
	    fi

	    $ECHO "Creating tarball ... " 
	    $TAR czf - $LOG_DIR | ($PV -p --timer --rate --bytes > ${PERF_TARBALL}.gz)
	#    $TAR cf $PERF_TARBALL $LOG_DIR >> $SPARTA_LOG 2>&1
	#    if [ -r ${PERF_TARBALL}.gz ]; then
	#        mv ${PERF_TARBALL}.gz ${PERF_TARBALL}.gz.$$
	#    fi
	#    $ECHO "done"
	#    $ECHO "Compressing tarball ... \c" 
	#    $GZIP -v $PERF_TARBALL >> $SPARTA_LOG 2>&1
	#    if [ $? -eq 0 ]; then
	#        $ECHO "done"
	#    else
	#    	$ECHO "failed! error encountered compressing the file (will not have .gz suffix)"
	#    fi

    $ECHO "\nA snapshot of the currently collected data has been collected."
    $ECHO "Please upload ${PERF_TARBALL}.gz to the Support Portal"
    $ECHO "eg:"
    $ECHO "curl -T ${PERF_TARBALL}.gz ${FTP_SERVER}/"$(basename ${PERF_TARBALL}.gz)" --ftp-create-dirs\n"
    $ECHO "where <CASE_REF> should be substituted for the case reference number"
    $ECHO "of the performance issue is being investigated.\n"
    $ECHO "The UUID can be obtained by using one of the following commands:"
    $ECHO ""
    $ECHO "NexentaStor 4.x\n"
    $ECHO "  nmc@ns4-jbod:/$ show appliance license"
    $ECHO "\n... which will be the value see for the 'Machine Signature'"
    $ECHO ""
    $ECHO "NexentaStor 5.x\n"
    $ECHO "  CLI@sparta> config get -O basic value system.guid\n\n"

    $ECHO "Please update your case reference in $CRM_TOOL \nor contact $NEX_SUPPORT_EMAIL if there are additional questions."
}

#
# In the field we've seen some users leave SPARTA running for days and weeks.  In some cases SPARTA
# has been run numerous times, in the same month, year or over several years.
# Naturally a *LOT* of data can be collected, so let's check to see if we should be pruning first.
#
function zap_logs
{
    SHIELD_PID="`pgrep -fl \"$SPARTA_SHIELD\" | awk '{print $1}'`"
    if [ "x${SHIELD_PID}" != "x" ]; then
	$ECHO "Cannot continue, SPARTA is already running and collecting data!"
	$ECHO "Please consider stopping SPARTA (/perflogs/scripts/sparta.sh stop) before purging historical data\n"
	exit 0
    fi
       
    $ECHO "Purging historical data"
    LOG_USAGE="`calc_space $LOG_DIR/samples`"
    LOG_USAGE="`expr $LOG_USAGE / $MEGABYTE`" 
    $ECHO "Current log space usage: $LOG_USAGE MB"

    if [ -d $LOG_DIR/samples ]; then
	$FIND $LOG_DIR/samples -type f -exec $RM {} + > /dev/null 2>&1
    fi

    LOG_USAGE="`calc_space $LOG_DIR/samples`"
    LOG_USAGE="`expr $LOG_USAGE / $MEGABYTE`" 
    $ECHO "After purging, log space usage: $LOG_USAGE MB"
}

#
# Prune the logs, using finer grain controls because sometimes we may want to keep some of the older data
# that is a few days or weeks old.
#
function prune_logs()
{
    if [ -d $LOG_DIR/samples ]; then
	$ECHO "Pruning log files older than $1 days"
	LOG_USAGE="`calc_space $LOG_DIR/samples`"
	LOG_USAGE="`expr $LOG_USAGE / $MEGABYTE`" 
	$ECHO "Current log space usage: $LOG_USAGE MB"
    
	$FIND $LOG_DIR/samples -type f -mtime +${1} -exec $RM {} +
    
	LOG_USAGE="`calc_space $LOG_DIR/samples`"
	LOG_USAGE="`expr $LOG_USAGE / $MEGABYTE`" 
	$ECHO "After pruning, log space usage: $LOG_USAGE MB"

	$ECHO "Done"
    else
	$ECHO "Could not find $LOG_DIR/samples directory!"
    fi
}


#
# Process any supplied command line switches
# before falling out to the sub-command processing stage
#
subcommand="usage"

while getopts b:Ce:hIi:NP:r:S:u:vp:? argopt
do
	case $argopt in
        b)      # Begin time for a scheduled SPARTA startup
    	        $ECHO "Scheduling SPARTA to start at: $OPTARG"
                schedule_sparta_start $OPTARG > /dev/null 2>&1
                SCHEDULE_SET="y"
                ;;

	C)      # Enable CIFS scripts
		TRACE_CIFS="y"
		;;

        e)      # End time for a scheduled SPARTA stop
    	        $ECHO "Scheduling SPARTA to stop at: $OPTARG"
                schedule_sparta_stop $OPTARG > /dev/null 2>&1
                SCHEDULE_SET="y"
                ;;

	I)      # Enable iSCSI scripts
		TRACE_ISCSI="y"
                TRACE_STMF="y"
		;;

	i)	# Get prune interval
		PRUNE_INTERVAL=$OPTARG
		;;

	N)      # Enable NFS scripts
		TRACE_NFS="y"
		;;

	P)	# Switch on the relevant protocols
		# and override any previous settings
		TRACE_CIFS="n"
		TRACE_ISCSI="n"
		TRACE_NFS="n"
		TRACE_STMF="n"

		IFS=", 	"
		for protocol in $OPTARG
		do
		    case $protocol in
			cifs  ) TRACE_CIFS="y"
				;;
			iscsi ) TRACE_ISCSI="y"
                                TRACE_STMF="y"
				;;
			nfs   ) TRACE_NFS="y"
				;;
			all   ) TRACE_CIFS="y"
				TRACE_ISCSI="y"
				TRACE_NFS="y"
				TRACE_STMF="y"
				;;
			none  ) TRACE_CIFS="n"
				TRACE_ISCSI="n"
				TRACE_NFS="n"
				TRACE_STMF="n"
				;;
		    esac
		done
		unset IFS
		;;

        r)      # Remove a specified scheduled SPARTA (at) job
                $ECHO "Removing job $OPTARG : \c"
                at -r $OPTARG
                if [ $? -eq 0 ]; then
		    $ECHO "Success"
                    exit 0
                else
		    $ECHO "Failed"
		    exit 1
	        fi
                ;;

	S)	# Set services to monitor into configation file
		TRACE_CIFS="n"
		TRACE_ISCSI="n"
		TRACE_NFS="n"
		TRACE_STMF="n"

		IFS=", 	"
		for protocol in $OPTARG
		do
		    case $protocol in
			cifs  ) TRACE_CIFS="y"
				;;
			iscsi ) TRACE_ISCSI="y"
                                TRACE_STMF="y"
				;;
			nfs   ) TRACE_NFS="y"
				;;
			all   ) TRACE_CIFS="y"
				TRACE_ISCSI="y"
				TRACE_NFS="y"
				TRACE_STMF="y"
				;;
			none  ) TRACE_CIFS="n"
				TRACE_ISCSI="n"
				TRACE_NFS="n"
				TRACE_STMF="n"
				;;
		    esac
		done
		unset IFS

	        $ECHO "TRACE_NFS=${TRACE_NFS}\nTRACE_CIFS=${TRACE_CIFS}\nTRACE_ISCSI=${TRACE_ISCSI}\nTRACE_STMF=${TRACE_STMF}" > $LOG_CONFIG/.services_to_monitor
                exit 0
		;;

	p)      ZPOOL_NAME=$OPTARG
		;;
	u)	UPDATE_OPT=$OPTARG
		;;
	v)      $ECHO "SPARTA version $SPARTA_VER"
		exit 0
		;;
	h|?)    help
		exit 0

	esac
done

shift $((OPTIND-1))
subcommand="$1"

#
# If a schedule is set, then exit at this point
#
if [ $SCHEDULE_SET == "y" ]; then
    exit 0
fi

#
# Check for a supplied command and act appropriately
#
case "$subcommand" in
    prune )
	is_integer $PRUNE_INTERVAL
	if [ $? -ne 0 ]; then
	    $ECHO "Looks like you didn't specify an integer as the prune interval, must exit."
	    exit 0
	fi

	prune_logs $PRUNE_INTERVAL
	exit 0
	;;
    zap )
	zap_logs
	exit 0
	;;
    space )
	SPACE_USED=`calc_space $LOG_DIR`
	echo "You are using `expr $SPACE_USED / $MEGABYTE` MB (uncompressed) in the $LOG_DIR directory for performance data." 
	exit 0
	;;
    start )
	# Break out of this case statement and into the main body of code
	;;
    stop )
	$ECHO "Stopping dtrace scripts ..."
	print_to_log "### Stopping SPARTA" $SPARTA_LOG $FF_DATE
	script_kill
	$ECHO "quiescing ..."
	sleep 5
	$ECHO "Number of dtrace scripts still active: \c"
	script_status | wc -l
	exit 0
	;;
    status )
	$ECHO "Monitoring zpool : $ZPOOL_NAME"
	$ECHO "Checking status of dtrace scripts ..."
	script_status verbose
	$ECHO ""
	exit 0
	;;
    tarball )
	$ECHO "Generating a tarball of collected performance data"
	generate_tarball
	exit 0 
	;;
    version )
	$ECHO "SPARTA version $SPARTA_VER"
	exit 0
	;;
    * )
	usage
	exit 0
	;;
esac


#
# Check we actually have sufficient free space to startup SPARTA
#
space_checker


#
# Recent 5.x SPARTA data has arrived in non LC_TIME=C format
# Check to see whether we have the C locale installed
# date '+%a %b %e %T %Z %Y'
#
locale -a > $LOG_DIR/locale-a.out
grep -q '^C' $LOG_DIR/locale-a.out
if [ $? -ne 0 ]; then
    do_log "C locale not installed, date format analysis may not work"
fi


################################################################################
# 
# In order to be more flexible, configurable and to allow for growth it was
# decided to define the series of commands/scripts/utilities we want to run 
# as a series of functions.
# Each function is specific to the command/script/utility being run and does
# the "heavy lifting" associated with that data collection.
#
# The choice as to whether a function is invoked is decided by having a set
# variable, per function/utility that can either be 1 (enabled) or 0 (disabled)
# and these can be configured by the admin.
# These will be defined in the sparta.config file *but* if a .commands.local file
# is found in the sparta/etc directory then we'll use that instead of the
# definitions in the sparta.config file.
# This will allow us to update the sparta.config file with new scripts/tools
# but allow site specific customisations to be kept.
#
# Finally we'll break down the scripts by category, cpu, kernel network, 
# zfs, etc... and setup a series of arrays that will read in that contain:
#
# ENABLE_ARRAY	  : Contains in the enable variables
# COMMAND_ARRAY   : Defines the functions to call
# COMMAND_NAME    : Defines a friendly name, which may (optionally) also be used for the log file
# 
# For example:
#
# CPU_ENABLE_LIST=($ENABLE_VMSTAT $ENABLE_MPSTAT $ENABLE_PSRINFO $ENABLE_PRSTAT $ENABLE_CSTATE $ENABLE_INTERRUPTS)
# CPU_NAME_LIST=( vmstat mpstat psrinfo prstat cstate interrupts)
# CPU_COMMAND_LIST=( launch_vmstat launch_mpstat gather_psrinfo launch_prstat gather_cstate gather_interrupts )
#
# Once the list has been defined, we walk the items in Enable array and if
# that particular command/function is set to enabled/true (1) then we invoke
# the function in the Command Array by the same index number as pass in the
# value of the Command Name found at the same index number.
#
# In the example above, assuming that $ENABLE_VMSTAT=1 and $ENABLE_MPSTAT=0 
# we'd walk the CPU_ENABLE_LIST, find that index entry 0 was enabled/true
# and then invoke the function in CPU_COMMAND_LIST at index entry 0, which
# would be launch_vmstat 
# Naturally for this to work correctly, the items in the lists must correspond
# exactly, so if we accidentally had launch_mpstat in index entry 0, even
# though it would be $ENABLE_VMSTAT set as enabled/true, then we would invoke
# the wrong function
#
# This is a limitation of bash with single, dimensional arrays and something
# for developers to bear in mind.
# As we set the ENABLE_VMSTAT, etc... variables elsewhere this should stop
# users/admins from meddling about with the arrays and causing problems but
# developers will need to be careful. 
#
# There are also two types of command/tool functions:
#  - launch : for running a script and putting into the background
#  - gather : for a one off run, usually to sample and then eixt
#

### Functions for command/tool/script usage below

#
# Avoid repetative copy/paste to update the log files
# arg1 = The human friendly name of the script+filename for logfile
#
function do_log
{
    MONITOR_NAME="$1"
    if [ "$MONITOR_NAME" == "NULL" ]; then
	return 0
    fi
    print_to_log "$MONITOR_NAME data gathering" $SPARTA_LOG $FF_DATE
}

## CPU/load specific section

#
# The following functions, by their name, describe what commands they're running
# If you don't know about vmstat/mpstat, etc... you're in the wrong place.
# All functions will take:
#   arg1 = Name of the service/tool we're launching, also used for the logfile name
#

function launch_vmstat
{
    $PGREP -fl "$VMSTAT $VMSTAT_OPTS" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
	$VMSTAT $VMSTAT_OPTS | $ROTATELOGS $LOG_DIR/samples/${1}.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME 2>&1 &
    fi
}

function launch_mpstat
{
    $PGREP -fl "$MPSTAT $MPSTAT_OPTS" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
	$MPSTAT $MPSTAT_OPTS | $ROTATELOGS $LOG_DIR/samples/${1}.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME 2>&1 &
    fi
}

function launch_prstat
{
    $PGREP -fl "$PRSTAT $PRSTAT_OPTS" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
	$PRSTAT $PRSTAT_OPTS | $ROTATELOGS $LOG_DIR/samples/${1}.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME 2>&1 &
    fi
}

function gather_psrinfo
{
    $PSRINFO $PSRINFO_OPTS > $LOG_DIR/samples/${1} 2>&1
}

function gather_cstate
{
    $KSTAT | grep -i cstate > $LOG_DIR/samples/${1} 2>&1
}

function gather_interrupts
{
    $ECHO "::interrupts -d" | $MDB -k > $LOG_DIR/samples/${1} 2>&1
}

function launch_watch_cpu
{
    print_to_log "Kicking off background kernel CPU utilisation monitor @ $WATCH_CPU_THRESHOLD %" $SPARTA_LOG $FF_DATE
    $NOHUP $($MPSTAT 2 | $LOG_SCRIPTS/watch_cpu.pl -p $WATCH_CPU_THRESHOLD -) > /dev/null 2>&1 &
}

### Kernel specific tool section

function launch_hotkernel
{
    $LOG_LAUNCHERS/hotkernel.sh $1 &
}

function obsolete_launch_hotkernel
{
    for x in {1..3}
    do
	print_to_log "Sample $x" $LOG_DIR/samples/${1} $FF_DATE_SEP
	$HOTKERNEL >> $LOG_DIR/samples/$1 2>&1 &
	$ECHO ". \c"
	let count=0
	while [ $count -lt $HOTKERNEL_SAMPLE_TIME ]; do
	    cursor_update
	    sleep 1
	    let count=$count+1
	done
	cursor_blank
	cursor_pause 5
    done
}

function launch_lockstat
{
    $PGREP -fl "$LOCKSTAT_SPARTA" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
	$LOCKSTAT_SPARTA >> $SPARTA_LOG &
    fi
}

function gather_taskq
{
    print_to_log "MDB taskq info" $LOG_DIR/mdb/taskq.out
    $ECHO "::taskq" | $MDB -k > $LOG_DIR/mdb/taskq.out
}

function launch_kmem_reap
{
    KMEM_REAP_PID="`pgrep -fl $KMEM_REAP | awk '{print $1}'`"
    if [ "x$KMEM_REAP_PID" == "x" ]; then
	$KMEM_REAP 2>&1 | $ROTATELOGS $LOG_DIR/samples/${1}.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME 2>&1 &
	print_to_log "  Started kmem_reap monitoring" $SPARTA_LOG $FF_DATE
    else
	print_to_log "  kmem_reap already running as PID $KMEM_REAP_PID" $SPARTA_LOG $FF_DATE
    fi
}

function gather_kernel_mdb
{
    print_to_log "Collecting kernel tunables" $SPARTA_LOG $FF_DATE
    for tunable in $KERNEL_TUNABLE_LIST
    do
	$ECHO "${tunable} : \c" > $LOG_DIR/mdb/mdb.${tunable}
	$ECHO "${tunable}::print -d" | $MDB -k >> $LOG_DIR/mdb/mdb.${tunable} 2>&1
    done
}

function gather_kernel_sdstate
{
    print_to_log "Collecting in kernel sd state" $SPARTA_LOG $FF_DATE
    $MDB -ke "::walk sd_state | ::grep '.!=0' | ::print -d struct sd_lun un_throttle un_saved_throttle un_phy_blocksize" >> $LOG_DIR/mdb/mdb.sd.throttle
    $MDB -ke "::walk sd_state | ::grep '.!=0' | ::print struct sd_lun un_sd | ::print struct scsi_device sd_dev | ::devinfo" >> $LOG_DIR/mdb/mdb.sd.devinfo
    $MDB -ke "::walk sd_state | ::grep '.!=0' | ::print struct sd_lun un_sd | ::print struct scsi_device sd_inq | ::print struct scsi_inquiry inq_vid inq_pid inq_serial" >> $LOG_DIR/mdb/mdb.sd.inquiry
}

function gather_flame_stacks
{
    $LOG_LAUNCHERS/flame_stacks.sh &
}

function obsolete_gather_flame_stacks
{
    print_to_log "Collecting kernel/user stacks" $SPARTA_LOG $FF_DATE
    print_to_log "  Starting kernel stack collection" $SPARTA_LOG $FF_DATE
    $FLAME_STACKS -k > $LOG_DIR/samples/flame_kernel_stacks.out 2>&1 &
    $ECHO ". \c"
    let count=0
    while [ $count -lt $FLAME_STACKS_SAMPLE_TIME ]; do
	cursor_update
	sleep 1
	let count=$count+1
    done
    cursor_blank

    print_to_log "  Starting userland stack collection" $SPARTA_LOG $FF_DATE
    $FLAME_STACKS -k > $LOG_DIR/samples/flame_user_stacks.out 2>&1 &
    $ECHO ". \c"
    let count=0
    while [ $count -lt $FLAME_STACKS_SAMPLE_TIME ]; do
	cursor_update
	sleep 1
	let count=$count+1
    done
    cursor_blank
}

function gather_kmastat
{
    $LOG_LAUNCHERS/kmastat.sh &
}

function obsolete_gather_kmastat
{
    print_to_log "Collecting kernel kmastat data" $SPARTA_LOG $FF_DATE
    $ECHO ". \c"
    let count=0
    while [ $count -lt $KMASTAT_SAMPLE_COUNT ]; do
	print_to_log "Sample $count" $LOG_DIR/samples/kmastat.out $FF_DATE_SEP
	$ECHO "::kmastat -g" | $MDB -k >> $LOG_DIR/samples/kmastat.out 2>&1
	cursor_update
	sleep 1
	let count=$count+1
    done
    cursor_blank
}

function gather_kmemslabs
{
    $LOG_LAUNCHERS/kmemslabs.sh &
}

function obsolete_gather_kmemslabs
{
    print_to_log "Collecting kernel kmem slabs data" $SPARTA_LOG $FF_DATE
    $ECHO ". \c"
    let count=0
    while [ $count -lt $KMEMSLABS_SAMPLE_COUNT ]; do
        print_to_log "Sample $count" $LOG_DIR/samples/kmem_slabs.out $FF_DATE_SEP
	$ECHO "::kmem_slabs" | $MDB -k >> $LOG_DIR/samples/kmem_slabs.out 2>&1
        cursor_update
        sleep 1
        let count=$count+1
    done
    cursor_blank
}

function gather_threads_and_stacks
{
    print_to_log "Collecting thread and stacks information" $SPARTA_LOG $FF_DATE
    $DATE +%Y-%m-%d_%H:%M:%S > $LOG_DIR/samples/threadlist.out
    $ECHO "-------------------" >> $LOG_DIR/samples/threadlist.out
    $MDB -ke "$THREADLIST_CMD" >> $LOG_DIR/samples/threadlist.out

    $DATE +%Y-%m-%d_%H:%M:%S > $LOG_DIR/samples/stacks.out
    $ECHO "-------------------" >> $LOG_DIR/samples/stacks.out
    $MDB -ke "$STACKS_CMD" >> $LOG_DIR/samples/stacks.out
}

function gather_kstat_info
{
    print_to_log "  Collecting kstat information" $SPARTA_LOG $FF_DATE
    $DATE +%Y-%m-%d_%H:%M:%S > $LOG_DIR/samples/kstat-p.out
    $ECHO "-------------------" >> $LOG_DIR/samples/kstat-p.out
    $KSTAT $KSTAT_OPTS >> $LOG_DIR/samples/kstat-p.out 2>&1
}
    

### Network specific tool section

function gather_ifconfig
{
    $IFCONFIG -a > $LOG_DIR/samples/${1}
}

function gather_dladm
{
    $DLADM show-phys > $LOG_DIR/samples/dladm-show-phys.out
    $DLADM show-link > $LOG_DIR/samples/dladm-show-link.out
    $DLADM show-linkprop > $LOG_DIR/samples/dladm-show-linkprop.out
}

function gather_ping
{
    if [ -r /etc/defaultrouter ]; then
        DEF_ROUTE="`cat /etc/defaultrouter`"
	$PING -s $DEF_ROUTE $PING_SIZE $PING_COUNT > $LOG_DIR/samples/ping.out &
    else
	$ECHO "Could not find default route" > $LOG_DIR/samples/ping.out
    fi
} 

function launch_nicstat
{
    if [ "$ENABLE_NICSTAT_IFACE" == "1" ]; then
        PGREP_STRING="$NICSTAT -n -M"
        NICSTAT__PID="`pgrep -fl "$PGREP_STRING" | awk '{print $1}'`"
        if [ "x$NICSTAT_PID" == "x" ]; then
	    $NICSTAT -n -M $NICSTAT_OPTS | $ROTATELOGS $LOG_DIR/samples/nicstat.ifaces.out.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME 2>&1 &
	    print_to_log "  Started interface monitoring" $SPARTA_LOG $FF_DATE
        else
            print_to_log "  nicstat interface monitoring was already running as PID $NICSTAT_PID" $SPARTA_LOG $FF_DATE
        fi
    fi
    if [ "$ENABLE_NICSTAT_TCP" == "1" ]; then
        PGREP_STRING="$NICSTAT -n -t"
        NICSTAT__PID="`pgrep -fl "$PGREP_STRING" | awk '{print $1}'`"
        if [ "x$NICSTAT_PID" == "x" ]; then
	    $NICSTAT -n -t $NICSTAT_OPTS | $ROTATELOGS $LOG_DIR/samples/nicstat.tcp.out.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME 2>&1 &
	    print_to_log "  Started TCP monitoring" $SPARTA_LOG $FF_DATE
        else
            print_to_log "  nicstat TCP monitoring was already running as PID $NICSTAT_PID" $SPARTA_LOG $FF_DATE
	fi
    fi
    if [ "$ENABLE_NICSTAT_UDP" == "1" ]; then
        PGREP_STRING="$NICSTAT -n -u"
        NICSTAT__PID="`pgrep -fl "$PGREP_STRING" | awk '{print $1}'`"
        if [ "x$NICSTAT_PID" == "x" ]; then
	    $NICSTAT -n -u $NICSTAT_OPTS | $ROTATELOGS $LOG_DIR/samples/nicstat.udp.out.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME 2>&1 &
	    print_to_log "  Started UDP monitoring" $SPARTA_LOG $FF_DATE
	else
	    print_to_log "  nicstat UDP monitoring was already running as PID $NICSTAT_PID" $SPARTA_LOG $FF_DATE
	fi
    fi
}

function launch_vlan_kstat
{
    print_to_log "  Collecting kstat VLAN information" $SPARTA_LOG $FF_DATE
    for VLAN in $($DLADM show-vlan -p -o link)
    do
        $PGREP -fl "$KSTAT -Td -p ${VLAN}::mac_rx_swlane0:rxsdrops" > /dev/null 2>&1
	if [ $? -ne 0 ]; then
            $DATE +%Y-%m-%d_%H:%M:%S > $LOG_DIR/samples/vlan-${VLAN}.out
            $ECHO "-------------------" >> $LOG_DIR/samples/vlan-${VLAN}.out
            $KSTAT -Td -p ${VLAN}::mac_rx_swlane0:rxsdrops $VLAN_KSTAT_OPTS >> $LOG_DIR/samples/vlan-${VLAN}.out &
        fi
    done
}


### ZFS specific tool section

#
# The original design goal was to monitor just one zpool, which is the most 
# common configuration, however some NexentaStor configurations have lots of
# zpools, eg: Metro HA Cluster
# Thus it became necessary to monitor multiple zpools in one go, rather than
# having to loop through multiple iterations of the sparta.sh script.
#

#
# Loop through zpool specific monitoring scripts for each zpool specified
# We expect the pool name(s) supplied to -p <value> to be of the format:
#   -p jonjones
#   -p jonjones,john,shayera
#   -p "supes flash"
#   -p "jonjones,john,shayera"
#

function launch_txg_monitor
{
    IFS=", 	"
    for poolname in $ZPOOL_NAME
    do
        PGREP_STRING="$TXG_MON $poolname"
        TXG_MON_PID="`pgrep -fl "$PGREP_STRING" | awk '{print $1}'`"
        if [ "x$TXG_MON_PID" == "x" ]; then
            $TXG_MON $poolname | $ROTATELOGS $LOG_DIR/samples/zfstxg_${poolname}.out.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME 2>&1 &
            print_to_log "  Started txg_monitoring on $poolname" $SPARTA_LOG $FF_DATE
        else
            print_to_log "  txg_monitor already running for zpool $poolname as PID $TXG_MON_PID" $SPARTA_LOG $FF_DATE
        fi
    done
    unset IFS
}

function launch_openzfs_txg_monitor
{
    IFS=", 	"
    for poolname in $ZPOOL_NAME
    do
        PGREP_STRING="$TXG_MON $poolname"
        OPENZFS_TXG_MON_PID="`pgrep -fl "$PGREP_STRING" | awk '{print $1}'`"
        if [ "x$OPENZFS_TXG_MON_PID" == "x" ]; then
            $OPENZFS_TXG_MON $poolname | $ROTATELOGS $LOG_DIR/samples/zfstxg_open_${poolname}.out.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME 2>&1 &
            print_to_log "  Started OpenZFS txg_monitoring on $poolname" $SPARTA_LOG $FF_DATE
        else
            print_to_log "  OpenZFS txg_monitor already running for zpool $poolname as PID $OPENZFS_TXG_MON_PID" $SPARTA_LOG $FF_DATE
        fi
    done
    unset IFS
}

function launch_openzfs_txg_full
{
    IFS=", 	"
    for poolname in $ZPOOL_NAME
    do
        PGREP_STRING="$OPENZFS_TXG_FULL $poolname"
        OPENZFS_TXG_FULL_PID="`pgrep -fl "$PGREP_STRING" | awk '{print $1}'`"
        if [ "x$OPENZFS_TXG_FULL_PID" == "x" ]; then
            $OPENZFS_TXG_FULL $poolname | $ROTATELOGS $LOG_DIR/samples/zfstxg_full_${poolname}.out.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME 2>&1 &
            print_to_log "  Started OpenZFS TXG full on $poolname" $SPARTA_LOG $FF_DATE
        else
            print_to_log "  OpenZFS TXG full already running for zpool $poolname as PID $OPENZFS_TXG_FULL_PID" $SPARTA_LOG $FF_DATE
        fi
    done
    unset IFS
}

function launch_metaslab
{
    IFS=", 	"
    for poolname in $ZPOOL_NAME
    do
        PGREP_STRING="$METASLAB_ALLOC -p $poolname"
        METASLAB_MON_PID="`pgrep -fl "$PGREP_STRING" | awk '{print $1}'`"
        if [ "x$METASLAB_MON_PID" == "x" ]; then
            $METASLAB_ALLOC -p $poolname | $ROTATELOGS $LOG_DIR/samples/metaslab_${poolname}.out.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME 2>&1 &
            print_to_log "  Started metaslab monitoring on $poolname" $SPARTA_LOG $FF_DATE
        else
            print_to_log "  metaslab monitoring already running for zpool $poolname as PID $METASLAB_MON_PID" $SPARTA_LOG $FF_DATE
        fi
    done
    unset IFS
}

function launch_msload
{
    MSLOAD_PID="$(pgrep -fl $MSLOAD | awk '{print $1}')"
    if [ "x$MSLOAD_PID" == "x" ]; then
        $MSLOAD $MSLOAD_TIME | $ROTATELOGS $LOG_DIR/samples/msload.out.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME 2>&1 &
        print_to_log "  Started msload monitoring" $SPARTA_LOG $FF_DATE
    else
        print_to_log "  msload.d already running as PID $MSLOAD_PID" $SPARTA_LOG $FF_DATE
    fi
}

function launch_arc_adjust
{
    ARC_ADJUST_PID="`pgrep -fl $ARC_ADJUST | awk '{print $1}'`"
    if [ "x$ARC_ADJUST_PID" == "x" ]; then
        $ARC_ADJUST | $ROTATELOGS $LOG_DIR/samples/arc_adjust.out.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME 2>&1 &
        print_to_log "  Started ARC adjust monitoring" $SPARTA_LOG $FF_DATE
    else
        print_to_log "  arc_adjust already running as PID $ARC_ADJUST_PID" $SPARTA_LOG $FF_DATE
    fi
}

function launch_arc_meta
{
    ARC_META_PID="`pgrep -fl $ARC_META | awk '{print $1}'`"
    if [ "x$ARC_META_PID" == "x" ]; then
        $ARC_META | $ROTATELOGS $LOG_DIR/samples/arc_meta.out.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME 2>&1 &
        print_to_log "  Started ARC metadata monitoring" $SPARTA_LOG $FF_DATE
    else
        print_to_log "  arc_meta.sh already running as PID $ARC_META_PID" $SPARTA_LOG $FF_DATE
    fi
}

function gather_arc_mdb
{
    $LOG_LAUNCHERS/arc_mdb.sh &
}

function obsolete_gather_arc_mdb
{
    for x in {1..3}
    do
        print_to_log "  arc statistics - sample ${x}" $SPARTA_LOG $FF_DATE
        print_to_log "::arc data - sample ${x}" $LOG_DIR/samples/arc.out $FF_DATE_SEP
        $ECHO "::arc" | $MDB -k >> $LOG_DIR/samples/arc.out
        $ECHO ".\c"
        cursor_pause 5
    done 
}

function launch_arcstat
{
    ARCSTAT_PL_PID="`pgrep -fl $ARCSTAT_PL | awk '{print $1}'`"
    if [ "x$ARCSTAT_PL_PID" == "x" ]; then
        $ARCSTAT_PL $ARCSTAT_SLEEP | $ROTATELOGS $LOG_DIR/samples/arcstat.out.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME 2>&1 &
        print_to_log "  Started ARCstat monitoring" $SPARTA_LOG $FF_DATE
    else
        print_to_log "  arcstat.pl already running as PID $ARCSTAT_PL_PID" $SPARTA_LOG $FF_DATE
    fi
}

function gather_arc_prefetch_stats
{
    $LOG_LAUNCHERS/arc_prefetch.sh &
}

function obsolete_gather_arc_prefetch_stats
{
    for x in {1..3}
    do
        print_to_log "  arc prefetch kstats - sample ${x}" $SPARTA_LOG $FF_DATE
        print_to_log "kstat zfetchstats - sample ${x}" $LOG_DIR/samples/arc.prefetch.kstat $FF_DATE_SEP
        kstat -m zfs -n zfetchstats >> $LOG_DIR/samples/arc.prefetch.kstat
        $ECHO ".\c"
        cursor_pause 5
    done
}

function launch_zil_commit
{
    ZIL_COMMIT_TIME_PID="`pgrep -fl $ZIL_COMMIT_TIME | awk '{print $1}'`"
    if [ "x$ZIL_COMMIT_TIME_PID" == "x" ]; then
        $ZIL_COMMIT_TIME | $ROTATELOGS $LOG_DIR/samples/zil_commit.out.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME 2>&1 &
        print_to_log "  Started zil commit time sampling" $SPARTA_LOG $FF_DATE
    else
        print_to_log "  zil commit time script already running as PID $ZIL_COMMIT_TIME_PID" $SPARTA_LOG $FF_DATE
    fi
}

#
# This is the partially adapted script from Matt Ahrens
#
function launch_zil_commit_watch
{
    ZIL_COMMIT_WATCH_PID="`pgrep -fl $ZIL_COMMIT_WATCH | awk '{print $1}'`"
    if [ "x$ZIL_COMMIT_WATCH_PID" == "x" ]; then
        $ZIL_COMMIT_WATCH | $ROTATELOGS $LOG_DIR/samples/zil_commit_watch.out.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME 2>&1 &
        print_to_log "  Started zil commit watch sampling" $SPARTA_LOG $FF_DATE
    else
        print_to_log "  zil commit watch script already running as PID $ZIL_COMMIT_WATCH_PID" $SPARTA_LOG $FF_DATE
    fi
}

function launch_zil_use_slog
{
    ZIL_USE_SLOG_PID="$(pgrep -fl $ZIL_USE_SLOG | awk '{print $1}')"
    if [ "x$ZIL_USE_SLOG_PID" == "x" ]; then
        $ZIL_USE_SLOG | $ROTATELOGS $LOG_DIR/samples/zil_use_slog.out.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME 2>&1 &
        print_to_log "  Started zil_use_slog sampling" $SPARTA_LOG $FF_DATE
    else
        print_to_log "  zil_use_slog script already running as PID $ZIL_USE_SLOG_PID" $SPARTA_LOG $FF_DATE
    fi
} 

function launch_zil_lwb_write
{
    ZIL_LWB_WRITE_PID="$(pgrep -fl $ZIL_LWB_WRITE | awk '{print $1}')"
    if [ "x$ZIL_LWB_WRITE_PID" == "x" ]; then
        $ZIL_LWB_WRITE | $ROTATELOGS $LOG_DIR/samples/zil_lwb_write.out.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME 2>&1 &
        print_to_log "  Started zil_lwb_write sampling" $SPARTA_LOG $FF_DATE
    else
        print_to_log "  zil_lwb_write script already running as PID $ZIL_LWB_WRITE_PID" $SPARTA_LOG $FF_DATE
    fi
} 



function launch_zil_stat
{
    ZIL_STAT_PID="`pgrep -fl zil_stat\.d | awk '{print $1}'`"
    if [ "x$ZIL_STAT_PID" == "x" ]; then
        $ZIL_STAT $ZIL_STAT_OPTS | $ROTATELOGS $LOG_DIR/samples/zilstat.out.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME 2>&1 &
        print_to_log "  Started zil statistics sampling" $SPARTA_LOG $FF_DATE
    else
        print_to_log "  zil statistics script already running as PID $ZIL_STAT_PID" $SPARTA_LOG $FF_DATE
    fi
}

function gather_zfs_mdb
{
    for tunable in $ZFS_TUNABLE_LIST
    do
        $ECHO "${tunable} : \c" > $LOG_DIR/mdb/mdb.${tunable}
        $ECHO "${tunable}::print -d" | $MDB -k >> $LOG_DIR/mdb/mdb.${tunable} 2>&1
    done
}

function gather_zfs_params
{
    $ECHO "zfs_params\n----------\n" > $LOG_DIR/mdb/mdb.zfs_params
    $ECHO "::zfs_params" | $MDB -k >> $LOG_DIR/mdb/mdb.zfs_params 2>&1
}

function gather_zpool_status
{
    $ZPOOL status >> $LOG_DIR/samples/zpool_status.out 2>&1
}

function gather_zpool_list
{
    $ZPOOL list >> $LOG_DIR/samples/zpool_list.out 2>&1
}

function gather_zfs_get
{
    IFS=", 	"
    for poolname in $ZPOOL_NAME
    do
        $ZFS get -r all $poolname >> $LOG_DIR/samples/zfs_get-r_all.${poolname}.out 2>&1
    done
    unset IFS
}

function launch_large_file_delete
{
    LARGE_DELETE_PID="`pgrep -fl $LARGE_DELETE | awk '{print $1}'`"
    if [ "x$LARGE_DELETE_PID" == "x" ]; then
        $LARGE_DELETE 2>&1 | $ROTATELOGS $LOG_DIR/samples/large_delete.out.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME 2>&1 &
        print_to_log "  Started monitoring of large deletes" $SPARTA_LOG $FF_DATE
    else
        print_to_log "  large delete script already running as PID $LARGE_DELETE_PID" $SPARTA_LOG $FF_DATE
    fi
}

function gather_zpool_iostat
{
    IFS=", 	"
    for poolname in $ZPOOL_NAME
    do
        PGREP_STRING="$ZPOOL iostat $ZPOOL_IOSTAT_OPTS $poolname $ZPOOL_IOSTAT_FREQ"
        ZPOOL_IOSTAT_PID="`pgrep -fl "$PGREP_STRING" | awk '{print $1}'`"
        if [ "x$ZPOOL_IOSTAT_PID" == "x" ]; then
            $ZPOOL iostat $ZPOOL_IOSTAT_OPTS $poolname $ZPOOL_IOSTAT_FREQ | $ROTATELOGS $LOG_DIR/samples/zpool_iostat_${poolname}.out.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME 2>&1 &
            print_to_log "Started zpool iostat $ZPOOL_IOSTAT_OPTS $poolname $ZPOOL_IOSTAT_FREQ" $SPARTA_LOG $FF_DATE
        else
            print_to_log "zpool iostat already running for zpool $poolname as PID $ZPOOL_IOSTAT_PID" $SPARTA_LOG $FF_DATE
        fi
    done
    unset IFS
}

function launch_rwlatency
{
    RWLATENCY_PID="`pgrep -fl $RWLATENCY | awk '{print $1}'`"
    if [ "x$RWLATENCY_PID" == "x" ]; then
	$RWLATENCY | $ROTATELOGS $LOG_DIR/samples/rwlatency.out.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME 2>&1 &
	print_to_log "  Started R/W latency sampling" $SPARTA_LOG $FF_DATE
    else
	print_to_log "  R/W latency monitoring is already running as PID $RWLATENCY_PID" $SPARTA_LOG $FF_DATE
    fi
}

function launch_delay_mintime
{
    DELAY_MINTIME_PID="`pgrep -fl $DELAY_MINTIME | awk '{print $1}'`"
    if [ "x$DELAY_MINTIME_PID" == "x" ]; then
	$DELAY_MINTIME | $ROTATELOGS $LOG_DIR/samples/delay_mintime.out.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME 2>&1 &
	print_to_log "  Started OpenZFS write delay sampling" $SPARTA_LOG $FF_DATE
    else
	print_to_log "  OpenZFS write delay monitoring is already running as PID $DELAY_MINTIME_PID" $SPARTA_LOG $FF_DATE
    fi
}


### OS specific functions defined here

function launch_dnlc
{
    DNLC_LOOKUP_PID="`pgrep -fl $DNLC_LOOKUPS | awk '{print $1}'`"
    if [ "x$DNLC_LOOKUP_PID" == "x" ]; then
        $DNLC_LOOKUPS | $ROTATELOGS $LOG_DIR/samples/dnlc_lookups.out.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME 2>&1 &
        print_to_log "  Started DNLC lookup sampling" $SPARTA_LOG $FF_DATE
    else
        print_to_log "  DNLC lookups already running as PID $DNLC_LOOKUPS_PID" $SPARTA_LOG $FF_DATE
    fi
}

function gather_memstat
{
    $LOG_LAUNCHERS/memstat.sh &
}

function obsolete_gather_memstat
{
    for x in {1..3}
    do
        print_to_log "  memory statistics - sample ${x}" $SPARTA_LOG $FF_DATE
        print_to_log "::memstat data - sample ${x}" $LOG_DIR/samples/memstat.out $FF_DATE_SEP
        $ECHO "::memstat" | $MDB -k >> $LOG_DIR/samples/memstat.out
        $ECHO ".\c"
        cursor_pause 5
    done
}

function gather_uptime
{
    print_to_log "  uptime statistics" $SPARTA_LOG $FF_DATE
    $UPTIME > $LOG_DIR/samples/uptime.out
}

function gather_process_data
{
    print_to_log "  process information" $SPARTA_LOG $FF_DATE
    $DATE +%Y-%m-%d_%H:%M:%S > $LOG_DIR/samples/ps.out
    $ECHO "-------------------" >> $LOG_DIR/samples/ps.out
    $PS $PS_OPTS >> $LOG_DIR/samples/ps.out

    $DATE +%Y-%m-%d_%H:%M:%S > $LOG_DIR/samples/ptree.out
    $ECHO "-------------------" >> $LOG_DIR/samples/ptree.out
    $PTREE $PTREE_OPTS >> $LOG_DIR/samples/ptree.out
}

## Disk specific functions defined here

function launch_iostat
{
    PGREP_STRING="$IOSTAT $IOSTAT_OPTS"
    $PGREP -fl "$PGREP_STRING" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        $IOSTAT $IOSTAT_OPTS | $ROTATELOGS $LOG_DIR/samples/iostat.out.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME 2>&1 &
	print_to_log "  Started iostat $IOSTAT_OPTS data collection" $SPARTA_LOG $FF_DATE
    else
        IOSTAT_PID="`pgrep -fl "$PGREP_STRING" | awk '{print $1}'`"
	print_to_log "  iostat disk statistic gathering already running as $IOSTAT_PID" $SPARTA_LOG $FF_DATE
    fi
}

function gather_iostat
{
    print_to_log "  getting disk error count (iostat -E)" $SPARTA_LOG $FF_DATE
    $IOSTAT $IOSTAT_INFO_OPTS >> $LOG_DIR/samples/iostat-En.out
}


### Filesystems specific functions defined here

function gather_fsstat
{
    print_to_log "Filesystem statistics" $SPARTA_LOG $FF_DATE
    $FSSTAT_SH $FSSTAT_OPTS >> $LOG_DIR/samples/fsstat.out &
}


### NFS specific functions defined here

function launch_nfs_io
{
    NFS_IO_PID="`pgrep -fl "$NFS_IO" | awk '{print $1}'`"
    if [ "x$NFS_IO_PID" == "x" ]; then
	$NFS_IO | $ROTATELOGS $LOG_DIR/samples/nfs_io.out.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME &
	print_to_log "  Started NFS file io monitoring" $SPARTA_LOG $FF_DATE
    else
 	print_to_log "  NFS file io monitoring alreading running as PID $NFS_IO_PID" $SPARTA_LOG $FF_DATE
    fi
}

function launch_nfs_thread_util
{
    NFS_THREADS_PID="`pgrep -fl "$NFS_THREADS" | awk '{print $1}'`"
    if [ "x$NFS_THREADS_PID" == "x" ]; then
	$NFS_THREADS | $ROTATELOGS $LOG_DIR/samples/nfs_threads.out.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME &
	print_to_log "  Started NFS thread monitoring" $SPARTA_LOG $FF_DATE
    else
	print_to_log "  NFS thread monitoring already running as PID $NFS_THREADS_PID" $SPARTA_LOG $FF_DATE
    fi
}

function launch_nfstop
{
    NFS_TOP_PID="`pgrep -fl 'dtrace .* nfssvrtop' | awk '{print $1}'`"
    if [ "x$NFS_TOP_PID" == "x" ]; then
	$NFS_TOP $NFSSVRTOP_OPTS | $ROTATELOGS $LOG_DIR/samples/nfssvrtop.out.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME &
	print_to_log "  Started NFS top monitoring" $SPARTA_LOG $FF_DATE
    else
	print_to_log "  NFS top monitoring already running as PID $NFS_TOP_PID" $SPARTA_LOG $FF_DATE
    fi
}

function launch_nfs_rwtime
{
    NFS_RWTIME_PID="`pgrep -fl "$NFS_RWTIME" | awk '{print $1}'`"
    if [ "x$NFS_RWTIME_PID" == "x" ]; then
	$NFS_RWTIME | $ROTATELOGS $LOG_DIR/samples/nfs_rwtime.out.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME &
	print_to_log "  Started NFS monitoring of top files being accessed" $SPARTA_LOG $FF_DATE
    else
	print_to_log "  NFS top files monitoring already running as PID $NFS_RWTIME_PID" $SPARTA_LOG $FF_DATE
    fi
}


function gather_nfs_tuning
{
    print_to_log "  NFS tuning parameters" $SPARTA_LOG $FF_DATE
    if [ $NEXENTASTOR_MAJ_VER -gt 3 ]; then
        print_to_log "ipadm _conn_req_max_q" $LOG_DIR/samples/ipadm.out $FF_DATE_SEP
        $IPADM show-prop -p _conn_req_max_q tcp >> $LOG_DIR/samples/ipadm.out
        $IPADM show-prop -p _conn_req_max_q0 tcp >> $LOG_DIR/samples/ipadm.out
    
        print_to_log "rpcbind listen backlog" $LOG_DIR/samples/rpcbind-smf-prop.out $FF_DATE_SEP
        $SVCPROP svc:/network/rpc/bind:default >> $LOG_DIR/samples/rpcbind-smf-prop.out
    else
	print_to_log "Unable to collect NFS tuning data, this is a NexentaStor $NEXENTASTOR_MAJ_VER release"
    fi
}


function gather_nfs_stat_server
{
    $LOG_LAUNCHERS/nfsstat.sh &
}

function obsolete_gather_nfs_stat_server
{
    print_to_log "  nfsstat -s" $SPARTA_LOG $FF_DATE
    print_to_log "nfsstat -s" $LOG_DIR/samples/nfsstat-s.out $FF_DATE_SEP
    $NFSSTAT $NFSSTAT_OPTS >> $LOG_DIR/samples/nfsstat-s.out 2>&1 & 2>&1 &
    $ECHO ".\c"
    cursor_pause 5
}

function gather_nfs_share_output
{
    print_to_log "  Collecting NFS share information" $SPARTA_LOG $FF_DATE
    $SHARECTL get nfs > $LOG_DIR/samples/sharectl_get_nfs.out
}


### ISCSI specific scripts defined here

function launch_iscsitop
{
    ISCSI_TOP_PID="`pgrep -fl 'dtrace .* iscsisvrtop' | awk '{print $1}'`"
    if [ "x$ISCSI_TOP_PID" == "x" ]; then
	$ISCSI_TOP $ISCSISVRTOP_OPTS | $ROTATELOGS $LOG_DIR/samples/iscsisvrtop.out.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME &
	print_to_log "Started ISCSI top monitoring" $SPARTA_LOG $FF_DATE
    else    
	print_to_log "  iSCSI top monitoring already running as PID $ISCSI_TOP_PID" $SPARTA_LOG $FF_DATE
    fi
}

function launch_iscsisnoop
{
    ISCSI_SNOOP_PID=$(pgrep -fl 'dtrace .* iscsisnoop' | awk '{print $1}')
    if [ "x$ISCSI_SNOOP_PID" == "x" ]; then
        $ISCSISNOOP | $ROTATELOGS $LOG_DIR/samples/iscsisnoop.out.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME &
	print_to_log "Started iSCSI snoop monitoring" $SPARTA_LOG $FF_DATE
    else
        print_to_log "  iSCSI snoop script already running as PID $ISCSI_SNOOP_PID" $SPARTA_LOG $FF_DATE
    fi
}


### COMSTAR/STMF/SBD specific scripts defined here

function launch_sbd_lu_rw
{
    PGREP_STRING="dtrace .*$SBD_LU_RW"
    SBD_LU_RW_PID="$(pgrep -fl "$PGREP_STRING" | awk '{print $1}')"
    if [ "x$SBD_LU_RW_PID" == "x" ]; then
	$SBD_LU_RW | $ROTATELOGS $LOG_DIR/samples/sbd_lu_rw.out.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME &
	print_to_log "  Started sbd_lu_rw monitoring" $SPARTA_LOG $FF_DATE
    else    
	print_to_log "  sbd_lu_rw monitoring already running as PID $SBD_LU_RW_PID" $SPARTA_LOG $FF_DATE
    fi
}

function launch_sbd_zvol_unmap
{
    PGREP_STRING="dtrace .*$SBD_ZVOL_UNMAP"
    SBD_ZVOL_UNMAP_PID="`pgrep -fl "$PGREP_STRING" | awk '{print $1}'`"
    if [ "x$SBD_ZVOL_UNMAP_PID" == "x" ]; then
	$SBD_ZVOL_UNMAP | $ROTATELOGS $LOG_DIR/samples/sbd_zvol_unmap.out.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME &
	print_to_log "  Started sbd_zvol_unmap monitoring" $SPARTA_LOG $FF_DATE
    else    
	print_to_log "  sbd_zvol_unmap monitoring already running as PID $SBD_ZVOL_UNMAP_PID" $SPARTA_LOG $FF_DATE
    fi
}

function launch_stmf_task_time
{
    PGREP_STRING="dtrace .*$STMF_TASK_TIME"
    STMF_TASK_TIME_PID="`pgrep -fl "$PGREP_STRING" | awk '{print $1}'`"
    if [ "x$STMF_TASK_TIME_PID" == "x" ]; then
	$STMF_TASK_TIME | $ROTATELOGS $LOG_DIR/samples/stmf_task_time.out.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME &
	print_to_log "  Started stmf_task_time monitoring" $SPARTA_LOG $FF_DATE
    else    
	print_to_log "  stmf_task_time monitoring already running as PID $STMF_TASK_TIME_PID" $SPARTA_LOG $FF_DATE
    fi
}

function gather_stmf_workers
{
    $LOG_LAUNCHERS/stmf_workers.sh &
}

function obsolete_gather_stmf_workers
{
    for x in {1..10}
    do
        print_to_log "  stmf current worker backlog statistics - sample ${x}" $SPARTA_LOG $FF_DATE
        print_to_log "stmf current worker backlog info - sample ${x}" $LOG_DIR/samples/stmf_worker_backlog.out $FF_DATE_SEP
        $ECHO "stmf_cur_ntasks::print -d" | $MDB -k >> $LOG_DIR/samples/stmf_worker_backlog.out
        $ECHO ".\c"
        cursor_pause 5
    done
}

function launch_stmf_threads
{
    PGREP_STRING="dtrace .*$STMF_THREADS"
    STMF_THREADS_PID="`pgrep -fl "$PGREP_STRING" | awk '{print $1}'`"
    if [ "x$STMF_THREADS_PID" == "x" ]; then
	$STMF_THREADS | $ROTATELOGS $LOG_DIR/samples/stmf_threads.out.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME &
	print_to_log "  Started stmf_threads monitoring" $SPARTA_LOG $FF_DATE
    else    
	print_to_log "  stmf_threads monitoring already running as PID $STMF_THREADS_PID" $SPARTA_LOG $FF_DATE
    fi
}



### CIFS specific scripts defined here

function launch_cifs_top
{
    CIFS_TOP_PID="`pgrep -fl 'dtrace .* cifssvrtop' | awk '{print $1}'`"
    if [ "x$CIFS_TOP_PID" == "x" ]; then
	$CIFS_TOP $CIFSSVRTOP_OPTS | $ROTATELOGS $LOG_DIR/samples/cifssvrtop.out.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME &
	print_to_log "Started CIFS top monitoring" $SPARTA_LOG $FF_DATE
    else    
	print_to_log "  CIFS top monitoring already running as PID $CIFS_TOP_PID" $SPARTA_LOG $FF_DATE
    fi
}

function gather_cifs_share_output
{
    print_to_log "Collecting CIFS share information" $SPARTA_LOG $FF_DATE
    $SHARECTL get smb > $LOG_DIR/samples/sharectl_get_smb.out
}

function launch_cifs_util
{
    $PGREP -fl "$SMBSTAT $SMB_UTIL_OPTS" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
	$SMBSTAT $SMB_UTIL_OPTS | $ROTATELOGS $LOG_DIR/samples/${1}.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME 2>&1 &
    fi
}

function launch_cifs_ops
{
    $SMBSTAT -r > $LOG_DIR/samples/smbstat-r.epoch.out
    $PGREP -fl "$SMBSTAT $SMB_OPS_OPTS" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
	$SMBSTAT $SMB_OPS_OPTS | $ROTATELOGS $LOG_DIR/samples/${1}.%Y-%m-%d_%H_%M $LOG_ROTATE_TIME 2>&1 &
    fi
}


### Package management functions

function gather_pkg_info
{
    case $NEXENTASTOR_MAJ_VER in
	4 ) dpkg -l > $LOG_DIR/dpkg-l.out 2>&1
	    ;;
	5 ) pkg info > $LOG_DIR/pkg-info.out 2>&1
	    pkg history -l > $LOG_DIR/pkg-history-l.out 2>&1
	    ;;
    esac
}


### NEF (NexentaStor 5.x CLI) specific stuff

function gather_nef_config
{
    case $NEXENTASTOR_MAJ_VER in
        5) $NEFCLI_CONFIG_CMD list > $LOG_DIR/nefcli.config.out 2>&1
           ;;
    esac
}


$ECHO "Nexenta Performance gathering script ($SPARTA_VER)"
$ECHO "====================================\n"

#
# NexentaStor 5 GA (5.0.1) ships without the required libraries to run the rotatelogs script
# It's fairly trivial to install but we need to check, otherwise you get lots of errors
#

if [ $NEXENTASTOR_MAJ_VER == "5" ]; then
    pkg info -q pkg:/library/apr-util
    if [ $? -ne 0 ]; then
        $ECHO "Package pkg:/library/apr-util is missing, which will prevent log files from rotating."
        $ECHO "Failure to install this package means that SPARTA will not run.\n"
        $ECHO "Would you like me to install the missing package? (y|n) \c"
        read INSTALL_ME
        INSTALL_ME="`$ECHO $INSTALL_ME | $TR '[:upper:]' '[:lower:]'`"
        if [ "$INSTALL_ME" == "y" ]; then
            pkg install -q pkg:/library/apr-util
            ERR_CODE=$?
            if [ $ERR_CODE -ne 0 ]; then
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


#
# Check to see whether there is an updated version of SPARTA online
# If so we need to exec the auto-install utility that we've pulled down as we can't
# update ourselves, whilst running.
# At the end of the auto-install, that utility re-invokes sparta.sh again.
#
# Controlled by the UPDATE_OPT in the sparta.config file or sparta.sh -u {yes|no}
# in reality only supplying yes will allow the upgrade check to proceed.
#

if [ "$UPDATE_OPT" == "yes" ]; then
    $ECHO "Checking SPARTA version online"
    bootstrap

    if [ $? -eq 1 ]; then
        $ECHO "Attempting to download current version of SPARTA"

        pull_me $SPARTA_URL $SPARTA_FILE
        if [ $? -eq 0 ]; then
            pull_me $SPARTA_UPDATER_URL $SPARTA_UPDATER
            if [ $? -eq 0 ]; then
	        #
	        # Looks like we've successfully pulled down the new SPARTA tarball and installer
	        # so lets invoke the auto-install utility to get upto date binaries
	        #
		chmod 700 $SPARTA_UPDATER
                exec $SPARTA_UPDATER $SPARTA_FILE /tmp/$SPARTA_HASH $INPUT_ARGS
            else
                $ECHO "Unable to download the auto-updater"
            fi
        else
            $ECHO "Unable to download the current SPARTA tarball"
        fi

    else
        $ECHO "Most recent version of SPARTA already installed"
    fi
fi


#
# Check for any running scrubs
#
$ECHO "Checking for active scrubs on imported zpools"
$ECHO "Please NOTE: scrubs can have an impact on zpool performance, affecting latency and throughput"
$ECHO ""
check_for_scrub
$ECHO ""
$ECHO ""


#
# Performance samples used to be collated by day, however by switching over to including the datestamp
# as part of the filename so we can deal with rotating logs, having a directory based on the date
# was considered redundant.
#
if [ ! -d $LOG_DIR/samples ]; then
    $MKDIR -p $LOG_DIR/samples
    if [ $? -ne 0 ]; then
	$ECHO "Unable to create $LOG_DIR/samples directory to capture statistics"
	exit 1
    fi
fi

if [ ! -d $LOG_DIR/samples/watch_cpu ]; then
    $MKDIR -p $LOG_DIR/samples/watch_cpu
    if [ $? -ne 0 ]; then
        $ECHO "Unable to create $LOG_DIR/samples/watch_cpu directory for cpu utilisation monitor"
        exit 1
    fi
fi

if [ ! -d $LOG_DIR/mdb ]; then
    $MKDIR $LOG_DIR/mdb
fi

if [ ! -d $LOG_KERNEL_TUNABLES ]; then
    $MKDIR $LOG_KERNEL_TUNABLES
fi


#
# Let's check to see if we should purge/zap some data before collecting new data
#
$ECHO "Checking $LOG_DIR for excessive historical data\n"
PERFLOG_USAGE="`calc_space $LOG_DIR`"
if [ $PERFLOG_USAGE -gt $PURGE_LOG_WARNING ]; then
    $ECHO "The $LOG_DIR has more than `expr $PURGE_LOG_WARNING / $GIGABYTE` GB of data already collected."
    $ECHO "This is likely to be historical data that is no longer required."
    $ECHO "Would you like me to zap this data ? \c"
    PURGE_ANS="n"
    while [ true ]; do
        $ECHO "(y|n) : \c"
        read PURGE_ANS
        if [ `echo $PURGE_ANS | wc -c` -lt 2 ]; then
            continue;
        fi
        PURGE_ANS="`$ECHO $PURGE_ANS | $TR '[:upper:]' '[:lower:]'`"
        if [ "$PURGE_ANS" == "y" -o "$PURGE_ANS" == "n" ]; then
            break
        fi
    done
    if [ "$PURGE_ANS" == "y" ]; then
        zap_logs
    fi
else
    echo "Log space usage was under `expr $PURGE_LOG_WARNING / $GIGABYTE` GB"
fi


#
# Collect the defined configuration and other files of interest
#

$ECHO "Collecting configuration and other files of interest ... \c"
print_to_log "#############################" $SPARTA_LOG $FF_NEWL

print_to_log "Collecting configuration files first" $SPARTA_LOG $FF_DATE
for config_file in ${CONFIG_FILE_LIST}
do
    if [ -r $config_file ]; then
#        $CP $config_file $LOG_DIR/
        ($FIND $config_file -print | $CPIO -pdum $LOG_KERNEL_TUNABLES) > /dev/null 2>&1
    else
	print_to_log "  missing file - $config_file" $SPARTA_LOG
    fi
done

FILE_LIMIT="`expr $MEGABYTE \* 50`"
for other_file in ${OTHER_FILE_LIST}
do
    if [ -r $other_file ]; then
        FILESIZE="`$STAT -c%s $other_file`"
        if [ $FILESIZE -lt $FILE_LIMIT ]; then
	    $CP $other_file $LOG_DIR/
        else
            $ECHO "File exceeded $FILE_LIMIT - did not collect" > $LOG_DIR/`basename $other_file`
	fi
    else
	print_to_log "  missing file - $other_file" $SPARTA_LOG
    fi
done


# Get information on installed packages
gather_pkg_info

# Get the NEF configuration
gather_nef_config

$ECHO "done"


#
# Start collecting data
#

$ECHO "Starting dtrace script collection"
print_to_log "Starting collection of performance data" $SPARTA_LOG $FF_DATE

#
# CPU/load based scripts invoked here
#
$ECHO "Starting CPU data gathering \c"
array_limit=$(expr ${#CPU_ENABLE_LIST[@]} - 1)
for item in `seq 0 $array_limit`
do
    if [ ${CPU_ENABLE_LIST[$item]} -eq 1 ]; then
        do_log ${CPU_NAME_LIST[$item]}

        ${CPU_COMMAND_LIST[$item]} ${CPU_NAME_LIST[$item]}

        $ECHO ".\c"
    fi
done
$ECHO " done"


# 
# Kernel specific scripts invoked here
#
$ECHO "Starting Kernel data gathering \c"
array_limit=$(expr ${#KERNEL_ENABLE_LIST[@]} - 1)
for item in `seq 0 $array_limit`
do
    if [ ${KERNEL_ENABLE_LIST[$item]} -eq 1 ]; then
        do_log ${KERNEL_NAME_LIST[$item]}
	${KERNEL_COMMAND_LIST[$item]} ${KERNEL_NAME_LIST[$item]}
	$ECHO ".\c"
    fi
done
$ECHO " done"


#
# OS specific scripts invoked here
#
$ECHO "Starting OS data gathering \c"
array_limit=$(expr ${#OS_ENABLE_LIST[@]} - 1)
for item in `seq 0 $array_limit`
do
    if [ ${OS_ENABLE_LIST[$item]} -eq 1 ]; then
        do_log ${OS_NAME_LIST[$item]}
	${OS_COMMAND_LIST[$item]} ${OS_NAME_LIST[$item]}
        $ECHO ".\c"
    fi
done
$ECHO " done"


#
# Disk specific scripts invoked here
#
$ECHO "Starting Disk data gathering \c"
array_limit=$(expr ${#DISK_ENABLE_LIST[@]} - 1)
for item in `seq 0 $array_limit`
do
    if [ ${DISK_ENABLE_LIST[$item]} -eq 1 ]; then
        do_log ${DISK_NAME_LIST[$item]}
	${DISK_COMMAND_LIST[$item]} ${DISK_NAME_LIST[$item]}
        $ECHO ".\c"
    fi
done
$ECHO " done"


#
# Filesystem specific scripts invoked here
#
$ECHO "Starting Filesystem statistics gathering .\c"
array_limit=$(expr ${#FILESYS_ENABLE_LIST[@]} - 1)
for item in `seq 0 $array_limit`
do
    if [ ${FILESYS_ENABLE_LIST[$item]} -eq 1 ]; then
        do_log ${FILESYS_NAME_LIST[$item]}
        ${FILESYS_COMMAND_LIST[$item]} ${FILESYS_NAME_LIST[$item]}
        $ECHO ".\c"
    fi
done
$ECHO " done"


#
# Determine whether we're performing extended NFS monitoring via dtrace
# and collecting other NFS statistics
#

NFSSRV_LOADED="`$MODINFO | $GREP nfssrv | awk '{print $6}'`"
if [ "$TRACE_NFS" == "y" -a "x$NFSSRV_LOADED" == "xnfssrv" ]; then
    let item=0
    $ECHO "Starting NFS data gathering \c"
    array_limit=$(expr ${#NFS_ENABLE_LIST[@]} - 1)
    for item in `seq 0 $array_limit`
    do
        if [ ${NFS_ENABLE_LIST[$item]} -eq 1 ]; then
            ${NFS_COMMAND_LIST[$item]} ${NFS_NAME_LIST[$item]}
            $ECHO ".\c"
        fi
    done
    $ECHO " done"
fi


#
# Determine whether we're performing extended iSCSI monitoring using dtrace
#

ISCSISRV_LOADED="`$MODINFO | awk '/iscsit \(iSCSI Target\)/ {print $6}'`"
if [ "$TRACE_ISCSI" == "y" -a "x$ISCSISRV_LOADED" == "xiscsit" ]; then
    $ECHO "Starting iSCSI data gathering \c"
    array_limit=$(expr ${#ISCSI_ENABLE_LIST[@]} - 1)
    for item in `seq 0 $array_limit`
    do
        if [ ${ISCSI_ENABLE_LIST[$item]} -eq 1 ]; then
            ${ISCSI_COMMAND_LIST[$item]} ${ISCSI_NAME_LIST[$item]}
            $ECHO ".\c"
        fi
    done
    $ECHO " done"
fi


#
# Determine whether we're performing extended COMSTAR monitoring using dtrace
#

STMFSRV_LOADED="`$MODINFO | awk '/stmf \(COMSTAR STMF\)/ {print $6}'`"
if [ "$TRACE_STMF" == "y" -a "x$STMFSRV_LOADED" == "xstmf" ]; then
    $ECHO "Starting COMSTAR data gathering \c"
    array_limit=$(expr ${#COMSTAR_ENABLE_LIST[@]} - 1)
    for item in `seq 0 $array_limit`
    do
        if [ ${COMSTAR_ENABLE_LIST[$item]} -eq 1 ]; then
            do_log ${COMSTAR_NAME_LIST[$item]}
            ${COMSTAR_COMMAND_LIST[$item]} ${COMSTAR_NAME_LIST[$item]}
            $ECHO ".\c"
        fi
    done
    $ECHO " done"
fi


#
#
# Determine whether we're performing extended CIFS monitoring using dtrace
# and collecting other CIFS statistics
#
CIFSSRV_LOADED="`$MODINFO | awk '/smbsrv \(CIFS Server Protocol\)/ {print $6}'`"
if [ "$TRACE_CIFS" == "y" -a "x$CIFSSRV_LOADED" == "xsmbsrv" ]; then
    $ECHO "Starting CIFS data gathering \c"
    array_limit=$(expr ${#CIFS_ENABLE_LIST[@]} - 1)
    for item in `seq 0 $array_limit`
    do
        if [ ${CIFS_ENABLE_LIST[$item]} -eq 1 ]; then
            do_log ${CIFS_NAME_LIST[$item]}
            ${CIFS_COMMAND_LIST[$item]} ${CIFS_NAME_LIST[$item]}
            $ECHO ".\c"
        fi
    done
    $ECHO " done"
fi


#
# ZFS specific scripts invoked here
#
$ECHO "Starting ZFS data gathering \c"
array_limit=$(expr ${#ZFS_ENABLE_LIST[@]} - 1)
for item in `seq 0 $array_limit`
do
    if [ ${ZFS_ENABLE_LIST[$item]} -eq 1 ]; then
	do_log ${ZFS_NAME_LIST[$item]}
	${ZFS_COMMAND_LIST[$item]} ${ZFS_NAME_LIST[$item]}
        $ECHO ".\c"
    fi
done
$ECHO " done"


#
# Network specific scripts invoked here
#
$ECHO "Starting Network data gathering \c"
array_limit=$(expr ${#NETWORK_ENABLE_LIST[@]} - 1)
for item in `seq 0 $array_limit`
do
    if [ ${NETWORK_ENABLE_LIST[$item]} -eq 1 ]; then
	do_log ${NETWORK_NAME_LIST[$item]}
	${NETWORK_COMMAND_LIST[$item]} ${NETWORK_NAME_LIST[$item]}
	$ECHO ".\c"
    fi
done
$ECHO " done"


#
# Invoke the SPARTA watchdog monitor to prevent filling up the monitoring zpool
#
SHIELD_PID="`pgrep -fl \"$SPARTA_SHIELD\" | awk '{print $1}'`"
if [ "x${SHIELD_PID}" == "x" ]; then
    print_to_log "Starting SPARTA watchdog monitor" $SPARTA_LOG $FF_DATE
    $NOHUP $SPARTA_SHIELD >> $SPARTA_LOG 2>&1 &
else
    print_to_log "SPARTA watchdog monitor already running as PID $SHIELD_PID" $SPARTA_LOG $FF_DATE
fi


#
# End of data collection
#
print_to_log "Finished collecting data, although dtrace scripts continue to run in background." $SPARTA_LOG $FF_DATE

$ECHO "\nPerformance script has completed, dtrace scripts continue to run in background."
$ECHO "It may take upto several hours for the dtrace scripts to build up a profile of"
$ECHO "the problem, so it may be expected to revisit and re-upload those particular"
$ECHO "log files at a later date.\n"

$DATE +%Y-%m-%d_%H:%M:%S > $SPARTA_ETC/.lastran

$ECHO "Once at least 30 minutes has elapsed, please generate a tarball of the data using:\n"
$ECHO "bash# /perflogs/scripts/sparta.sh tarball"

#$ECHO "Would you like to generate a tarball of the data collected so far? \c"
#TARBALL_ANS="n"
#while [ true ]; do
#    $ECHO "(y|n) : \c"
#    read TARBALL_ANS
#    if [ `echo $TARBALL_ANS | wc -c` -lt 2 ]; then
#        continue;
#    fi
#    TARBALL_ANS="`$ECHO $TARBALL_ANS | $TR '[:upper:]' '[:lower:]'`"
#    if [ "$TARBALL_ANS" == "y" -o "$TARBALL_ANS" == "n" ]; then
#        break
#    fi
#done
#if [ "$TARBALL_ANS" == "y" ]; then
#    generate_tarball
#fi   

exit 0
