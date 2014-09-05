#!/usr/sbin/dtrace -s

/*
 * Script to observe I/O read/write latency 
 *
 * Author: Adam Leventhal
 * Copyright 2014 Joyent
 */

#pragma D option quiet

BEGIN
{
    start = timestamp;
}

io:::start
{
    ts[args[0]->b_edev, args[0]->b_lblkno] = timestamp;
}

io:::done
/ts[args[0]->b_edev, args[0]->b_lblkno]/
{
    this->delta = (timestamp - ts[args[0]->b_edev, args[0]->b_lblkno]) / 1000;
    this->name = (args[0]->b_flags & (B_READ | B_WRITE)) == B_READ ?  "read " : "write ";

    @q[this->name] = quantize(this->delta);
    @a[this->name] = avg(this->delta);
    @v[this->name] = stddev(this->delta);
    @i[this->name] = count();
    @b[this->name] = sum(args[0]->b_bcount);

    ts[args[0]->b_edev, args[0]->b_lblkno] = 0;
}

END
{
    printa(@q);

    normalize(@i, (timestamp - start) / 1000000000);
    normalize(@b, (timestamp - start) / 1000000000 * 1024);

    printf("%-30s %11s %11s %11s %11s\n", "", "avg latency", "stddev", "iops", "throughput");
    printa("%-30s %@9uus %@9uus %@9u/s %@8uk/s\n", @a, @v, @i, @b);
}

