#!/usr/sbin/dtrace -s
/*
 * iscsisnoop.d - Snoop iSCSI events. Solaris Nevada, DTrace.
 *
 * This snoops iSCSI events when run on an iSCSI server.
 *
 * USAGE: iscsisnoop.d          # Hit Ctrl-C to end
 *
 * FIELDS:
 *              CPU             CPU event occured on
 *              REMOTE IP       IP address of the client
 *              EVENT           Data I/O event (data-send/data-receive)
 *              BYTES           Data bytes
 *              ITT             Initiator task tag
 *              SCSIOP          SCSI opcode as a description, as hex, or '-'
 *
 * NOTE: On multi-CPU servers output may not be in correct time order
 * (shuffled). A change in the CPU column is a hint that this happened.
 * If this is a problem, print an extra timestamp field and post sort.
 */

#pragma ident   "@(#)iscsisnoop.d       1.2     07/03/27 SMI"

#pragma D option quiet
#pragma D option switchrate=10

dtrace:::BEGIN
{
        printf("%-20s %3s  %-26s %-14s %6s %10s  %29s %-52s\n", "TIMESTAMP", "CPU", "REMOTE IP",
            "EVENT", "BYTES", "ITT", "SCSIOP", "INITIATOR");

        /*
         * SCSI opcode to string translation hash. This is from
         * /usr/include/sys/scsi/generic/commands.h. If you would
         * rather all hex, comment this out.
         */
        scsiop[0x00] = "test_unit_ready";
        scsiop[0x01] = "rezero/rewind";
        scsiop[0x03] = "request_sense";
        scsiop[0x04] = "format";
        scsiop[0x05] = "read_block_limits";
        scsiop[0x07] = "reassign";
        scsiop[0x08] = "read";
        scsiop[0x0a] = "write";
        scsiop[0x0b] = "seek";
        scsiop[0x0f] = "read_reverse";
        scsiop[0x10] = "write_file_mark";
        scsiop[0x11] = "space";
        scsiop[0x12] = "inquiry";
        scsiop[0x13] = "verify";
        scsiop[0x14] = "recover_buffer_data";
        scsiop[0x15] = "mode_select";
        scsiop[0x16] = "reserve";
        scsiop[0x17] = "release";
        scsiop[0x18] = "copy";
        scsiop[0x19] = "erase_tape";
        scsiop[0x1a] = "mode_sense";
        scsiop[0x1b] = "load/start/stop";
        scsiop[0x1c] = "get_diagnostic_results";
        scsiop[0x1d] = "send_diagnostic_command";
        scsiop[0x1e] = "door_lock";
        scsiop[0x23] = "read_format_capacity";
        scsiop[0x25] = "read_capacity";
        scsiop[0x28] = "read(10)";
        scsiop[0x2a] = "write(10)";
        scsiop[0x2b] = "seek(10)";
        scsiop[0x2e] = "write_verify";
        scsiop[0x2f] = "verify(10)";
        scsiop[0x30] = "search_data_high";
        scsiop[0x31] = "search_data_equal";
        scsiop[0x32] = "search_data_low";
        scsiop[0x33] = "set_limits";
        scsiop[0x34] = "read_position";
        scsiop[0x35] = "synchronize_cache";
        scsiop[0x37] = "read_defect_data";
        scsiop[0x39] = "compare";
        scsiop[0x3a] = "copy_verify";
        scsiop[0x3b] = "write_buffer";
        scsiop[0x3c] = "read_buffer";
        scsiop[0x3e] = "read_long";
        scsiop[0x3f] = "write_long";
        scsiop[0x42] = "unmap";
        scsiop[0x44] = "report_densities/read_header";
        scsiop[0x4c] = "log_select";
        scsiop[0x4d] = "log_sense";
        scsiop[0x55] = "mode_select(10)";
        scsiop[0x56] = "reserve(10)";
        scsiop[0x57] = "release(10)";
        scsiop[0x5a] = "mode_sense(10)";
        scsiop[0x5e] = "persistent_reserve_in";
        scsiop[0x5f] = "persistent_reserve_out";
        scsiop[0x80] = "write_file_mark(16)";
        scsiop[0x81] = "read_reverse(16)";
        scsiop[0x83] = "extended_copy";
        scsiop[0x88] = "read(16)";
        scsiop[0x8a] = "write(16)";
        scsiop[0x8c] = "read_attribute";
        scsiop[0x8d] = "write_attribute";
        scsiop[0x8f] = "verify(16)";
        scsiop[0x91] = "space(16)";
        scsiop[0x92] = "locate(16)";
        scsiop[0x9e] = "service_action_in(16)";
        scsiop[0x9f] = "service_action_out(16)";
        scsiop[0xa0] = "report_luns";
        scsiop[0xa2] = "security_protocol_in";
        scsiop[0xa3] = "maintenance_in";
        scsiop[0xa4] = "maintenance_out";
        scsiop[0xa8] = "read(12)";
        scsiop[0xa9] = "service_action_out(12)";
        scsiop[0xaa] = "write(12)";
        scsiop[0xab] = "service_action_in(12)";
        scsiop[0xac] = "get_performance";
        scsiop[0xaf] = "verify(12)";
        scsiop[0xb5] = "security_protocol_out"
}

iscsi*:::data-*,
iscsi*:::login-*,
iscsi*:::logout-*,
iscsi*:::nop-*,
iscsi*:::task-*,
iscsi*:::async-*,
iscsi*:::scsi-response
{
        printf("%-20Y %3d  %-26s %-14s %6d %10d  %29s\n", walltimestamp, cpu, args[0]->ci_remote,
            probename, args[1]->ii_datalen, args[1]->ii_itt, "-");
}

iscsi*:::scsi-command
/scsiop[args[2]->ic_cdb[0]] != NULL/
{
        printf("%-20Y %3d  %-26s %-14s %6d %10d  %29s %-52s\n", walltimestamp, cpu, args[0]->ci_remote,
            probename, args[1]->ii_datalen, args[1]->ii_itt, scsiop[args[2]->ic_cdb[0]], args[1]->ii_initiator);
}

iscsi*:::scsi-command
/scsiop[args[2]->ic_cdb[0]] == NULL/
{
        printf("%-20Y %3d  %-26s %-14s %6d %10d  0x%x %-52s\n", walltimestamp, cpu, args[0]->ci_remote,
            probename, args[1]->ii_datalen, args[1]->ii_itt, args[2]->ic_cdb[0], args[1]->ii_initiator);
}
