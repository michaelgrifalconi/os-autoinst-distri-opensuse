# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Test module for performing database takeover using various methods on "master" HANA database.

use base 'sles4sap_publiccloud_basetest';
use strict;
use warnings FATAL => 'all';
use testapi;
use publiccloud::utils;
use utils qw(zypper_call);
use sles4sap_publiccloud;
use Data::Dumper;
use serial_terminal 'select_serial_terminal';

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub run {
    my ($self, $run_args) = @_;
    select_serial_terminal;
    $self->{instances} = $run_args->{instances};
    my $test_name = $self->{name};
    my $takeover_action = $run_args->{hana_test_definitions}{$test_name}{action};
    my $site_name = $run_args->{hana_test_definitions}{$test_name}{site_name};
    my $target_site = $run_args->{$site_name};
    my $sbd_delay;
    die("Target site '$site_name' data is missing. This might indicate deployment issue.")
      unless $target_site;

    # Switch to control to target site (currently PROMOTED)
    $self->{my_instance} = $target_site;

    # Check initial cluster status
    $self->run_cmd(cmd => 'zypper -n in ClusterTools2');
    $self->run_cmd(cmd => 'cs_wait_for_idle --sleep 5');
    my $cluster_status = $self->run_cmd(cmd => 'crm status');
    record_info('Cluster status', $cluster_status);
    die(uc($site_name) . " '$target_site->{instance_id}' is NOT in MASTER mode.") if
      $self->get_promoted_hostname() ne $target_site->{instance_id};
    record_info(ucfirst($takeover_action) . ' DB',
        join(' ', ucfirst($takeover_action) . 'DB on', ucfirst($site_name), "('", $target_site->{instance_id}, "')")
    );

    # Setup sbd delay if defined by variable in case of crash OS to prevent cluster starting too quickly after reboot
    $self->setup_sbd_delay() if $takeover_action eq 'crash' and defined(get_var('HA_SBD_START_DELAY'));
    # Calculate SBD delay sleep time
    $sbd_delay = $self->sbd_delay_formula if $takeover_action eq 'crash';

    # Stop/kill/crash HANA DB and wait till SSH is again available with pacemaker running.
    $self->stop_hana(method => $takeover_action);
    $self->{my_instance}->wait_for_ssh(username => 'cloudadmin');

    # SBD delay is active only after reboot
    if ($takeover_action eq 'crash' and $sbd_delay != 0) {
        record_info('SBD SLEEP', "Waiting $sbd_delay sec for SBD delay timeout.");
        sleep($sbd_delay);
        $self->wait_for_pacemaker();
    }

    record_info('Takeover check');
    $self->check_takeover;

    record_info('Replication', join(' ', ('Enabling replication on', ucfirst($site_name), '(DEMOTED)')));
    $self->enable_replication();

    record_info(ucfirst($site_name) . ' start');
    $self->cleanup_resource();

    record_info('Done', 'Test finished');
}

1;
