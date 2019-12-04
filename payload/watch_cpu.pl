#!/usr/bin/perl

#
# Name		: watch-cpu.pl
# Author	: Jason Banham
# Date		: 28th November 2019
# Usage		: watch-cpu.pl
# Purpose	: Kick off additional data sampling kernel cpu utilisation exceeds a threshold
# Version	: 0.03
# History	: 0.01 - Initial version (read data from a file)
#		  0.02 - Now takes an argument as the file to monitor, rather than hard coded
#                 0.03 - Can now monitor a file or from stdin
#

use strict;
use POSIX qw(uname);
use Getopt::Std;
use IO::File;

$SIG{INT} = sub { die "Interrupt received, must exit" };

my @uname = uname();

if ($uname[0] !~ /SunOS/) {
    printf("Sorry, this script requires an Illumos/Solaris based system to work\n");
    exit(0);
}

my $num_args = $#ARGV + 1;

my $cmd;			# The command to run to capture additional data
my $run_cmd;			# The command to execute
my $sleeptime = 5;		# How long to sleep in seconds
my $CPU_THRESHOLD = 85;		# Pending CPU kernel utilisation as a percentage
my $LOG_FILE = "Not specified";	# The log file containing the mpstat output
my $datestring;
my $str;
my $file;
my $watch_cpu_log;
my $LOG_ERROR = "Can't read file: " . $LOG_FILE;
my $WATCH_CPU_LOG_ERROR = "Cannot write to CPU watch log";

sub write_to_log{
    my $linedata = shift;
    open($watch_cpu_log, ">> /perflogs/samples/watch_cpu/watch_cpu.log") || die $WATCH_CPU_LOG_ERROR;
    print $watch_cpu_log $linedata;
    close $watch_cpu_log;
}


#
# This is the command to run to capture additional diagnostics
# It's a wrapper script that kicks off other programs, so as to ensure there's one place
# to do the work, rather than spawn multiple system calls from the monitoring app
#
# At the moment this is the cpu-grabit.sh script
#
$cmd = '/perflogs/scripts/cpu-grabit.sh';

my %options=();
getopts("f:p:", \%options);

if (defined $options{f}) {
    $LOG_FILE = $options{f};
}
if (defined $options{p}) {
    $CPU_THRESHOLD = $options{p};
}

$str = "Monitoring kernel CPU utilisation @ " . $CPU_THRESHOLD . "%\n";
write_to_log($str);

if (defined $file) {
    open($file, "<", $LOG_FILE) || die $LOG_ERROR;
    seek $file, 0, 2;       # Seek to the EOF
}
else {
    $file = *STDIN;
}

while (1 < 2) {
    while (<$file>) {
        $_ =~ s/^\s+//;
        my ($cpu, $minf, $mjf, $xcal, $intr, $ithr, $csw, $icsw, $migr, $smtx, $srw, $syscl, $usr, $sys, $wt, $idle) = split/\s+/, $_;
        if ($sys > $CPU_THRESHOLD) {
	    $datestring = localtime();
            $datestring = $datestring . ": CPU " . $cpu . " kernel utilisation exceeded " . $CPU_THRESHOLD . "%\n";
            write_to_log($datestring);
            $datestring = "";
            $run_cmd = $cmd . " " . $cpu;
            system($run_cmd);
        }
    }

    sleep $sleeptime;
    seek $file, 0, 1;	# Clear the EOF on the file
}
