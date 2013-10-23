#!/usr/sbin/dtrace -s
/* nfsrwtime.d */

#pragma D option quiet

inline int TOP_FILES = 10;

dtrace:::BEGIN
{
        printf("Tracing... NFS r/w times and files.\n");
}

nfsv3:::op-read-start,
nfsv3:::op-write-start
{
        start[args[1]->noi_xid] = timestamp;
}

nfsv3:::op-read-done,
nfsv3:::op-write-done
/start[args[1]->noi_xid] != 0/
{
        this->elapsed = timestamp - start[args[1]->noi_xid];
        @rw[probename == "op-read-done" ? "read" : "write"] =
            quantize(this->elapsed / 1000);
        @host[args[0]->ci_remote] = sum(this->elapsed);
        @file[args[1]->noi_curpath] = sum(this->elapsed);
        start[args[1]->noi_xid] = 0;
}

nfsv4:::op-read-start,
nfsv4:::op-write-start
{
        nfsv4_start[args[1]->noi_xid] = timestamp;
}

nfsv4:::op-read-done,
nfsv4:::op-write-done
/nfsv4_start[args[1]->noi_xid] != 0/
{
        self->elapsed = timestamp - nfsv4_start[args[1]->noi_xid];
        @nfsv4_rw[probename == "op-read-done" ? "read" : "write"] =
            quantize(self->elapsed / 1000);
        @nfsv4_host[args[0]->ci_remote] = sum(self->elapsed);
        @nfsv4_file[args[1]->noi_curpath] = sum(self->elapsed);
        nfsv4_start[args[1]->noi_xid] = 0;
}

profile:::tick-60sec
{
	printf("%Y\n", walltimestamp);
        printf("NFSv3 read/write distributions (us):\n");
        printa(@rw);

        printf("\nNFSv3 read/write by host (total us):\n");
        normalize(@host, 1000);
        printa(@host);

        printf("\nNFSv3 read/write top %d files (total us):\n", TOP_FILES);
        normalize(@file, 1000);
        trunc(@file, TOP_FILES);
        printa(@file);

        printf("NFSv4 read/write distributions (us):\n");
        printa(@nfsv4_rw);

        printf("\nNFSv4 read/write by host (total us):\n");
        normalize(@nfsv4_host, 1000);
        printa(@host);

        printf("\nNFSv4 read/write top %d files (total us):\n", TOP_FILES);
        normalize(@nfsv4_file, 1000);
        trunc(@nfsv4_file, TOP_FILES);
        printa(@nfsv4_file);
}
