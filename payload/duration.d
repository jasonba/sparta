#!/usr/sbin/dtrace -s

/*
 * Script to observe the time taken to sync a txg, which can be compared with
 * the output of dirty.d in order to see how much data and how long it's taking
 * to write that out to stable storage
 *
 * Author: Adam Leventhal
 * Copyright 2014 Joyent
 */

#pragma D option quiet

BEGIN
{
    printf("Monitoring TXG sync times for %s\n", $$1)
}

txg-syncing
/((dsl_pool_t *)arg0)->dp_spa->spa_name == $$1/
{
        start = timestamp;
}

txg-synced
/start && ((dsl_pool_t *)arg0)->dp_spa->spa_name == $$1/
{
        this->d = timestamp - start;
        printf("sync took %d.%02d seconds\n", this->d / 1000000000,
            this->d / 10000000 % 100);
}
