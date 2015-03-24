#!/usr/sbin/dtrace -s

/*
 * Script to observe the amount of dirty data being written out (async) 
 * per sync event and also to see the dirty data max, so we can see how
 * close we are to the limit.
 *
 * Heavily based on several DTrace scripts written by Adam Leventhal that discuss OpenZFS tuning here:
 *   http://dtrace.org/blogs/ahl/2014/08/31/openzfs-tuning/
 *
 * This script has taken a couple of scripts and merged the output into one.
 *
 * Author: Jason Banham (from original work by Adam Leventhal)
 * Copyright 2014 Delphix
 * Copyright 2015, Nexenta Systems, Inc. All rights reserved.
 */

#pragma D option quiet

BEGIN
{
    printf("Monitoring TXG syncs (dirty data) for %s\n", $$1);
    this->delay = 0;
    this->no_delay = 0;
}

txg-syncing
/((dsl_pool_t *)arg0)->dp_spa->spa_name == $$1/
{
        this->dp = (dsl_pool_t *)arg0;
	this->dirty = this->dp->dp_dirty_total;
	start = timestamp;
}

txg-synced
/start && ((dsl_pool_t *)arg0)->dp_spa->spa_name == $$1/
{
        this->d = timestamp - start;
        printf("%Y %s %4dMB of %4dMB used, synced in %dms, delays = %d, no_delays = %d\n", walltimestamp, stringof($$1), this->dirty / 1024 / 1024, `zfs_dirty_data_max / 1024 / 1024, this->d / 1000000, this->delay, this->no_delay);
	this->delay = 0;
	this->no_delay = 0;
        this->dirty = 0;
}


fbt::dsl_pool_need_dirty_delay:return
/args[1] == 1/
{
    this->delay++;
}

fbt::dsl_pool_need_dirty_delay:return
/args[1] == 0/
{
    this->no_delay++;
}
