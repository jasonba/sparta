#!/usr/sbin/dtrace -qs

/*
 * This script will collect data from the various COMSTAR layers so that latency
 * and throughput analysis can be performed.
 *
 * The output can be viewed as:
 *     lu_xfer     = disk I/O latency (ZFS layer) - current blank due to a bug
 *     lport_xfer  = over the wire latency (between ports)
 *     qtime       = time waiting in COMSTAR task queue
 *     task_total  = sum of the other columns
 *
 * Once we know which component/sub-system is showing high latency we can focus
 * on that particular area.
 *
 * The scsi_task_t task_flags are defined in:
 *   usr/src/uts/common/sys/stmf.h
 *
 *   #define	TF_READ_DATA		0x40
 *   #define	TF_WRITE_DATA		0x20
 *
 * Version: 0.2
 *
 * Comments: Jason.Banham@Nexenta.COM
 *
 * Author: Tony.Huygen@Nexenta.COM
 * Copyright 2013, Nexenta Systems, Inc. All rights reserved.
 *
 * History: 0.01 - Initial version by Tony
 *          0.02 - Modified to print timestamps to make graphing easier (JB)
 *
 */


dtrace:::BEGIN
{
	r_iops = 1;
        rtask = 0;
        rqtime = 0;
        r_lu_xfer = 0;
        r_lport_xfer = 0;

	w_iops = 1;
        wtask = 0;
        wqtime = 0;
        w_lu_xfer = 0;
        w_lport_xfer = 0;

        printf("\nDate/Time              reads/sec  Avg:lu_xfer/lport_xfer/qtime/task_total(usec)   ");
        printf("writes/sec   Avg:lu_xfer/lport_xfer/qtime/task_total(usec)\n");
}

/*
 * read task completed
 */
sdt:stmf:stmf_task_free:stmf-task-end
/((scsi_task_t *) arg0)->task_flags & 0x40/
{
        this->task = (scsi_task_t *) arg0;
        this->lu = (stmf_lu_t *) this->task->task_lu;
        this->itask = (stmf_i_scsi_task_t *) this->task->task_stmf_private;
        this->lport = this->task->task_lport;

	r_iops = r_iops + 1;

        rtask = rtask + (arg1 / 1000);
        rqtime = rqtime + (this->itask->itask_waitq_time / 1000);
        r_lu_xfer = r_lu_xfer + (this->itask->itask_lu_read_time / 1000);
        r_lport_xfer = r_lport_xfer + (this->itask->itask_lport_read_time / 1000);
}

/*
 * write task completed
 */
sdt:stmf:stmf_task_free:stmf-task-end
/((scsi_task_t *) arg0)->task_flags & 0x20/
{
        this->task = (scsi_task_t *) arg0;
        this->lu = (stmf_lu_t *) this->task->task_lu;
        this->itask = (stmf_i_scsi_task_t *) this->task->task_stmf_private;
        this->lport = this->task->task_lport;

	w_iops = w_iops + 1;

	/* Save total time in usecs */
        wtask = wtask + (arg1 / 1000);
        wqtime = wqtime + (this->itask->itask_waitq_time / 1000);
        w_lu_xfer = w_lu_xfer + (this->itask->itask_lu_write_time / 1000);
        w_lport_xfer = w_lport_xfer + (this->itask->itask_lport_write_time / 1000);
}

profile:::tick-1sec
/r_iops || w_iops/
{
        avg_task = rtask / r_iops;
        avg_qtime = rqtime / r_iops;
        avg_lu_xfer = r_lu_xfer / r_iops;
        avg_lport_xfer = r_lport_xfer / r_iops;

        printf("%Y : reads/s: %d  Time: %d / %d / %d / %d   ", walltimestamp, r_iops,
	    avg_lu_xfer, avg_lport_xfer, avg_qtime, avg_task);

        avg_task = wtask / w_iops;
        avg_qtime = wqtime / w_iops;
        avg_lu_xfer = w_lu_xfer / w_iops;
        avg_lport_xfer = w_lport_xfer / w_iops;

        printf("writes/s: %d  Time: %d / %d / %d / %d\n", w_iops,
	    avg_lu_xfer, avg_lport_xfer, avg_qtime, avg_task);

	/* Resetting globals */
	r_iops = 1;
        rtask = 0;
        rqtime = 0;
        r_lu_xfer = 0;
        r_lport_xfer = 0;

	w_iops = 1;
        wtask = 0;
        wqtime = 0;
        w_lu_xfer = 0;
        w_lport_xfer = 0;
}

