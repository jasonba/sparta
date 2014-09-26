#!/usr/sbin/dtrace -s

/* 
 * Script to observe the number of delayed writes
 *
 * Author: Adam Leventhal
 * Copyright 2014 Joyent
 */

#pragma D option quiet

BEGIN
{
	printf("Monitoring the number of delays vs non-delays in ZFS TXG\n");
}

fbt::dsl_pool_need_dirty_delay:return
{ 
        @[args[1] == 0 ? "no delay" : "delay"] = count();
}

tick-10sec
{
    printa(@);
    trunc(@);
}
