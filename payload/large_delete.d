#!/usr/sbin/dtrace -s

fbt:zfs:dmu_free_long_range_impl:entry 
{ 
    printf("%Y", walltimestamp); 
    self->start = timestamp; 
    trace((dnode_t *)args[1]->dn_maxblkid); 
    trace((dnode_t *)args[1]->dn_datablksz); 
    trace((uint64_t)args[2]); 
    trace((uint64_t)args[3]);
}

fbt:zfs:dmu_free_long_range_impl:return
/self->start/
{
    trace((timestamp - self->start)/1000000); 
    this->start = 0; 
}
