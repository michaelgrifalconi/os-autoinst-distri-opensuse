# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: systemd-journal-remote
# Summary: - Send logs via systemd-journal-upload
#          - Collect them back via systemd-journal-remote
#          - Done on single machine and using https
# Maintainer: qe-core@suse.de

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {

    assert_script_run 'wget --quiet ' . data_url('console/journal_remote_upstream.sh');
    assert_script_run 'chmod +x journal_remote_upstream.sh';
    assert_script_run "./journal_remote_upstream.sh $os_version", 900;

}

1;
