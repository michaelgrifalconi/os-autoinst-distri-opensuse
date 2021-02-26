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
use utils;
#use utils qw(systemctl zypper_call);
#use version_utils qw(is_sle is_leap);


# Check Service State, enable it if necessary, set default zone to public
sub pre_test {
    zypper_call('in firewalld');
    zypper_call('info firewalld');
    record_info 'Check Service State';
    assert_script_run("if ! systemctl is-active -q firewalld; then systemctl start firewalld; fi");
    assert_script_run("firewall-cmd --set-default-zone=public");
}

sub setup_interfaces {
    assert_script_run("ip addr add 192.168.66.60 dev eth0");
    assert_script_run("ip addr add 192.168.66.61 dev eth1");
}

sub start_webserver {
	#assert_script_run('(PYTHONUNBUFFERED=x python3 -m http.server 6666 & true > http.server.log & echo $! > http.server.pid)');
    assert_script_run("screen -dm -S webserverScreen /bin/bash 'PYTHONUNBUFFERED=x python3 -m http.server 6666 & > http.server.log & echo $! > http.server.pid'")
}

sub stop_webserver {
    assert_script_run("kill $(cat http.server.pid)");
}

sub check_webserver_log {
    assert_script_run("cat http.server.log");
}

sub curl_webserver {
    assert_script_run("curl 192.168.66.60:6666/test60");
    assert_script_run("curl 192.168.66.61:6666/test61");
}

sub setup_policy {
    assert_script_run('firewall-cmd --zone=public --remove-interface=ovs-veth0');
    assert_script_run('firewall-cmd --zone=internal --add-interface=ovs-veth0');

}

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    pre_test;
    assert_script_run 'wget  ' . data_url('console/test_openssl_nodejs.sh');
    assert_script_run 'wget --quiet ' . data_url('console/firewalld_policy_objects.sh');
    assert_script_run 'chmod +x firewalld_policy_objects.sh';
    assert_script_run "./firewalld_policy_objects.sh", 900;

}

1;
