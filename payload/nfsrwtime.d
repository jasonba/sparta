#!/usr/sbin/dtrace -s

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
        this->nfs3_elapsed = timestamp - start[args[1]->noi_xid];
        @rw[probename == "op-read-done" ? "read" : "write"] =
            quantize(this->nfs3_elapsed / 1000);
        @host[args[0]->ci_remote] = sum(this->nfs3_elapsed);
        @file[args[1]->noi_curpath] = sum(this->nfs3_elapsed);
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
        this->nfs4_elapsed = timestamp - nfsv4_start[args[1]->noi_xid];
        @nfsv4_rw[probename == "op-read-done" ? "read" : "write"] =
            quantize(this->nfs4_elapsed / 1000);
        @nfsv4_host[args[0]->ci_remote] = sum(this->nfs4_elapsed);
        @nfsv4_file[args[1]->noi_curpath] = sum(this->nfs4_elapsed);
        nfsv4_start[args[1]->noi_xid] = 0;
}

profile:::tick-30sec
{
	printf("%Y\n", walltimestamp);

        printf("NFSv3 read/write distributions (us):\n");
        printa(@rw);
	trunc(@rw);

        printf("\nNFSv3 read/write by host (total us):\n");
        normalize(@host, 1000);
        printa(@host);
	trunc(@host);

        printf("\nNFSv3 read/write top %d files (total us):\n", TOP_FILES);
        normalize(@file, 1000);
        trunc(@file, TOP_FILES);
        printa(@file);
	clear(@file);

        printf("NFSv4 read/write distributions (us):\n");
        printa(@nfsv4_rw);
	trunc(@nfsv4_rw);

        printf("\nNFSv4 read/write by host (total us):\n");
        normalize(@nfsv4_host, 1000);
        printa(@nfsv4_host);
	trunc(@nfsv4_host);

        printf("\nNFSv4 read/write top %d files (total us):\n", TOP_FILES);
        normalize(@nfsv4_file, 1000);
        trunc(@nfsv4_file, TOP_FILES);
        printa(@nfsv4_file);
	clear(@nfsv4_file);
}
