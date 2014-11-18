#!/usr/sbin/dtrace -s

/* 
 * Script to observe the consistency delay latency in OpenZFS
 *
 * Author: Adam Leventhal
 * Copyright 2014 Delphix
 */

#pragma D option quiet

BEGIN
{
	printf("Monitoring for variation in delay latency\n");
}

delay-mintime
{ 
	@ = quantize(arg2);
}

tick-2sec
{
    printa(@);
    trunc(@);
}
