#!/usr/sbin/dtrace -s

/* 
 * Measure the current number of pending TCP connections and the listen backlog limit set 
 * If cnt > max this may be indicative of a problem
 *
 * Comments: Jason.Banham@Nexenta.COM
 *
 * Author: Marcel.Telka@Nexenta.COM
 * Copyright 2014, Nexenta Systems, Inc. All rights reserved.
 * Version: 0.1
 */

#pragma D option quiet

tcp_input_listener:entry
{
        printf("%Y cnt %d max %d\n",walltimestamp,
                ((conn_t *)args[0])->conn_proto_priv.cp_tcp->tcp_conn_req_cnt_q,
                ((conn_t *)args[0])->conn_proto_priv.cp_tcp->tcp_conn_req_max);
}
