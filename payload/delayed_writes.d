#!/usr/sbin/dtrace -s

/* 
 * Script to observe the number of delayed writes
 *
 * Author: Adam Leventhal
 * Copyright 2014 Delphix
 */

#pragma D option quiet

BEGIN
{
	printf("Monitoring the number of delays vs non-delays in ZFS TXG\n");
}

fbt::dsl_pool_need_dirty_delay:entry
{
        this->dsl = (struct dsl_pool *)arg0;
        this->spa = (struct spa *)this->dsl->dp_spa;
        printf("Delaying writes to %s\n", stringof(this->spa->spa_name));
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
