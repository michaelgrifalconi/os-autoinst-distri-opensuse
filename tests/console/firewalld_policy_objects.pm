# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: firewalld
# Summary: Test FirewallD Policy Objects Feature
# Maintainer: Michael Grifalconi <mgrifalconi@suse.com>

use strict;
use warnings;
use base "consoletest";
use testapi;
use utils qw(systemctl zypper_call);
#use version_utils qw(is_sle is_leap);


# Check Service State, enable it if necessary, set default zone to public
sub pre_test {
    zypper_call('in firewalld');
    zypper_call('info firewalld');
    record_info 'Check Service State';
    assert_script_run("if ! systemctl is-active -q firewalld; then systemctl start firewalld; fi");
    assert_script_run("firewall-cmd --set-default-zone=public");
}

sub test_ping {
    record_info 'Ping Test';
    assert_script_run('ping -c 5 -I vdmz 192.168.99.20');
    assert_script_run('ping -c 5 -I vext 192.168.99.20');
}

sub setup_policy {
    assert_script_run('firewall-cmd --zone=public --remove-interface=ovs-veth0');
    assert_script_run('firewall-cmd --zone=internal --add-interface=ovs-veth0');

}

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    pre_test;
}

1;
