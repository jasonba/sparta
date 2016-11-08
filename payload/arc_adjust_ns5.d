#!/usr/sbin/dtrace -s
#pragma D option quiet
#pragma D option destructive

arc_adjust:entry
{
        self->ts = walltimestamp;
        printf("Entered arc_adjust at %Y\n1836: adjustment = MIN( %d, %d)\n\n", walltimestamp,
                (int64_t)(`arc_stats.arcstat_size.value.ui64 - `arc_stats.arcstat_c.value.ui64),
                (int64_t)(`arc_anon->arcs_size.rc_count + `arc_mru->arcs_size.rc_count + `arc_stats.arcstat_meta_used.value.ui64 - `arc_stats.arcstat_p.value.ui64));
        printf("arc_size = %d, arc_c = %d, arc_p = %d\n", 
                `arc_stats.arcstat_size.value.ui64,
                `arc_stats.arcstat_c.value.ui64,
                `arc_stats.arcstat_p.value.ui64);
	printf("arc_mru.size = %d, arc_mfu.size = %d\n", 
                `arc_mru->arcs_size.rc_count,
                `arc_mfu->arcs_size.rc_count);
	printf("arc_mru_ghost.size = %d, arc_mfu_ghost.size = %d\n", 
                `arc_mru_ghost->arcs_size.rc_count,
                `arc_mfu_ghost->arcs_size.rc_count);
	printf("arc_anon.size = %d, arc_meta_used = %d, arc_l2c_only.size = %d\n\n",
                `arc_anon->arcs_size.rc_count,
                `arc_stats.arcstat_meta_used.value.ui64,
                `arc_l2c_only->arcs_size.rc_count);
}

arc_shrink:entry
{
        printf("%Y 2085: to_free = MAX( %d, %d)\n", walltimestamp,
                `arc_stats.arcstat_c.value.ui64 >> `arc_shrink_shift, `needfree*4096);
}

arc_adjust:return
{
        printf("Returned from arc_adjust started at %Y %d ms later.\n---\n", self->ts, (walltimestamp - self->ts)/1000000);
}
