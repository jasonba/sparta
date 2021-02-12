#!/usr/sbin/dtrace -s

/*
 * Program : sbd_lu_rw.d
 * Author  : Jason Banham
 * Date    : August 2016 | November 2018
 * Version : 0.04
 * Purpose : Watch R/W activity on a per SBD LU basis
 * Usage   : sbd_lu_rw.d
 * History : 0.01 - Initial version
 *           0.02 - Prettyfied
 *           0.03 - Now shows details of read/write bytes - total and per/sec
 *           0.04 - Now displays in MB because bytes are too large to contemplate quickly
 *
 */

#pragma D option quiet

BEGIN
{
    printf("Monitoring COMSTAR LU activity\n");
}

fbt:stmf_sbd:sbd_data_write:entry
{
    self->sbd_wlu = (struct sbd_lu *)arg0; 
    @w[stringof(self->sbd_wlu->sl_data_filename)] = count();
    @wb = sum(arg3);
} 

fbt:stmf_sbd:sbd_data_read:entry
{
    self->sbd_rlu = (struct sbd_lu *)arg0; 
    @r[stringof(self->sbd_rlu->sl_data_filename)] = count();
    @rb = sum(arg3);
} 

fbt:stmf_sbd:sbd_data_write:return
{
    self->sbd_wlu = 0;
}

fbt:stmf_sbd:sbd_data_read:return
{
    self->sbd_rlu = 0;
}

tick-5sec
{
     printf("%Y\n\n", walltimestamp);
     printf("Write Activity\n"); 
     printa(@w); 
     normalize(@wb, 1048576);
     printa("\nWrite Mbytes (in this period) : %@12d Mbytes\n", @wb);
     normalize(@wb, 5242880);
     printa("Writes per second             : %@12d Mbytes\n", @wb);
     printf("\n");

     printf("Read Activity\n"); 
     printa(@r); 
     normalize(@rb, 1048576);
     printa("\nRead Mbytes (in this period) : %@12d Mbytes\n", @rb);
     normalize(@rb, 5242880);
     printa("Read per second              : %@12d Mbytes\n", @rb);
     printf("\n");
     printf("---------------------------\n");

     trunc(@w); 
     trunc(@r);
     trunc(@wb);
     trunc(@rb);
}
