#!/usr/sbin/dtrace -s
#pragma D option quiet

dtrace:::BEGIN
{
        trace("Tracing NFS I/O access ... \n");
}

nfsv3:::op-read-done
{
        @readbytes[args[1]->noi_curpath] = sum(args[2]->res_u.ok.data.data_len);
        @readiops[args[1]->noi_curpath] = count();
        @readbs[args[1]->noi_curpath] = avg(args[2]->res_u.ok.data.data_len);
}

nfsv4:::op-read-done
{
        @readbytes[args[1]->noi_curpath] = sum(args[2]->data_len);
        @readiops[args[1]->noi_curpath] = count();
        @readbs[args[1]->noi_curpath] = avg(args[2]->data_len);
}

nfsv3:::op-write-done
{
        @writebytes[args[1]->noi_curpath] = sum(args[2]->res_u.ok.count);
        @writeiops[args[1]->noi_curpath] = count();
        @writebs[args[1]->noi_curpath] = avg(args[2]->res_u.ok.count);
}

nfsv4:::op-write-done
{
        @writebytes[args[1]->noi_curpath] = sum(args[2]->count);
        @writeiops[args[1]->noi_curpath] = count();
        @writebs[args[1]->noi_curpath] = avg(args[2]->count);
}

/*
 * The data collected here is usually massive, leading to pointless data for a lot of samples
 * Truncate down to the top 10 for a more manageable, useful output
 */
tick-10sec
{
        trunc(@readbytes, 10);
        trunc(@readiops, 10);
        trunc(@readbs, 10);
        trunc(@writebytes, 10);
        trunc(@writeiops, 10);
        trunc(@writebs, 10);
        printf("%Y", walltimestamp);
        printf("\n%12s %12s %12s %12s %12s %12s %s\n", "Rbytes", "Rops", "Rbs", "Wbytes", "WOps", "Wbs", "Pathname");
        printa("%@12d %@12d %@12d %@12d %@12d %@12d %s\n", @readbytes, @readiops, @readbs, @writebytes, @writeiops, @writebs);
        clear(@readbytes);
        clear(@readiops);
        clear(@readbs);
        clear(@writebytes);
        clear(@writeiops);
        clear(@writebs);
}
