#!/usr/sbin/dtrace -qs

dnlc_lookup:return
{
    @[(arg1) ? "Hit":"Miss"] = count();
} 

tick-10sec
{
    printf("%Y ",walltimestamp);
    printa("%s: %@d ",@);
    printf("DNLC entries: %d\n",`dnlc_nentries);
    trunc(@);
}
