#!/usr/sbin/dtrace -s

/*
 * This file and its contents are supplied under the terms of the
 * Common Development and Distribution License ("CDDL"), version 1.0.
 * You may only use this file in accordance with the terms of version
 * 1.0 of the CDDL.
 *
 * A full copy of the text of the CDDL should have accompanied this
 * source.  A copy of the CDDL is also available via the Internet at
 * http://www.illumos.org/license/CDDL.
 */

/*
 * Copyright 2019, Nexenta Systems, Inc. All rights reserved.
 */

#pragma D option defaultargs
#pragma D option quiet

dtrace:::BEGIN
{
	apd = 0;
	slow = 0;
	threshold_ms = ($1 == 0) ? 1000 : $1;
	printf("Monitoring for requests slower that %d ms\n", threshold_ms);
}

nfsv3:::op-read-start,
nfsv3:::op-write-start,
nfsv4:::op-read-start,
nfsv4:::op-write-start
{
	self->ts = timestamp;
}

nfsv3:::op-read-done,
nfsv3:::op-write-done,
nfsv4:::op-read-done,
nfsv4:::op-write-done
/ self->ts && (timestamp - self->ts) / 1000000 > threshold_ms /
{
	slow = 1;

	elapsed_ms = (timestamp - self->ts) / 1000000;
	@max_rsp  = max(elapsed_ms);
	@avg_rsp  = avg(elapsed_ms);
	@reqs = count();
	self->ts = 0;
}

tick-1s
/ apd == 0 && slow != 0 /
{
	apd = 1;
	printf("%Y BEGIN SLOW NFS EVENT\n", walltimestamp);
}

tick-1s
/ apd == 1 && slow == 0 /
{
	apd = 0;
    printf("%Y ", walltimestamp);
	printa("END   SLOW NFS EVENT - %@d reqs (max: %@dms, avg: %@dms)\n",
		@reqs, @max_rsp, @avg_rsp);

	trunc(@reqs);
	trunc(@max_rsp);
	trunc(@avg_rsp);
}

tick-1s
{
	slow = 0;
}

fbt::metaslab_activate:entry { self->activate = 1; }
fbt::metaslab_activate:return { self->activate = 0; }
fbt::metaslab_preload:entry { self->preload = 1; }
fbt::metaslab_preload:return { self->preload = 0; }

fbt::metaslab_load:entry
/args[0]->ms_group->mg_vd->vdev_spa->spa_name != "rpool"/
{
	self->ms = (metaslab_t *)args[0];
	printf("%Y %s BEGIN LOAD: (%s) vdev %d MS %d MSsz: %dG\n",
		   walltimestamp,
		   self->ms->ms_group->mg_vd->vdev_spa->spa_name,
		   self->activate ? "activate" : self->preload ? "preload" : "",
		   self->ms->ms_group->mg_vd->vdev_id,
		   self->ms->ms_id,
		   self->ms->ms_size / 1024 /1024 / 1024);
	self->ts = timestamp;
}

fbt::metaslab_load:return
/self->ms/
{
	idx = self->ms->ms_group->mg_vd->vdev_id * 1000 + self->ms->ms_id;
	tts[idx] = timestamp;
	this->elapsed = timestamp - self->ts;
	printf("%Y %s END LOAD:   (%s) vdev %d MS %d took %dms [AVLsz: %d SMap sz: %d blksz: %dK]\n",
		   walltimestamp,
		   self->ms->ms_group->mg_vd->vdev_spa->spa_name,
		   self->activate ? "activate" : self->preload ? "preload" : "",
		   self->ms->ms_group->mg_vd->vdev_id,
		   self->ms->ms_id,
		   this->elapsed / 1000000,
		   self->ms->ms_tree->rt_root.avl_numnodes * 72,
		   self->ms->ms_sm == 0 ? 0 : self->ms->ms_sm->sm_phys->smp_objsize,
		   self->ms->ms_sm == 0 ? 0 : self->ms->ms_sm->sm_blksz/1024);
	self->ts = 0;
	self->ms = 0;
}

fbt::metaslab_unload:entry
/args[0]->ms_group->mg_vd->vdev_spa->spa_name != "rpool"/
{
	self->ums = (metaslab_t *)args[0];
}

fbt::metaslab_unload:return
/self->ums/
{
	idx = self->ums->ms_group->mg_vd->vdev_id * 1000 + self->ums->ms_id;
	printf("%Y %s UNLOAD: vdev %d MS %d [size: %d blksz: %dK] - loaded for %dms\n",
		   walltimestamp,
		   self->ums->ms_group->mg_vd->vdev_spa->spa_name,
		   self->ums->ms_group->mg_vd->vdev_id,
		   self->ums->ms_id,
		   self->ums->ms_sm == 0 ? 0 : self->ums->ms_sm->sm_phys->smp_objsize,
		   self->ums->ms_sm == 0 ? 0 : self->ums->ms_sm->sm_blksz/1024,
		   (tts[idx] == 0) ? 0 : (timestamp - tts[idx]) / 1000000);
	self->ums = 0;
	tts[idx] = 0;
}

dtrace:::END
{
}
