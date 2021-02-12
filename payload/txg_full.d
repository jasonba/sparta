#!/usr/sbin/dtrace -s

/*
 * $Id$
 */

/*
 * CDDL HEADER START
 *
 * This file and its contents are supplied under the terms of the
 * Common Development and Distribution License ("CDDL"), version 1.0.
 * You may only use this file in accordance with the terms of version
 * 1.0 of the CDDL.
 *
 * A full copy of the text of the CDDL should have accompanied this
 * source.  A copy of the CDDL is also available via the Internet at
 * http://www.illumos.org/license/CDDL.
 *
 * CDDL HEADER END
 */

/*
 * Copyright (c) 2014 by Delphix. All rights reserved.
 *
 * Modified by Jason Banham @ Nexenta by DDN to catch for the divide-by-zero
 * problem on an idle zpool, resulting in garbage on screen and mangling of
 * the output.
 * - 2019-12-05
 */

#pragma D option quiet
#pragma D option dynvarsize=64m

:::BEGIN
{
        ((self->start) = 0x0);
        ((self->stop) = 0x0);
        (reason = "?");
        (reasoncaller = 0x0u);
        (@bytes_read2 = sum(0x0));
        (@reads = count());
        (lastprint = 0x0);
}

dtrace:::ERROR
{
        ((self->_DPP_error) = 0x1);
}

::spa_sync:entry
{
        ((self->_DPP_error) = 0x0);
}

::spa_sync:entry
/!(self->_DPP_error)/
{
        ((this->_DPP_condition1) = (0x1 && (stringof((args[0x0])->spa_name) == $$1)));
}

::spa_sync:entry
/(!(self->_DPP_error) && (this->_DPP_condition1))/
{
	printf("%Y : ", walltimestamp);
        printf("%d %5ums ", args[1], ((timestamp - (self->stop)) / 0xf4240));
        (spa = (args[0x0]));
        ((self->start) = timestamp);
}

::dsl_pool_sync:entry
{
        (((self->_DPP_entry_args01)[stackdepth]) = (args[0x0]));
        (((self->_DPP_entry_timestamp1)[stackdepth]) = timestamp);
}

::dsl_pool_sync:return
{
        ((self->_DPP_error) = 0x0);
}

::dsl_pool_sync:return
/!(self->_DPP_error)/
{
        ((this->_DPP_condition1) = (0x1 && ((self->_DPP_entry_timestamp1)[stackdepth])));
}

::dsl_pool_sync:return
/!(self->_DPP_error)/
{
        ((this->_DPP_condition2) = ((this->_DPP_condition1) && (((((self->_DPP_entry_args01)[stackdepth])->dp_spa) == spa) && ((spa->spa_sync_pass) == 0x1))));
}

::dsl_pool_sync:return
/(!(self->_DPP_error) && (this->_DPP_condition2))/
{
        (pass1_ms = ((timestamp - ((self->_DPP_entry_timestamp1)[stackdepth])) / 0xf4240));
}

::dsl_pool_sync:return
{
        (((self->_DPP_entry_args01)[stackdepth]) = 0x0);
        (((self->_DPP_entry_timestamp1)[stackdepth]) = 0x0);
}

::vdev_queue_pending_remove:entry
{
        ((self->_DPP_error) = 0x0);
}

::vdev_queue_pending_remove:entry
{
        (this->io) = (zio_t *)(args[0x1]);
}

::vdev_queue_pending_remove:entry
/!(self->_DPP_error)/
{
        ((this->_DPP_condition1) = (0x1 && (((this->io)->io_spa) == spa)));
}

::vdev_queue_pending_remove:entry
/!(self->_DPP_error)/
{
        ((this->_DPP_condition2) = ((this->_DPP_condition1) && ((((this->io)->io_type) == ZIO_TYPE_WRITE) && ((((this->io)->io_bookmark).zb_level) != -2))));
}

::vdev_queue_pending_remove:entry
/(!(self->_DPP_error) && (this->_DPP_condition2))/
{
        (@bytes_written = sum(((this->io)->io_size)));
        (@bytes_written2 = sum(((this->io)->io_size)));
}

::dmu_tx_delay:delay-mintime
{
        ((self->_DPP_error) = 0x0);
}

::dmu_tx_delay:delay-mintime
{
        ((this->tx) = (dmu_tx_t *)arg0);
}

::dmu_tx_delay:delay-mintime
/!(self->_DPP_error)/
{
        ((this->_DPP_condition1) = (0x1 && ((((this->tx)->tx_pool)->dp_spa) == spa)));
}

::dmu_tx_delay:delay-mintime
/(!(self->_DPP_error) && (this->_DPP_condition1))/
{
        (@throttle_us = max(((arg2 + 0x3e7) / 0x3e8)));
}

::dmu_tx_delay:entry
{
        (((self->_DPP_entry_args02)[stackdepth]) = (args[0x0]));
        (((self->_DPP_entry_timestamp2)[stackdepth]) = timestamp);
}

::dmu_tx_delay:return
{
        ((self->_DPP_error) = 0x0);
}

::dmu_tx_delay:return
/!(self->_DPP_error)/
{
        ((this->_DPP_condition1) = (0x1 && ((self->_DPP_entry_timestamp2)[stackdepth])));
}

::dmu_tx_delay:return
/!(self->_DPP_error)/
{
        ((this->_DPP_condition2) = ((this->_DPP_condition1) && (((((self->_DPP_entry_args02)[stackdepth])->tx_pool)->dp_spa) == spa)));
}

::dmu_tx_delay:return
/(!(self->_DPP_error) && (this->_DPP_condition2))/
{
        (@delay_us = max((((timestamp - ((self->_DPP_entry_timestamp2)[stackdepth])) / 0x3e8) + 0x1)));
}

::dmu_tx_delay:return
{
        (((self->_DPP_entry_args02)[stackdepth]) = 0x0);
        (((self->_DPP_entry_timestamp2)[stackdepth]) = 0x0);
}

::dsl_sync_task:entry
{
        ((self->_DPP_error) = 0x0);
}

::dsl_sync_task:entry
/!(self->_DPP_error)/
{
        ((this->_DPP_condition1) = (0x1 && ((strtok(stringof((char *)arg0), "/@") == $$1) && (reasoncaller == 0x0))));
}

::dsl_sync_task:entry
/(!(self->_DPP_error) && (this->_DPP_condition1))/
{
        (reason = "synctask");
        (reasoncaller = caller);
}

::txg_wait_open:entry
{
        ((self->_DPP_error) = 0x0);
}

::txg_wait_open:entry
/!(self->_DPP_error)/
{
        ((this->_DPP_condition1) = (0x1 && (((args[0x0])->dp_spa) == spa)));
}

::txg_wait_open:entry
/(!(self->_DPP_error) && (this->_DPP_condition1))/
{
        (reason = "waitopen");
        (reasoncaller = caller);
        trace(probefunc);
        stack();
}

::arc_tempreserve_space:entry
{
        (((self->_DPP_entry_arg03)[stackdepth]) = arg0);
        (((self->_DPP_entry_timestamp3)[stackdepth]) = timestamp);
}

::arc_tempreserve_space:return
{
        ((self->_DPP_error) = 0x0);
}

::arc_tempreserve_space:return
/!(self->_DPP_error)/
{
        ((this->_DPP_condition1) = (0x1 && ((self->_DPP_entry_timestamp3)[stackdepth])));
}

::arc_tempreserve_space:return
/!(self->_DPP_error)/
{
        ((this->_DPP_condition2) = ((this->_DPP_condition1) && (arg1 == 0x5b)));
}

::arc_tempreserve_space:return
/(!(self->_DPP_error) && (this->_DPP_condition2))/
{
        printf("reserve=%uKB arc_tempreserve=%uKB anon_size=%uKB arc_c=%uKB\n",
			   (((self->_DPP_entry_arg03)[stackdepth]) / 0x400),
			   (`arc_tempreserve / 0x400),
			   ((`arc_anon->arcs_size.rc_count) / 0x400),
			   ((((`arc_stats.arcstat_c).value).ui64) / 0x400));
}

::arc_tempreserve_space:return
{
        (((self->_DPP_entry_arg03)[stackdepth]) = 0x0);
        (((self->_DPP_entry_timestamp3)[stackdepth]) = 0x0);
}

:::zfs-dprintf
{
        ((self->_DPP_error) = 0x0);
}

:::zfs-dprintf
/!(self->_DPP_error)/
{
        ((this->_DPP_condition1) = (0x1 && (stringof(arg1) == "arc_tempreserve_space")));
}

:::zfs-dprintf
/(!(self->_DPP_error) && (this->_DPP_condition1))/
{
        printf("%s: %s\n", stringof(arg1), stringof(arg3));
}

::cv_timedwait:return
{
        ((self->_DPP_error) = 0x0);
}

::txg_thread_wait:entry
{
        ++(self->_DPP_callers1);
}

::cv_timedwait:return
/!(self->_DPP_error)/
{
        ((this->_DPP_condition2) = (0x1 && (((self->start) && ((args[0x1]) == 0xffffffffffffffff)) && (self->_DPP_callers1))));
}

::cv_timedwait:return
/(!(self->_DPP_error) && (this->_DPP_condition2))/
{
        (reason = "timeout");
}

::txg_thread_wait:return
/(self->_DPP_callers1)/
{
        --(self->_DPP_callers1);
}

::txg_thread_wait:entry
{
        (((self->_DPP_entry_args04)[stackdepth]) = (args[0x0]));
        (((self->_DPP_entry_args34)[stackdepth]) = (args[0x3]));
        (((self->_DPP_entry_timestamp4)[stackdepth]) = timestamp);
}

::txg_thread_wait:return
{
        ((self->_DPP_error) = 0x0);
}

::txg_thread_wait:return
/!(self->_DPP_error)/
{
        ((this->_DPP_condition1) = (0x1 && ((self->_DPP_entry_timestamp4)[stackdepth])));
}

::txg_thread_wait:return
/!(self->_DPP_error)/
{
        ((this->_DPP_condition2) = ((this->_DPP_condition1) && (((self->start) && (reason == "?")) && (((self->_DPP_entry_args34)[stackdepth]) != 0x0))));
}

::txg_thread_wait:return
/(!(self->_DPP_error) && (this->_DPP_condition2))/
{
        ((this->txs) = ((self->_DPP_entry_args04)[stackdepth]));
}

::txg_thread_wait:return
/!(self->_DPP_error)/
{
        ((this->_DPP_condition3) = ((this->_DPP_condition2) && (((this->txs)->tx_synced_txg) < ((this->txs)->tx_sync_txg_waiting))));
}

::txg_thread_wait:return
/(!(self->_DPP_error) && (this->_DPP_condition3))/
{
        (reason = "sync_txg_waiting");
}

::txg_thread_wait:return
/!(self->_DPP_error)/
{
        ((this->_DPP_condition4) = ((this->_DPP_condition2) && !(this->_DPP_condition3)));
}

::txg_thread_wait:return
/!(self->_DPP_error)/
{
        ((this->_DPP_condition5) = ((this->_DPP_condition4) && (((this->txs)->tx_quiesced_txg) != 0x0)));
}

::txg_thread_wait:return
/(!(self->_DPP_error) && (this->_DPP_condition5))/
{
        (reason = "quiesced");
}

::txg_thread_wait:return
{
        (((self->_DPP_entry_args04)[stackdepth]) = 0x0);
        (((self->_DPP_entry_args34)[stackdepth]) = 0x0);
        (((self->_DPP_entry_timestamp4)[stackdepth]) = 0x0);
}

:::tick-10hz
{
        ((self->_DPP_error) = 0x0);
}

:::tick-10hz
/!(self->_DPP_error)/
{
        ((this->_DPP_condition1) = (0x1 && (spa != 0x0)));
}

:::tick-10hz
/(!(self->_DPP_error) && (this->_DPP_condition1))/
{
        (@dirty_mb = max(((((spa->spa_dsl_pool)->dp_dirty_total) / 0x400) / 0x400)));
        (@dirty_b = max(((spa->spa_dsl_pool)->dp_dirty_total)));
}

::spa_sync:entry
{
        (((self->_DPP_entry_timestamp5)[stackdepth]) = timestamp);
}

::spa_sync:return
{
        ((self->_DPP_error) = 0x0);
}

::spa_sync:return
/!(self->_DPP_error)/
{
        ((this->_DPP_condition1) = (0x1 && ((self->_DPP_entry_timestamp5)[stackdepth])));
}

::spa_sync:return
/!(self->_DPP_error)/
{
        ((this->_DPP_condition2) = ((this->_DPP_condition1) && (self->start)));
}

/*
 * On a quiet zpool, the result of the timestamp calculation below can result in a returned
 * value of zero.  Unchecked this leaves to problems in the pass1 calculations, resulting
 * in dtrace barfing out an error 'divide-by-zero in action #X'
 * Apart from throwing garbage on screen, ruining formatting and being a pain in the
 * rear end, it just looks bad to have divide by zero error.
 * Here we capture the result into a variable, so we can detect the condition and avoid
 * dtrace barfing up the error
 */
::spa_sync:return
/(!(self->_DPP_error) && (this->_DPP_condition2))/
{
        this->div_zero = ((timestamp - ((self->_DPP_entry_timestamp5)[stackdepth])) / 0xf4240)
}

::spa_sync:return
/(!(self->_DPP_error) && (this->_DPP_condition2) && (this->div_zero == 0))/
{
	printf("  No SPA I/O detected\n");
        clear(@bytes_read2);
        clear(@reads);
        clear(@bytes_written);
        clear(@bytes_written2);
        clear(@bytes_read2);
        clear(@reads);
        trunc(@throttle_us);
        trunc(@delay_us);
        clear(@dirty_mb);
        clear(@dirty_b);
        (reason = "?");
        (reasoncaller = 0x0);
        ((self->stop) = timestamp);
}

::spa_sync:return
/(!(self->_DPP_error) && (this->_DPP_condition2) && (this->div_zero > 0))/
{
        normalize(@bytes_written, 0x100000);
        normalize(@bytes_written2, ((0x100000 * (timestamp - (self->start))) / 0x3b9aca00));
        printa(" %4@uMB", @bytes_written);
        printf(" in %5ums", ((timestamp - ((self->_DPP_entry_timestamp5)[stackdepth])) / 0xf4240));
        printf(" (%2u%% p1)", ((pass1_ms * 0x64) / ((timestamp - ((self->_DPP_entry_timestamp5)[stackdepth])) / 0xf4240)));
        printa(" %3@uMB/s", @bytes_written2);
        printa(" %@4uMB", @dirty_mb);
        normalize(@dirty_b, (`zfs_dirty_data_max / 0x64));
        printa(" (%@2u%%)", @dirty_b);
        printa(" %@4dus %@5dus", @throttle_us, @delay_us);
        printf("\n");
        clear(@bytes_read2);
        clear(@reads);
        clear(@bytes_written);
        clear(@bytes_written2);
        clear(@bytes_read2);
        clear(@reads);
        trunc(@throttle_us);
        trunc(@delay_us);
        clear(@dirty_mb);
        clear(@dirty_b);
        (reason = "?");
        (reasoncaller = 0x0);
        ((self->stop) = timestamp);
}

::spa_sync:return
{
        (((self->_DPP_entry_timestamp5)[stackdepth]) = 0x0);
}

:::BEGIN
{
        (printed = 0x186a0);
}

:::BEGIN,
::spa_sync:return
{
        ((self->_DPP_error) = 0x0);
}

:::BEGIN,
::spa_sync:return
/!(self->_DPP_error)/
{
        ((this->_DPP_condition1) = (0x1 && ((self->start) && (++printed > 0x1e))));
}

:::BEGIN,
::spa_sync:return
/(!(self->_DPP_error) && (this->_DPP_condition1))/
{
        printf(" \n");
        printf("                      txg        time since last sync \n");
        printf("                       |             |  written by sync \n");
        printf("                       |             |      | syncing time (%% pass 1) \n");
        printf("                       |             |      |         |        |     write rate while syncing \n");
        printf("                       |             |      |         |        |       |   highest dirty (%% of limit) \n");
        printf("                       |             |      |         |        |       |        | highest throttle delay \n");
        printf("                       |             |      |         |        |       |        |            |      | \n");
        printf("                       v             v      v         v        v       v        v            v      v \n");
        (printed = 0x0);
}

dtrace:::ERROR
{
        trace(arg1);
        trace(arg2);
        trace(arg3);
        trace(arg4);
        trace(arg5);
}

::spa_export:entry
/args[0] == $$1/
{
        self->export = 1;
}

::spa_export:return
/self->export && arg1 == 0/
{
        self->export = 0;
            exit(0);
}

::spa_export:return
/self->export/
{
        self->export = 0;
}
