#!/usr/bin/sh

### Default variables
poolname="syspool";

### Process options
while getopts hp: pname
do
        case $pname in
        p)      poolname=$OPTARG ;;

        h|?)	echo "USAGE: metaslab [-p poolname]"
		exit 1
        esac
done

###############################
#  --- Main Program,Dtrace ---
#

/usr/sbin/dtrace -n '
/*
 * metaslab
 */
#pragma D option quiet

inline string pool="'$poolname'";

fbt:zfs:metaslab_alloc:entry
/((spa_t *) (arg0))->spa_name == pool/
{
self->ts = timestamp;
        @bs = quantize(arg2);
}

fbt:zfs:metaslab_alloc:return
/self->ts/
{
        @ = quantize((timestamp - self->ts) / 1000);
	self->ts = 0;
}

profile:::tick-10s
{
	printf("\n==================================\n");
	printf("\t %s pool metaslab_alloc() activies:\n", pool);

	printf("\nLatencies(usec)");
	printa(@); trunc(@, 0);

	printf("\nslab size");
	printa(@bs); trunc(@bs, 0);
}
'
