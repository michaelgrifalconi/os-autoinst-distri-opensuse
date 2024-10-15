# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: systemd-journal-remote
# Summary: - Send logs via systemd-journal-upload
#          - Collect them back via systemd-journal-remote
# Maintainer: qe-core@suse.de

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    select_serial_terminal;

    zypper_call("in systemd-journal-remote");

    # Setup uploader service
    script_run("echo '[Upload]' > /etc/systemd/journal-upload.conf");
    script_run("echo 'URL=http://127.0.0.1:9090' >> /etc/systemd/journal-upload.conf");
    systemctl('enable systemd-journal-upload.service');

    # Setup receiver service
    assert_script_run("mkdir -p /var/log/journal/remote");

    systemctl('enable systemd-journal-remote.socket');
    assert_script_run("sed -i \'s/^ListenStream=.*\$/ListenStream=9090/\' /etc/systemd/system/sockets.target.wants/systemd-journal-remote.socket");


    # Start them both
    systemctl('restart systemd-journal-remote.socket');
    script_run("sleep 10");
    systemctl('restart systemd-journal-upload.service');
    script_run("sleep 10");

    # Send a log message and look for it on both local and remote journalctl
    assert_script_run("echo 'TEST_MESSAGE_FOR_JOURNAL_UPLOADER' | systemd-cat");
    script_run("sleep 15");
    assert_script_run('journalctl --since "10 min ago" -g TEST_MESSAGE_FOR_JOURNAL_UPLOADER');
    #assert_script_run('journalctl  --file /var/log/journal/remote/remote-localhost.journalf --since "10 min ago" -g TEST_MESSAGE_FOR_JOURNAL_UPLOADER');


}

1;

