#!/usr/sbin/dtrace -s

#pragma D option quiet

/*
 * Program : stmf_threads.d
 * Author  : Jason Banham
 * Date    : 2018-01-27
 * Version : 0.01
 * Purpose : Give insight into STMF task queue thread scaling/management
 * Usage   : stmf_threads.d
 * History : 0.01 - Initial version
 *           0.02 - Redundant since NexentaStor 5.2
 */

fbt:stmf:stmf_worker_mgmt:entry
{
    printf("%Y : stmf_nworkers_needed = %d : stmf_nworkers_cur = %d\n", walltimestamp, stmf`stmf_nworkers_needed, stmf`stmf_nworkers_cur);
}
