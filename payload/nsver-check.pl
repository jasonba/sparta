#!/usr/bin/perl

#
# Name          : nsver-check.pl
# Author        : Jason.Banham@nexenta.com
# Date          : 22nd July 2016
# Usage         : nsver-check.pl /etc/issue patch-requirement
# Purpose       : Check to see if the current version of NexentaStor contains a fix at the specified level
# Version       : 0.03
# Legal         : Copyright 2016, Nexenta Systems, Inc.
# History       : 0.01 - Initial version
#                 0.02 - Modified to handle a specified patch level to make it more generic
#		  0.03 - Now with added help and usage functionality
#

#
# This script was originally written to check to see if the appliance had the fix for NEX-3273 (4.0.3-FP4)
# installed, which the bug database tells us is 4.0.3-FP4 or later.
# It was subsequently expanded to check the installed release against any version
#
# The syntax for this would be to run the program thus:
#
# nsver-check.pl /etc/issue 4.0.3-FP4
#
# If the appliance is at the required version or greater, it returns "fixed" otherwise if the fix is absent
# it returns "missing"
#

use strict;
use Switch;
use Getopt::Std;

#
# Show how to run the program, if no arguments/file supplied
#
sub usage{
    print "Usage: nsver-check.pl [-h] /etc/issue version\n";
}


#
# Show the help page
#
sub help{
    usage();
    printf("\n");
    printf("This utility expects to take two arguments, the first being an /etc/issue file and the second being\n");
    printf("a NexentaStor version which should be the minimum level we require, that contains a given bug fix.\n");
    printf("For example, bug NEX-3273 is fixed in 4.0.3-FP4, so if the current running version of NexentaStor\n");
    printf("is at version 4.0.3-FP4 or any version of 4.0.4, or 4.0.5 or even 5.x then it should have the fix.\n");
    printf("If it's 4.0.3-FP3 or 4.0.2 for example, the fix is missing.\n\n");
    printf("So to check for this we would run:\n\n");
    printf("nsver-check.pl /etc/issue 4.0.3-FP4\n\n");
    printf("If the version of NexentaStor is patched, then this utility will return \"fixed\" otherwise it will\n");
    printf("return the word \"missing\"\n"); 
}

#
# Parse and process any options passed in
#

my %options=();
getopts("h", \%options);

if (defined $options{h}) {
    help();
    exit;
}

#
# Check we've actually supplied an '/etc/issue' file for checking
#
my $num_args = $#ARGV + 1;
if ( $num_args < 2 ) {
    usage();
    exit;
}

open (my $file, "<", $ARGV[0]) || die "Can't read file: $ARGV[0]";
my (@issue_list) = <$file>;
close($file);

my $fixlevel = $ARGV[1];

chomp(@issue_list);
my ($issue_lines) = scalar @issue_list;
my $index = 0;
my $major = 0;
my $minor = 0;
my $manic = 0;
my $fixpack = 0;

my $fixmajor = 0;
my $fixminor = 0;
my $fixmanic = 0;
my $fixfp    = 0;

while ($index < $issue_lines) {
    my ($preamble, $version) = split /\(/, $issue_list[$index];
    my ($tidyversion) = split /\)/, $version;
    ($major, $minor, $manic) = split /\./, $tidyversion;
    $major =~ s/v//g;
    ($manic, $fixpack) = split /-/, $manic;
    if ( $fixpack eq "" ) {
	$fixpack = "GA";
    }
    $index++;
}

#
# Parse the patch/NS fix level into base units
#
($fixmajor, $fixminor, $fixmanic) = split /\./, $fixlevel;
($fixmanic, $fixfp) = split /-/, $fixmanic;
if ( $fixfp eq "" ) {
    $fixfp = "GA";
}

#printf("Fix level = %s\n", $fixlevel);
#printf("Actual: major = %s, minor = %s, sub-minor = %s, fixpack = %s\n", $major, $minor, $manic, $fixpack);

if ( $major == $fixmajor && $minor == $fixminor && $manic > $fixmanic) {
    printf("fixed\n");
}
else {
    if ( $manic == $fixmanic ) {
	if ( $fixpack eq $fixfp ) {
    	    printf("fixed\n");
	}
	else {
	    printf("missing\n");
	}
    }
    if ( $manic < $fixmanic ) {
        printf("missing\n");
    }
}
