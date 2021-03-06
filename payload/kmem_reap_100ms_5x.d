#!/usr/sbin/dtrace -s

/*
 * As part of the fix for Illumos:
 * Bug #5376
 * Synopsis: arc_kmem_reap_now() should not result in clearing arc_no_grow
 *
 * We no longer have a reap strategy.  
 * Previously this could have been (0) = Aggressive, (1) = Conservative
 * Due to the graph plotting tools expecting a fixed number of fields, we'll 
 * artificially set this to 1 in NexentaStor 4.0.4 onwards
 * - Jason Banham, 2015/08/13
 *
 * NEX-9752 backport illumos 6950 ARC should cache compressed data
 *
 * This has elminated the use of arc_do_user_evicts() code, so the probes
 * have also been removed.
 * - Jason Banham, 2019/02/25
 *
 */
 
fbt::arc_kmem_reap_now:entry
{
    self->start[probefunc] = timestamp;
    self->strategy = 1;
    self->in_kmem = 1;
}

fbt::arc_adjust:entry,
fbt::arc_shrink:entry,
fbt::dnlc_reduce_cache:entry,
fbt::kmem_reap:entry
/self->in_kmem/
{
    self->start[probefunc] = timestamp;
}

kmem_depot_ws_reap:entry
{
        self->i = 1;
        self->start[probefunc] = timestamp;
        self->kct = args[0];
        self->magcount = 0;
        self->slabcount = 0;
}

kmem_magazine_destroy:entry
/self->i/
{
        self->magcount += 1;
}

kmem_slab_free:entry
/self->i/
{
        self->slabcount += 1;
}

fbt::arc_adjust:return,
fbt::arc_shrink:return,
fbt::dnlc_reduce_cache:return,
fbt::kmem_reap:return
/self->start[probefunc] && self->in_kmem && ((self->end[probefunc] = timestamp - self->start[probefunc]) > 100000000)/
{
        printf("%Y %d ms, freemem = %d lotsfree = %d desfree = %d minfree = %d throttlefree = %d", walltimestamp,
                (timestamp - self->start[probefunc]) / 1000000,
	        `freemem, `lotsfree, `desfree, `minfree, `throttlefree);
        self->start[probefunc] = NULL;
}

fbt::arc_adjust:return,
fbt::arc_shrink:return,
fbt::dnlc_reduce_cache:return,
fbt::kmem_reap:return
/self->start[probefunc] && self->in_kmem && ((self->end[probefunc] = timestamp - self->start[probefunc]) < 100000000)/
{
        self->start[probefunc] = NULL;
}


kmem_depot_ws_reap:return
/self->i && ((self->ts_end[probefunc] = timestamp - self->start[probefunc]) > 100000000)/
{
        self->i = NULL;
        printf("%Y %s %d ms %d mags %d slabs, freemem = %d lotsfree = %d desfree = %d minfree = %d throttlefree = %d", 
		walltimestamp, self->kct->cache_name, (self->ts_end[probefunc])/1000000, self->magcount, self->slabcount,
            	`freemem, `lotsfree, `desfree, `minfree, `throttlefree);
        self->start[probefunc] = NULL;

}

kmem_depot_ws_reap:return
/self->i && ((self->ts_end[probefunc] = timestamp - self->start[probefunc]) < 100000000)/
{
        self->i = NULL;
        self->start[probefunc] = NULL;
}


fbt::arc_kmem_reap_now:return
/self->start[probefunc] && ((self->end[probefunc] = timestamp - self->start[probefunc]) > 100000000)/
{
        printf("%Y %d ms, strategy %d, freemem = %d lotsfree = %d desfree = %d minfree = %d throttlefree = %d", 
		walltimestamp, (timestamp - self->start[probefunc]) / 1000000, self->strategy,
        	`freemem, `lotsfree, `desfree, `minfree, `throttlefree);
        self->start[probefunc] = NULL;
        self->in_kmem = NULL;
}

fbt::arc_kmem_reap_now:return
/self->start[probefunc] && ((self->end[probefunc] = timestamp - self->start[probefunc]) < 100000000)/
{
        self->start[probefunc] = NULL;
        self->in_kmem = NULL;
}
