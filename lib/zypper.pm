# Copyright (C) 2021 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

package zypper;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi qw(is_serial_terminal :DEFAULT);
use version_utils qw(is_microos is_leap is_sle is_sle12_hdd_in_upgrade is_storage_ng is_jeos);
use Mojo::UserAgent;

our @EXPORT = qw(
  wait_quit_zypper
  IN_ZYPPER_CALL
  zypper_call
);

# set flag IN_ZYPPER_CALL in zypper_call and unset when leaving
our $IN_ZYPPER_CALL = 0;

=head2 wait_quit_zypper

    wait_quit_zypper();

This function waits for any zypper processes in background to finish.

Some zypper processes (such as purge-kernels) in background hold the lock,
usually it's not intended or common that run 2 zypper tasks at the same time,
so we need wait the zypper processes in background to finish and release the
lock so that we can run a new zypper for our test.

=cut
sub wait_quit_zypper {
    assert_script_run('until ! pgrep \'zypper|purge-kernels|rpm\' > /dev/null; do sleep 10; done', 600);
}


=head2 zypper_call

 zypper_call($command [, exitcode => $exitcode] [, timeout => $timeout] [, log => $log] [, dumb_term => $dumb_term]);

Function wrapping 'zypper -n' with allowed return code, timeout and logging facility.
First parammeter is required command, all others are named and provided as hash
for example:

 zypper_call("up", exitcode => [0,102,103], log => "zypper.log");

 # up        --> zypper -n up --> update system
 # exitcode  --> allowed return code values
 # log       --> capture log and store it in zypper.log
 # dumb_term --> pipes through cat if set to 1 and log is not set. This is a  workaround
 #               to get output without any ANSI characters in zypper before 1.14.1. See boo#1055315.

C<dumb_term> will default to C<is_serial_terminal()>.
=cut
sub zypper_call {
    my $command          = shift;
    my %args             = @_;
    my $allow_exit_codes = $args{exitcode} || [0];
    my $timeout          = $args{timeout}  || 700;
    my $log              = $args{log};
    my $dumb_term        = $args{dumb_term} // is_serial_terminal;

    my $printer = $log ? "| tee /tmp/$log" : $dumb_term ? '| cat' : '';
    die 'Exit code is from PIPESTATUS[0], not grep' if $command =~ /^((?!`).)*\| ?grep/;

    # Michael zypper poc
    my $current_terminal = current_console();
    if ($current_terminal eq "root-console") {
        # is root, move to serial
        my $self = shift;
        $self->select_serial_terminal;
    }
    my $new_terminal = current_terminal();
    if ($current_terminal eq $new_terminal) {
        # is root, move to serial
        die "Nothing changed, still: $new_terminal";
    }
    # End poc

    $IN_ZYPPER_CALL = 1;
    # Retrying workarounds
    my $ret;
    my $search_conflicts = 'awk \'BEGIN {print "Processing conflicts - ",NR; group=0}
                    /Solverrun finished with an ERROR/,/statistics/{ print group"|",
                    $0; if ($0 ~ /statistics/ ){ print "EOL"; group++ }; }\'\
                    /var/log/zypper.log
                    ';
    for (1 .. 5) {
        $ret = script_run("zypper -n $command $printer; ( exit \${PIPESTATUS[0]} )", $timeout);
        die "zypper did not finish in $timeout seconds" unless defined($ret);
        if ($ret == 4) {
            if (script_run('grep "Error code.*502" /var/log/zypper.log') == 0) {
                die 'According to bsc#1070851 zypper should automatically retry internally. Bugfix missing for current product?';
            } elsif (script_run('grep "Solverrun finished with an ERROR" /var/log/zypper.log') == 0) {
                my $conflicts = script_output($search_conflicts);
                record_info("Conflict", $conflicts, result => 'fail');
                diag "Package conflicts found, not retrying anymore" if $conflicts;
                last;
            }
            next unless get_var('FLAVOR', '') =~ /-(Updates|Incidents)$/;
        }
        if (get_var('FLAVOR', '') =~ /-(Updates|Incidents)/ && ($ret == 4 || $ret == 8 || $ret == 105 || $ret == 106 || $ret == 139 || $ret == 141)) {
            if (script_run('grep "Exiting on SIGPIPE" /var/log/zypper.log') == 0) {
                record_soft_failure 'Zypper exiting on SIGPIPE received during package download bsc#1145521';
            }
            else {
                record_soft_failure 'Retry due to network problems poo#52319';
            }
            next;
        }
        last;
    }
    upload_logs("/tmp/$log") if $log;

    unless (grep { $_ == $ret } @$allow_exit_codes) {
        upload_logs('/var/log/zypper.log');
        my $msg = "'zypper -n $command' failed with code $ret";
        if ($ret == 104) {
            $msg .= " (ZYPPER_EXIT_INF_CAP_NOT_FOUND)\n\nRelated zypper logs:\n";
            script_run('tac /var/log/zypper.log | grep -F -m1 -B10000 "Hi, me zypper" | tac | grep \'\(SolverRequester.cc\|THROW\|CAUGHT\)\' > /tmp/z104.txt');
            $msg .= script_output('cat /tmp/z104.txt');
        }
        else {
            script_run('tac /var/log/zypper.log | grep -F -m1 -B10000 "Hi, me zypper" | tac | grep \'Exception.cc\' > /tmp/zlog.txt');
            $msg .= "\n\nRelated zypper logs:\n";
            $msg .= script_output('cat /tmp/zlog.txt');
        }
        die $msg;
    }
    $IN_ZYPPER_CALL = 0;
    if ($current_terminal eq "root-console") {
        # was root, move back to root
        select_console('root-console');
    }
    return $ret;
}


1;
