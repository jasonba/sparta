#!/bin/bash

#
# Program	: sparta.sh
# Author	: Jason.Banham@Nexenta.COM
# Date		: 2013-02-04 - 2014-05-115-11
# Version	: 0.34
# Usage		: sparta.sh [ -h | -help | start | status | stop | tarball ]
# Purpose	: Gather performance statistics for a NexentaStor appliance
# Legal		: Copyright 2013 and 2014, Nexenta Systems, Inc. 
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
#		  
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
    $ECHO "Usage: `basename $0` [-h] [-C|-I|-N|-S] [-p zpoolname] -u [ yes | no ] [-P protocol,protocol...] { start | stop | status | tarball | version }\n"
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
    $ECHO ""
    $ECHO "The following are valid optional arguments:\n"
    $ECHO "  -C              : Enable CIFS data collection (in addition to existing protocols)"
    $ECHO "  -I              : Enable iSCSI data collection (in addition to existing protocols)"
    $ECHO "  -N              : Enable NFS data collection (in addition to existing protocols)"
    $ECHO "  -S		     : Enable STMF (COMSTAR) data collection (in addition to existing protocols)"
    $ECHO "  -p <zpoolname>  : Monitor the given ZFS pool(s)"
    $ECHO "  -u [ yes | no ] : Enable or disable the automatic update feature"
    $ECHO "  -P <protocol>   : Enable *only* the given protocol(s) nfs iscsi cifs stmf or a combination"
    $ECHO "                    of multiple protocols, eg: -P nfs,cifs"
    $ECHO ""
    $ECHO "  -v              : display the version."
    $ECHO "  -help | -h | -? : display this help page.\n"

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
    $ECHO "Progress and pausing\n--------------------"
    $ECHO "  During collection you'll see dots (.) to indicate progress is being made and"
    $ECHO "  also a spinning cursor whilst data is being sampled.  When some processing is"
    $ECHO "  taking place you'll see the cursor change to Zzz to indicate this, before it"
    $ECHO "  changes back to a spinning cursor."
    $ECHO ""
}


#
# Display a status of the scripts we're interested in / have invoked
# this includes dtrace and other scripts
#
function script_status
{
    pgrep -fl 'dtrace .* [/perflogs|nfssvrtop|cifssvrtop|iscsisvrtop|metaslab]'
    pgrep -fl $ARCSTAT_PL
    pgrep -fl $LOCKSTAT_SPARTA
    pgrep -fl "$VMSTAT $VMSTAT_OPTS"
    pgrep -fl "$MPSTAT $MPSTAT_OPTS"
    pgrep -fl "$IOSTAT $IOSTAT_OPTS"
    pgrep -fl "$PRSTAT $PRSTAT_OPTS"
    pgrep -fl "$SPARTA_SHIELD"
    pgrep -fl "$ZPOOL iostat $ZPOOL_IOSTAT_OPTS"
}


#
# Kill a list of performance monitoring scripts
#
function script_kill
{
    pkill -f 'dtrace .* [/perflogs|nfssvrtop|cifssvrtop|iscsisvrtop]'
    pkill -f $ARCSTAT_PL
    pkill -f $LOCKSTAT_SPARTA
    pkill -f "$VMSTAT $VMSTAT_OPTS"
    pkill -f "$MPSTAT $MPSTAT_OPTS"
    pkill -f "$IOSTAT $IOSTAT_OPTS"
    pkill -f "$PRSTAT $PRSTAT_OPTS"
    pkill -f "$ZPOOL iostat $ZPOOL_IOSTAT_OPTS"
}
 

#
# Format flags used by print_to_log and callers
#
FF_DATE=1
FF_SEP=2
FF_DATE_SEP=3
FF_NEWL=4

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
# The function print_to_log takes a message and prints it to a log file and stdout
# it can also take another argument to prettify the formatting, inserting a seperator
# and newlines, where appropriate.
#
# arg 1 = The message to send
# arg 2 = The log file to write to
# arg 3 = The formatting flag
#
function print_to_log
{
    PREFIX=""
    POSTFIX=""

    case $3 in 
              1 )
 		PREFIX="${PREFIX}`$DATE +%Y-%m-%d_%H:%M:%S` "
		;;
	      2 )
		POSTFIX="${POSTFIX}\n---"
		;;
	      3 )
                PREFIX="$PREFIX`$DATE +%Y-%m-%d_%H:%M:%S` "
		POSTFIX="$POSTFIX\n---"
		;;
	      4 )
		POSTFIX="$POSTFIX\n"
		;;
	      * )
		;;
    esac

    $ECHO "${PREFIX}${1}${POSTFIX}" >> $2
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

    $ECHO "Creating tarball ... \c" 
    $TAR cf $PERF_TARBALL $LOG_DIR >> $SPARTA_LOG 2>&1
    if [ -r ${PERF_TARBALL}.gz ]; then
        mv ${PERF_TARBALL}.gz ${PERF_TARBALL}.gz.$$
    fi
    $ECHO "done"
    $ECHO "Compressing tarball ... \c" 
    $GZIP -v $PERF_TARBALL >> $SPARTA_LOG 2>&1
    if [ $? -eq 0 ]; then
        $ECHO "done"
    else
    	$ECHO "failed! error encountered compressing the file (will not have .gz suffix)"
    fi

    $ECHO "\nA snapshot of the currently collected data has been collected."
    $ECHO "Please upload ${PERF_TARBALL}.gz to $FTP_SERVER:/upload/<CASE_REF>"
    $ECHO "where <CASE_REF> should be substituted for the case reference number"
    $ECHO "of the performance issue is being investigated.\n"

    $ECHO "Please update your case reference in $CRM_TOOL \nor contact $NEX_SUPPORT_EMAIL if there are additional questions."
}

#
# Process any supplied command line switches
# before falling out to the sub-command processing stage
#
subcommand="usage"

while getopts ChINP:u:vp:? argopt
do
        case $argopt in
        C)      # Enable CIFS scripts
                TRACE_CIFS="y"
                ;;

        I)      # Enable iSCSI scripts
                TRACE_ISCSI="y"
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

    		IFS=",  ^M"
		for protocol in $OPTARG
		do
		    case $protocol in
			cifs  ) TRACE_CIFS="y"
			        ;;
			iscsi ) TRACE_ISCSI="y"
				;;
			nfs   ) TRACE_NFS="y"
			        ;;
			stmf  ) TRACE_STMF="y"
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

	S) 	# Enable STMF scripts
		# No scripts exist to date, to be enhanced at a later stage
		TRACE_STMF="y"
		;;

#        c)      subcommand=$OPTARG
#                ;;

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
# Check for a supplied command and act appropriately
#
case "$subcommand" in
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
	script_status
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
    print_to_log "$MONITOR_COMMAND $MONITOR_OPTS" $LOG_DIR/$SAMPLE_DAY/${MONITOR_NAME} $FF_DATE_SEP
}

### CPU/load specific section

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
        $VMSTAT $VMSTAT_OPTS >> $LOG_DIR/$SAMPLE_DAY/${1} 2>&1 &
    fi
}

function launch_mpstat
{
    $PGREP -fl "$MPSTAT $MPSTAT_OPTS" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        $MPSTAT $MPSTAT_OPTS >> $LOG_DIR/$SAMPLE_DAY/${1} 2>&1 &
    fi
}

function launch_prstat
{
    $PGREP -fl "$PRSTAT $PRSTAT_OPTS" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        $PRSTAT $PRSTAT_OPTS >> $LOG_DIR/$SAMPLE_DAY/${1} 2>&1 &
    fi
}

function gather_psrinfo
{
    $PSRINFO $PSRINFO_OPTS > $LOG_DIR/$SAMPLE_DAY/${1} 2>&1
}

function gather_cstate
{
    $KSTAT | grep -i cstate > $LOG_DIR/$SAMPLE_DAY/${1} 2>&1
}

function gather_interrupts
{
    $ECHO "::interrupts -d" | $MDB -k > $LOG_DIR/$SAMPLE_DAY/${1} 2>&1
}


### Kernel specific tool section

function launch_hotkernel
{
    for x in {1..3}
    do
        print_to_log "Sample $x" $LOG_DIR/$SAMPLE_DAY/${1} $FF_DATE_SEP
        $HOTKERNEL >> $LOG_DIR/$SAMPLE_DAY/$1 2>&1 &
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
        print_to_log "kmem_reap" $LOG_DIR/$SAMPLE_DAY/${1} $FF_DATE_SEP
        $KMEM_REAP >> $LOG_DIR/$SAMPLE_DAY/${1} 2>&1 &
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


### Network specific tool section

function gather_ifconfig
{
    $IFCONFIG -a > $LOG_DIR/$SAMPLE_DAY/${1}
}

function gather_dladm
{
    $DLADM show-phys > $LOG_DIR/$SAMPLE_DAY/dladm-show-phys.out
    $DLADM show-link > $LOG_DIR/$SAMPLE_DAY/dladm-show-link.out
    $DLADM show-linkprop > $LOG_DIR/$SAMPLE_DAY/dladm-show-linkprop.out
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
    IFS=",  ^M"
    for poolname in $ZPOOL_NAME
    do
        PGREP_STRING="$TXG_MON $poolname"
        TXG_MON_PID="`pgrep -fl "$PGREP_STRING" | awk '{print $1}'`"
        if [ "x$TXG_MON_PID" == "x" ]; then
            print_to_log "$TXG_MON on zpool $poolname" $LOG_DIR/$SAMPLE_DAY/zpool_${poolname}.out $FF_DATE_SEP
            $TXG_MON $poolname >> $LOG_DIR/$SAMPLE_DAY/zpool_${poolname}.out 2>&1 &
            print_to_log "  Started txg_monitoring on $poolname" $SPARTA_LOG $FF_DATE
        else
            print_to_log "  txg_monitor already running for zpool $poolname as PID $TXG_MON_PID" $SPARTA_LOG $FF_DATE
        fi
    done
    unset IFS
}

function launch_metaslab
{
    IFS=",  ^M"
    for poolname in $ZPOOL_NAME
    do
        PGREP_STRING="$METASLAB_ALLOC -p $poolname"
        METASLAB_MON_PID="`pgrep -fl "$PGREP_STRING" | awk '{print $1}'`"
        if [ "x$METASLAB_MON_PID" == "x" ]; then
            print_to_log "$METASLAB_ALLOC on zpool $poolname" $LOG_DIR/$SAMPLE_DAY/metaslab_${poolname}.out $FF_DATE_SEP
            $METASLAB_ALLOC -p $poolname >> $LOG_DIR/$SAMPLE_DAY/metaslab_${poolname}.out 2>&1 &
            print_to_log "  Started metaslab monitoring on $poolname" $SPARTA_LOG $FF_DATE
        else
            print_to_log "  metaslab monitoring already running for zpool $poolname as PID $METASLAB_MON_PID" $SPARTA_LOG $FF_DATE
        fi
    done
    unset IFS
}

function launch_arc_adjust
{
    ARC_ADJUST_PID="`pgrep -fl $ARC_ADJUST | awk '{print $1}'`"
    if [ "x$ARC_ADJUST_PID" == "x" ]; then
        print_to_log "ARC adjust" $LOG_DIR/$SAMPLE_DAY/arc_adjust.out $FF_DATE_SEP
        $ARC_ADJUST >> $LOG_DIR/$SAMPLE_DAY/arc_adjust.out 2>&1 &
        print_to_log "  Started ARC adjust monitoring" $SPARTA_LOG $FF_DATE
    else
        print_to_log "  arc_adjust already running as PID $ARC_ADJUST_PID" $SPARTA_LOG $FF_DATE
    fi
}

function gather_arc_mdb
{
    for x in {1..3}
    do
        print_to_log "  arc statistics - sample ${x}" $SPARTA_LOG $FF_DATE
        print_to_log "::arc data - sample ${x}" $LOG_DIR/$SAMPLE_DAY/arc.out $FF_DATE_SEP
        $ECHO "::arc" | $MDB -k >> $LOG_DIR/$SAMPLE_DAY/arc.out
        $ECHO ".\c"
        cursor_pause 5
    done 
}

function launch_arcstat
{
    ARCSTAT_PL_PID="`pgrep -fl $ARCSTAT_PL | awk '{print $1}'`"
    if [ "x$ARCSTAT_PL_PID" == "x" ]; then
        print_to_log "arcstat.pl" $LOG_DIR/$SAMPLE_DAY/arcstat.out $FF_DATE_SEP
        $ARCSTAT_PL $ARCSTAT_SLEEP >> $LOG_DIR/$SAMPLE_DAY/arcstat.out 2>&1 &
        print_to_log "  Started ARCstat monitoring" $SPARTA_LOG $FF_DATE
    else
        print_to_log "  arcstat.pl already running as PID $ARCSTAT_PL_PID" $SPARTA_LOG $FF_DATE
    fi
}

function launch_zil_commit
{
    ZIL_COMMIT_TIME_PID="`pgrep -fl $ZIL_COMMIT_TIME | awk '{print $1}'`"
    if [ "x$ZIL_COMMIT_TIME_PID" == "x" ]; then
        print_to_log "zil commit time" $LOG_DIR/$SAMPLE_DAY/zil_commit.out $FF_DATE_SEP
        $ZIL_COMMIT_TIME >> $LOG_DIR/$SAMPLE_DAY/zil_commit.out 2>&1 &
        print_to_log "  Started zil commit time sampling" $SPARTA_LOG $FF_DATE
    else
        print_to_log "  zil commit time script already running as PID $ZIL_COMMIT_TIME_PID" $SPARTA_LOG $FF_DATE
    fi
}

function launch_zil_stat
{
    ZIL_STAT_PID="`pgrep -fl zil_stat\.d | awk '{print $1}'`"
    if [ "x$ZIL_STAT_PID" == "x" ]; then
        print_to_log "zil statistics" $LOG_DIR/$SAMPLE_DAY/zilstat.out $FF_DATE_SEP
        $ZIL_STAT >> $LOG_DIR/$SAMPLE_DAY/zilstat.out 2>&1 &
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
    $ZPOOL status >> $LOG_DIR/$SAMPLE_DAY/zpool_status.out 2>&1
}

function gather_zpool_list
{
    $ZPOOL list >> $LOG_DIR/$SAMPLE_DAY/zpool_list.out 2>&1
}

function gather_zfs_get
{
    IFS=",  ^M"
    for poolname in $ZPOOL_NAME
    do
        $ZFS get -r all $poolname >> $LOG_DIR/$SAMPLE_DAY/zfs_get-r_all.${poolname}.out 2>&1
    done
    unset IFS
}

function launch_large_file_delete
{
    LARGE_DELETE_PID="`pgrep -fl $LARGE_DELETE | awk '{print $1}'`"
    if [ "x$LARGE_DELETE_PID" == "x" ]; then
        print_to_log "large delete monitoring" $LOG_DIR/$SAMPLE_DAY/large_delete.out $FF_DATE_SEP
        $LARGE_DELETE >> $LOG_DIR/$SAMPLE_DAY/large_delete.out 2>&1 &
        print_to_log "  Started monitoring of large deletes" $SPARTA_LOG $FF_DATE
    else
        print_to_log "  large delete script already running as PID $LARGE_DELETE_PID" $SPARTA_LOG $FF_DATE
    fi
}

function gather_zpool_iostat
{
    IFS=",  ^M"
    for poolname in $ZPOOL_NAME
    do
        PGREP_STRING="$ZPOOL iostat $ZPOOL_IOSTAT_OPTS $poolname $ZPOOL_IOSTAT_FREQ"
        ZPOOL_IOSTAT_PID="`pgrep -fl "$PGREP_STRING" | awk '{print $1}'`"
        if [ "x$ZPOOL_IOSTAT_PID" == "x" ]; then
            print_to_log "$ZPOOL iostat on zpool $poolname" $LOG_DIR/$SAMPLE_DAY/zpool_iostat_${poolname}.out $FF_DATE_SEP
            $ZPOOL iostat $ZPOOL_IOSTAT_OPTS $poolname $ZPOOL_IOSTAT_FREQ >> $LOG_DIR/$SAMPLE_DAY/zpool_iostat_${poolname}.out 2>&1 &
            print_to_log "Started zpool iostat $ZPOOL_IOSTAT_OPTS $poolname $ZPOOL_IOSTAT_FREQ" $SPARTA_LOG $FF_DATE
        else
            print_to_log "zpool iostat already running for zpool $poolname as PID $ZPOOL_IOSTAT_PID" $SPARTA_LOG $FF_DATE
        fi
    done
    unset IFS
}


### OS specific functions defined here

function launch_dnlc
{
    DNLC_LOOKUP_PID="`pgrep -fl $DNLC_LOOKUPS | awk '{print $1}'`"
    if [ "x$DNLC_LOOKUP_PID" == "x" ]; then
        print_to_log "DNLC lookups" $LOG_DIR/$SAMPLE_DAY/dnlc_lookups.out $FF_DATE_SEP
        $DNLC_LOOKUPS >> $LOG_DIR/$SAMPLE_DAY/dnlc_lookups.out 2>&1 &
        print_to_log "  Started DNLC lookup sampling" $SPARTA_LOG $FF_DATE
    else
        print_to_log "  DNLC lookups already running as PID $DNLC_LOOKUPS_PID" $SPARTA_LOG $FF_DATE
    fi
}

function gather_memstat
{
    for x in {1..3}
    do
        print_to_log "  memory statistics - sample ${x}" $SPARTA_LOG $FF_DATE
        print_to_log "::memstat data - sample ${x}" $LOG_DIR/$SAMPLE_DAY/memstat.out $FF_DATE_SEP
        $ECHO "::memstat" | $MDB -k >> $LOG_DIR/$SAMPLE_DAY/memstat.out
        $ECHO ".\c"
        cursor_pause 5
    done
}


## Disk specific functions defined here

function launch_iostat
{
    PGREP_STRING="$IOSTAT $IOSTAT_OPTS"
    $PGREP -fl "$PGREP_STRING" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        $IOSTAT $IOSTAT_OPTS >> $LOG_DIR/$SAMPLE_DAY/iostat.out 2>&1 &
	print_to_log "  Started iostat $IOSTAT_OPTS data collection" $SPARTA_LOG $FF_DATE
    else
        IOSTAT_PID="`pgrep -fl "$PGREP_STRING" | awk '{print $1}'`"
	print_to_log "  iostat disk statistic gathering already running as $IOSTAT_PID" $SPARTA_LOG $FF_DATE
    fi
}

function gather_iostat
{
    print_to_log "  getting disk error count (iostat -E)" $SPARTA_LOG $FF_DATE
    $IOSTAT $IOSTAT_INFO_OPTS >> $LOG_DIR/$SAMPLE_DAY/iostat-En.out
}


### NFS specific functions defined here

function launch_nfs_io
{
    NFS_IO_PID="`pgrep -fl "$NFS_IO" | awk '{print $1}'`"
    if [ "x$NFS_IO_PID" == "x" ]; then
        print_to_log "$NFS_IO starting" $LOG_DIR/$SAMPLE_DAY/nfs_io.out $FF_DATE_SEP
	$NFS_IO >> $LOG_DIR/$SAMPLE_DAY/nfs_io.out &
	print_to_log "  Started NFS file io monitoring" $SPARTA_LOG $FF_DATE
    else
 	print_to_log "  NFS file io monitoring alreading running as PID $NFS_IO_PID" $SPARTA_LOG $FF_DATE
    fi
}

function launch_nfs_thread_util
{
    NFS_THREADS_PID="`pgrep -fl "$NFS_THREADS" | awk '{print $1}'`"
    if [ "x$NFS_THREADS_PID" == "x" ]; then
	print_to_log "$NFS_THREADS starting" $LOG_DIR/$SAMPLE_DAY/nfs_threads.out $FF_DATE_SEP
	$NFS_THREADS >> $LOG_DIR/$SAMPLE_DAY/nfs_threads.out &
	print_to_log "  Started NFS thread monitoring" $SPARTA_LOG $FF_DATE
    else
	print_to_log "  NFS thread monitoring already running as PID $NFS_THREADS_PID" $SPARTA_LOG $FF_DATE
    fi
}

function launch_nfstop
{
    NFS_TOP_PID="`pgrep -fl 'dtrace .* nfssvrtop' | awk '{print $1}'`"
    if [ "x$NFS_TOP_PID" == "x" ]; then
	print_to_log "$NFS_TOP starting" $LOG_DIR/$SAMPLE_DAY/nfssvrtop.out $FF_DATE_SEP
	$NFS_TOP $NFSSVRTOP_OPTS >> $LOG_DIR/$SAMPLE_DAY/nfssvrtop.out &
	print_to_log "  Started NFS top monitoring" $SPARTA_LOG $FF_DATE
    else
	print_to_log "  NFS top monitoring already running as PID $NFS_TOP_PID" $SPARTA_LOG $FF_DATE
    fi
}

function launch_nfs_rwtime
{
    NFS_RWTIME_PID="`pgrep -fl "$NFS_RWTIME" | awk '{print $1}'`"
    if [ "x$NFS_RWTIME_PID" == "x" ]; then
	print_to_log "$NFS_RWTIME starting" $LOG_DIR/$SAMPLE_DAY/nfs_rwtime.out $FF_DATE_SEP
	$NFS_RWTIME >> $LOG_DIR/$SAMPLE_DAY/nfs_rwtime.out &
	print_to_log "  Started NFS monitoring of top files being accessed" $SPARTA_LOG $FF_DATE
    else
	print_to_log "  NFS top files monitoring already running as PID $NFS_RWTIME_PID" $SPARTA_LOG $FF_DATE
    fi
}


function gather_nfs_stat_server
{
    for x in {1..3}
    do
        print_to_log "  nfsstat -s statistics - sample ${x}" $SPARTA_LOG $FF_DATE
        print_to_log "nfsstat -s sample ${x}" $LOG_DIR/$SAMPLE_DAY/nfsstat-s.out $FF_DATE_SEP
        $NFSSTAT $NFSSTAT_OPTS >> $LOG_DIR/$SAMPLE_DAY/nfsstat-s.out
        $ECHO ".\c"
        cursor_pause 5
    done
}

function gather_nfs_share_output
{
    print_to_log "  Collecting NFS share information" $SPARTA_LOG $FF_DATE
    $SHARECTL get nfs > $LOG_DIR/$SAMPLE_DAY/sharectl_get_nfs.out
}


### ISCSI specific scripts defined here

function launch_iscsitop
{
    ISCSI_TOP_PID="`pgrep -fl 'dtrace .* iscsisvrtop' | awk '{print $1}'`"
    if [ "x$ISCSI_TOP_PID" == "x" ]; then
        print_to_log "$ISCSI_TOP starting" $LOG_DIR/$SAMPLE_DAY/iscsisvrtop.out $FF_DATE_SEP
	$ISCSI_TOP $ISCSISVRTOP_OPTS >> $LOG_DIR/$SAMPLE_DAY/iscsisvrtop.out &
	print_to_log "Started ISCSI top monitoring" $SPARTA_LOG $FF_DATE
    else    
	print_to_log "  iSCSI top monitoring already running as PID $ISCSI_TOP_PID" $SPARTA_LOG $FF_DATE
    fi
}


### COMSTAR/STMF/SBD specific scripts defined here

function launch_sbd_zvol_unmap
{
    PGREP_STRING="dtrace .*$SBD_ZVOL_UNMAP"
    SBD_ZVOL_UNMAP_PID="`pgrep -fl "$PGREP_STRING" | awk '{print $1}'`"
    if [ "x$SBD_ZVOL_UNMAP_PID" == "x" ]; then
        print_to_log "$SBD_ZVOL_UNMAP starting" $LOG_DIR/$SAMPLE_DAY/sbd_zvol_unmap.out $FF_DATE_SEP
	$SBD_ZVOL_UNMAP >> $LOG_DIR/$SAMPLE_DAY/sbd_zvol_unmap.out &
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
        print_to_log "$STMF_TASK_TIME starting" $LOG_DIR/$SAMPLE_DAY/stmf_task_time.out $FF_DATE_SEP
	$STMF_TASK_TIME >> $LOG_DIR/$SAMPLE_DAY/stmf_task_time.out &
	print_to_log "  Started stmf_task_time monitoring" $SPARTA_LOG $FF_DATE
    else    
	print_to_log "  stmf_task_time monitoring already running as PID $STMF_TASK_TIME_PID" $SPARTA_LOG $FF_DATE
    fi
}

function gather_stmf_workers
{
    for x in {1..10}
    do
        print_to_log "  stmf current worker backlog statistics - sample ${x}" $SPARTA_LOG $FF_DATE
        print_to_log "stmf current worker backlog info - sample ${x}" $LOG_DIR/$SAMPLE_DAY/stmf_worker_backlog.out $FF_DATE_SEP
        $ECHO "stmf_cur_ntasks::print -d" | $MDB -k >> $LOG_DIR/$SAMPLE_DAY/stmf_worker_backlog.out
        $ECHO ".\c"
        cursor_pause 5
    done
}


### CIFS specific scripts defined here

function launch_cifs_top
{
    CIFS_TOP_PID="`pgrep -fl 'dtrace .* cifssvrtop' | awk '{print $1}'`"
    if [ "x$CIFS_TOP_PID" == "x" ]; then
        print_to_log "$CIFS_TOP starting" $LOG_DIR/$SAMPLE_DAY/cifssvrtop.out $FF_DATE_SEP
	$CIFS_TOP $CIFSSVRTOP_OPTS >> $LOG_DIR/$SAMPLE_DAY/cifssvrtop.out &
	print_to_log "Started CIFS top monitoring" $SPARTA_LOG $FF_DATE
    else    
	print_to_log "  CIFS top monitoring already running as PID $CIFS_TOP_PID" $SPARTA_LOG $FF_DATE
    fi
}

function gather_cifs_share_output
{
    print_to_log "Collecting CIFS share information" $SPARTA_LOG $FF_DATE
    $SHARECTL get smb > $LOG_DIR/$SAMPLE_DAY/sharectl_get_smb.out
}




$ECHO "Nexenta Performance gathering script ($SPARTA_VER)"
$ECHO "====================================\n"

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
# Performance samples are collated by day (where possible) so figure out the day
#
SAMPLE_DAY="`$DATE +%Y:%m:%d`"
if [ ! -d $LOG_DIR/$SAMPLE_DAY ]; then
    $MKDIR -p $LOG_DIR/$SAMPLE_DAY
    if [ $? -ne 0 ]; then
	$ECHO "Unable to create $LOG_DIR/$SAMPLE_DAY directory to capture statistics"
	exit 1
    fi
fi

if [ ! -d $LOG_DIR/mdb ]; then
    $MKDIR $LOG_DIR/mdb
fi


#
# Collect the defined configuration files of interest
#

$ECHO "Collecting configuration files ... \c"
print_to_log "#############################" $SPARTA_LOG $FF_NEWL

print_to_log "Collecting configuration files first" $SPARTA_LOG $FF_DATE
for config_file in ${CONFIG_FILE_LIST}
do
    $CP $config_file $LOG_DIR/
done
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

$ECHO "Would you like to generate a tarball of the data collected so far? \c"
TARBALL_ANS="n"
while [ true ]; do
    $ECHO "(y|n) : \c"
    read TARBALL_ANS
    if [ `echo $TARBALL_ANS | wc -c` -lt 2 ]; then
        continue;
    fi
    TARBALL_ANS="`$ECHO $TARBALL_ANS | $TR '[:upper:]' '[:lower:]'`"
    if [ "$TARBALL_ANS" == "y" -o "$TARBALL_ANS" == "n" ]; then
        break
    fi
done
if [ "$TARBALL_ANS" == "y" ]; then
    generate_tarball
fi   

exit 0
