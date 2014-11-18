#!/usr/sbin/dtrace -s

/*
 * Script to observe the amount of dirty data being written out (async) 
 * per sync event and also to see the dirty data max, so we can see how
 * close we are to the limit.
 *
 * Author: Adam Leventhal
 * Copyright 2014 Delphix
 */

#pragma D option quiet

BEGIN
{
    printf("Monitoring TXG syncs (dirty data) for %s\n", $$1)
}

txg-syncing
{
        this->dp = (dsl_pool_t *)arg0;
}

txg-syncing
/this->dp->dp_spa->spa_name == $$1/
{
        printf("%Y : %4dMB of %4dMB used\n", walltimestamp, this->dp->dp_dirty_total / 1024 / 1024,
            `zfs_dirty_data_max / 1024 / 1024);
}

