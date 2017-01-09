#!/usr/sbin/dtrace -s

/*
 * Script to observe I/O read/write latency 
 *
 * Author: Adam Leventhal
 * Copyright 2014 Delphix
 *
 * NOTE: Code upto and including the io:::done was writtenby Adam Leventhal
 *       In the original the tick-10sec was an END statement, to print information
 *       once an interrupt had been generated.
 *       The modification to use tick-10sec was changed by Jason.Banham@Nexenta.COM
 *       (and badly) in the first implementation.
 *       Within SPARTA the data was not automatically analysed and until this was
 * 	 recently plotted, no real analysis had taken place with the data sampled
 *       over any period of time.
 *       After plotting, the graph would start high and gradually decline to almost
 *       zero throughput, which was found over multiple samples from multiple systems,
 *       eg:
 *
 *    45 +-+-++-+-+-++-+-+-++-+-+-++-+-+-++-+-+-++-+-+-++-+-+-++-+-+-++-+-+-++-+
 *       +      # +        +       +        +        ++-------+-------+-------++
 *    40 +-+    #                                     |read throughput *******-+
 *       |      #                                     write throughput-#######+|
 *    35 +-+    #                                                            +-+
 *    30 +-+    #                                                            +-+
 *       |      #                                                              |
 *    25 +-+    #                                                            +-+
 *       |      #                                                              |
 *    20 +-+    #                                                            +-+
 *       |      #                                                              |
 *    15 +-+    *                                                            +-+
 *    10 +-+    *#                                                           +-+
 *       |      *#                                                             |
 *     5 +-+    *#                                                           +-+
 *       +      **#####    +       +        +        +        +       +        +
 *     0 +-+-++-+***************************************************************
 *     13/12    13/12    13/12   13/12    13/12    13/12    13/12   13/12    13/12
 *     09:40    09:50    10:00   10:10    10:20    10:30    10:40   10:50    11:00
 *
 *       Something was clearly wrong and after careful studying of the code I realised
 *       that the 'start' timestamp was static, thus during the normalisation, the
 *       calculation of 'timestamp - start' was always getting bigger!
 *       The fix was to reset start everytime we went through tick-10sec. 
 *
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

tick-10sec
{
    printf("---\n%Y\n", walltimestamp);
    printa(@q);

    normalize(@i, (timestamp - start) / 1000000000);
    normalize(@b, (timestamp - start) / 1000000000 * 1024);

    printf("%-30s %11s %11s %11s %11s\n", "", "avg latency", "stddev", "iops", "throughput");
    printa("%-30s %@9uus %@9uus %@9u/s %@8uk/s\n", @a, @v, @i, @b);
    trunc(@q);
    trunc(@a);
    trunc(@i);
    trunc(@b);
    trunc(@v);
    start = timestamp;
}

