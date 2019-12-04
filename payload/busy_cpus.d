#!/usr/sbin/dtrace -s

#pragma D option quiet

fbt:unix:cpu_resched:entry
{
    self->cpu = (struct cpu *)arg0; 
    @[stack(), self->cpu->cpu_id] = count();
}

fbt:unix:cpu_resched:return
{
    self->cpu = 0;
}

tick-60sec
{
    exit(0);
}
