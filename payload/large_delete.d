#!/usr/sbin/dtrace -s

/*
 * This script monitors the time spent processing the deletion of a large file
 * It breaks this down by dataset dir name, the dnode being removed along with the max block id
 * and the data block size.
 *
 * Author: Jason Banham and others
 * Copyright 2012 and 2017 Nexenta Systems, Inc. All rights reserved.
 */

#pragma D option quiet

BEGIN
{
    printf("Tracing large delete operations\n\n");
}

fbt:zfs:dmu_free_long_range_impl:entry 
{ 
    self->objset = (struct objset *)arg0;
    self->dnode = (struct dnode *)arg1;
    printf("%Y : dsl_dir name = %s dnode = %d : ", walltimestamp, stringof(self->objset->os_dsl_dataset->ds_dir->dd_myname), self->dnode->dn_object); 
    self->start = timestamp; 
    printf("maxblkid = %d, datablksz = %d, arg2 = %p, arg3 = %p\n", self->dnode->dn_maxblkid, self->dnode->dn_datablksz, arg2, arg3);
}

fbt:zfs:dmu_free_long_range_impl:return
/self->start && self->dnode->dn_object/
{
    printf("%Y : dsl_dir name = %s dnode = %d : elapsed time = %d ms\n", walltimestamp, stringof(self->objset->os_dsl_dataset->ds_dir->dd_myname), self->dnode->dn_object, ((timestamp - self->start)/1000000));
    self->start = 0; 
    self->dnode = 0;
}
