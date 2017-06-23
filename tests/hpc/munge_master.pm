# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Installation of munge package from HPC module and sanity check
# of this package
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>, soulofdestiny <mgriessmeier@suse.com>

use base "hpcbase";
use strict;
use warnings;
use testapi;
use lockapi;
use utils;

sub run() {
    my $self     = shift;
    my $host_ip  = get_required_var('HPC_HOST_IP');
    my $slave_ip = get_required_var('HPC_SLAVE_IP');
    barrier_create("INSTALLATION_FINISHED", 2);
    barrier_create("SERVICE_ENABLED",       2);

    select_console 'root-console';

    $self->setup_static_mm_network($host_ip);

    # set proper hostname
    assert_script_run('hostnamectl set-hostname munge-master');

    # install munge and wait for slave
    zypper_call('in munge');
    barrier_wait('INSTALLATION_FINISHED');

    # copy munge key
    $self->exec_and_insert_password("scp -o StrictHostKeyChecking=no /etc/munge/munge.key root\@$slave_ip:/etc/munge/munge.key");
    mutex_create('KEY_COPIED');

    # enable and start service
    assert_script_run('systemctl enable munge.service');
    assert_script_run('systemctl start munge.service');
    barrier_wait("SERVICE_ENABLED");

    # test if munch works fine
    assert_script_run('munge -n');
    assert_script_run('munge -n | unmunge');
    $self->exec_and_insert_password("munge -n | ssh $slave_ip unmunge");
    assert_script_run('remunge');
    mutex_create('MUNGE_DONE');
}

1;

# vim: set sw=4 et:

