#!/usr/sbin/dtrace -Cqs
/*
 * This script observes the time spent from when we enter zil_commit()
 * to when we exit this particular function.
 * It runs until terminated, but also presents a graph of times, the number
 * of times we've taken that long and from which zpool, every tick seconds.
 * All times are in milliseconds
 *
 * The resulting data should be compared with previous samples to spot
 * any trends with particular times seeing higher hits.
 *
 * This implementation dumps the aggregation every 5 seconds
 * Now printing timestamps per tick operation to correlate any unusual
 * ZIL activity and latency issues.
 * 
 * Author: Jason Banham 
 * Copyright 2012 and 2013, Nexenta Systems, Inc. All rights reserved.
 */

fbt:zfs:zil_commit:entry
{
    self->zilog = (zilog_t *) arg0;
    self->spa = self->zilog->zl_spa;
    self->zil_ts = timestamp;
}

fbt:zfs:zil_commit:return
{
    self->zil_ctime = (timestamp - self->zil_ts) / 1000000;
    @[self->spa->spa_name] = quantize(self->zil_ctime);
    self->zilog = 0;
    self->spa = 0;
    self->zil_ts = 0;
    self->zil_ctime = 0;
}

tick-5sec
{
    printf("%Y\n", walltimestamp);
    printa(@);
}

